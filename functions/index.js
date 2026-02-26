const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');
const {
  onCall, onRequest, HttpsError,
} = require('firebase-functions/v2/https');
const {
  defineSecret,
} = require('firebase-functions/params');
const Stripe = require('stripe');
const {
  Agent, run, setDefaultOpenAIKey,
} = require('@openai/agents');

admin.initializeApp();
const db = admin.firestore();

const REGION = 'europe-west1';
const PLATFORM_FEE_BPS = 1500;
// 15.00 %

const STRIPE_SECRET_KEY = defineSecret('STRIPE_SECRET_KEY');
const STRIPE_WEBHOOK_SECRET = defineSecret('STRIPE_WEBHOOK_SECRET');

const ONBOARDING_RETURN_URL = 'homelybites://onboarding/return';
const ONBOARDING_REFRESH_URL = 'homelybites://onboarding/refresh';
const PAYMENT_INTENT_ORDERS_COLLECTION = 'payment_intent_orders';
const HACCP_VERSION_CURRENT = '2026-02';
const SERVICE_MODE = Object.freeze({
  ON_SITE: 'on_site',
  TAKEAWAY: 'takeaway',
  BOTH: 'both',
});
const ALLOWED_MEAL_SERVICE_MODES = new Set([
  SERVICE_MODE.ON_SITE,
  SERVICE_MODE.TAKEAWAY,
  SERVICE_MODE.BOTH,
]);
const ALLOWED_ORDER_SERVICE_MODES = new Set([
  SERVICE_MODE.ON_SITE,
  SERVICE_MODE.TAKEAWAY,
]);
const ORDER_STATUS = Object.freeze({
  PENDING: 'pending',
  CONFIRMED: 'confirmed',
  CANCELLED: 'cancelled',
  REJECTED: 'rejected',
});
const PAYMENT_STATUS = Object.freeze({
  REQUIRES_PAYMENT: 'requires_payment',
  PAID: 'paid',
  FAILED: 'failed',
  REFUNDED: 'refunded',
});

function
getStripeClient() {
  const secret = STRIPE_SECRET_KEY.value();
  if (!secret || typeof secret !== 'string') {
    logger.error('STRIPE_SECRET_KEY missing or invalid');
    throw new HttpsError('failed-precondition', 'Stripe backend not configured.');
  }
  return new Stripe(secret);
}

function
assertAuthenticated(request) {
  if (!request.auth ?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }
  return request.auth.uid;
}

function
resolveRequestUid(request) {
  const authUid = assertAuthenticated(request);
  const requestedUid = getStringField(request.data ?.uid);
  if (requestedUid && requestedUid !== authUid) {
    throw new HttpsError('permission-denied', 'Cannot act on another user.');
  }
  return requestedUid || authUid;
}

async function
getUserProfile(uid) {
  const userRef = db.collection('users').doc(uid);
  const userSnapshot = await userRef.get();

  if (!userSnapshot.exists) {
    throw new HttpsError('failed-precondition', 'User profile not found.');
  }

  return {
    userRef,
    userData: userSnapshot.data(),
  };
}

function
assertHost(userData) {
  if (userData.role !== 'host') {
    throw new HttpsError('permission-denied', 'Host account required.');
  }
}

function
assertClient(userData) {
  if (userData.role !== 'client') {
    throw new HttpsError('permission-denied', 'Client account required.');
  }
}

function
computeStripeStatusFromAccount(account) {
  const chargesEnabled = Boolean(account ?.charges_enabled);
  const payoutsEnabled = Boolean(account ?.payouts_enabled);
  const currentlyDue = Array.isArray(account ?.requirements ?.currently_due) ?
    account.requirements.currently_due.length : 0;

  if (chargesEnabled && payoutsEnabled) {
    return 'ready';
  }

  if (currentlyDue > 0) {
    return 'pending';
  }

  return 'not_ready';
}

function
toConnectStatus(account) {
  const baseStatus = computeStripeStatusFromAccount(account);
  if (baseStatus === 'ready') {
    return 'enabled';
  }
  return baseStatus;
}

function
getStripeRequestId(error) {
  if (!error || typeof error !== 'object') {
    return null;
  }
  return error.requestId || error.request_id || error ?.raw ?.requestId || null;
}

async function
createStripeOnboardingLink(stripe, stripeAccountId) {
  return stripe.accountLinks.create({
    account: stripeAccountId,
    refresh_url: ONBOARDING_REFRESH_URL,
    return_url: ONBOARDING_RETURN_URL,
    type: 'account_onboarding',
  });
}

exports.createConnectAccount = onCall(
    {
      region: REGION,
      secrets: [STRIPE_SECRET_KEY],
    },
    async (request) => {
      const uid = resolveRequestUid(request);
      logger.info('createConnectAccount called', {
        functionName: 'createConnectAccount',
        uid,
      });
      let step = 'load_profile';
      try {
        const {
          userRef, userData,
        } = await getUserProfile(uid);
        logger.info('createConnectAccount user profile loaded', {
          functionName: 'createConnectAccount',
          uid,
          userPath: userRef.path,
        });
        step = 'assert_host_role';
        assertHost(userData);
        const stripe = getStripeClient();

        const existingAccountId = getStringField(userData.stripeAccountId);
        if (existingAccountId) {
          step = 'retrieve_existing_account';
          const existingAccount = await stripe.accounts.retrieve(existingAccountId);
          const connectStatus = toConnectStatus(existingAccount);
          const existingStatus = connectStatus === 'enabled' ? 'ready' : connectStatus;
          const stripeOnboarded = connectStatus === 'enabled';
          let onboardingLink = null;

          if (!stripeOnboarded) {
            step = 'create_existing_onboarding_link';
            onboardingLink = await createStripeOnboardingLink(stripe, existingAccountId);
          }

          step = 'save_existing_profile';
          await userRef.set({
            role: 'host',
            stripeStatus: existingStatus,
            stripeOnboarded,
            stripeConnectStatus: connectStatus,
            stripeOnboardingUrl: onboardingLink ?.url || null,
            stripeOnboardingExpiresAt: onboardingLink ?.expires_at || null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            stripeUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {
            merge: true,
          });

          logger.info('createConnectAccount returning existing account', {
            functionName: 'createConnectAccount',
            uid,
            accountId: existingAccountId,
            stripeStatus: existingStatus,
            status: connectStatus,
            onboardingUrl: onboardingLink ?.url || null,
          });
          return {
            accountId: existingAccountId,
            onboardingUrl: onboardingLink ?.url || null,
            onboardingExpiresAt: onboardingLink ?.expires_at || null,
            stripeOnboarded,
            stripeStatus: existingStatus,
            status: connectStatus,
            alreadyExists: true,
          };
        }

        step = 'create_stripe_account';
        const account = await stripe.accounts.create({
          type: 'express',
          email: request.auth ?.token ?.email || undefined,
          metadata: {
            uid,
          },
        });

        step = 'create_onboarding_link';
        const onboardingLink = await createStripeOnboardingLink(stripe, account.id);

        step = 'save_user_profile';
        await userRef.set({
          role: 'host',
          stripeAccountId: account.id,
          stripeOnboarded: false,
          stripeStatus: 'not_ready',
          stripeConnectStatus: 'not_ready',
          stripeOnboardingUrl: onboardingLink.url,
          stripeOnboardingExpiresAt: onboardingLink.expires_at,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          stripeUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {
          merge: true,
        });

        logger.info('createConnectAccount success', {
          functionName: 'createConnectAccount',
          uid,
          accountId: account.id,
          stripeStatus: 'not_ready',
          onboardingUrl: onboardingLink.url,
        });
        return {
          accountId: account.id,
          onboardingUrl: onboardingLink.url,
          onboardingExpiresAt: onboardingLink.expires_at,
          stripeOnboarded: false,
          stripeStatus: 'not_ready',
          status: 'not_ready',
          alreadyExists: false,
        };
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }

        if (error && error.type === 'StripeAuthenticationError') {
          logger.error('createConnectAccount failed: invalid Stripe credentials', {
            functionName: 'createConnectAccount',
            uid,
            step,
            stripeRequestId: getStripeRequestId(error),
            stripeType: error.type,
            error: error instanceof Error ? error.message : String(error),
          });
          throw new HttpsError('failed-precondition', 'Stripe credentials are invalid on backend.');
        }

        logger.error('createConnectAccount failed', {
          functionName: 'createConnectAccount',
          uid,
          step,
          stripeRequestId: getStripeRequestId(error),
          stripeType: error && error.type ? error.type : null,
          stripeCode: error && error.code ? error.code : null,
          stripeDeclineCode: error && error.decline_code ? error.decline_code : null,
          error: error instanceof Error ? error.message : String(error),
        });
        console.error('[createConnectAccount] failure', {
          uid,
          step,
          error: error instanceof Error ? {
            name: error.name,
            message: error.message,
            stack: error.stack,
          } : String(error),
        });
        throw new HttpsError(
            'internal',
            `createConnectAccount failed at step "${step}".`,
            {
              message: `Erreur interne Stripe Connect (step: ${step}).`,
              hint: 'Verifier users/{uid}, role=host et la secret STRIPE_SECRET_KEY.',
              functionName: 'createConnectAccount',
              uid,
              step,
              stripeRequestId: getStripeRequestId(error),
              stripeType: error && error.type ? error.type : null,
              stripeCode: error && error.code ? error.code : null,
            },
        );
      }
    },
);

exports.createOnboardingLink = onCall(
    {
      region: REGION,
      secrets: [STRIPE_SECRET_KEY],
    },
    async (request) => {
      const uid = resolveRequestUid(request);
      logger.info('createOnboardingLink called', {
        functionName: 'createOnboardingLink',
        uid,
      });
      let step = 'load_profile';
      try {
        const {
          userRef, userData,
        } = await getUserProfile(uid);
        step = 'assert_host_role';
        assertHost(userData);

        const stripeAccountId = getStringField(userData.stripeAccountId);
        if (!stripeAccountId) {
          throw new HttpsError(
              'failed-precondition',
              'Host has no Stripe account yet. Call createConnectAccount first.',
          );
        }

        step = 'create_onboarding_link';
        const stripe = getStripeClient();
        const link = await createStripeOnboardingLink(stripe, stripeAccountId);

        step = 'save_onboarding_state';
        await userRef.set({
          stripeOnboardingUrl: link.url,
          stripeOnboardingExpiresAt: link.expires_at,
          stripeStatus: 'pending',
          stripeUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {
          merge: true,
        });

        logger.info('createOnboardingLink success', {
          functionName: 'createOnboardingLink',
          uid,
          stripeAccountId,
          expiresAt: link.expires_at,
        });
        return {
          url: link.url,
          expiresAt: link.expires_at,
          status: 'pending',
        };
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }

        logger.error('createOnboardingLink failed', {
          functionName: 'createOnboardingLink',
          uid,
          step,
          stripeRequestId: getStripeRequestId(error),
          stripeType: error && error.type ? error.type : null,
          stripeCode: error && error.code ? error.code : null,
          stripeDeclineCode: error && error.decline_code ? error.decline_code : null,
          error: error instanceof Error ? error.message : String(error),
        });
        throw new HttpsError('internal', 'Unable to create Stripe onboarding link.');
      }
    },
);

exports.refreshStripeStatus = onCall(
    {
      region: REGION,
      secrets: [STRIPE_SECRET_KEY],
    },
    async (request) => {
      const uid = resolveRequestUid(request);
      logger.info('refreshStripeStatus called', {
        functionName: 'refreshStripeStatus',
        uid,
      });

      let step = 'load_profile';
      try {
        const {
          userRef, userData,
        } = await getUserProfile(uid);
        step = 'assert_host_role';
        assertHost(userData);

        const stripeAccountId = getStringField(userData.stripeAccountId);
        if (!stripeAccountId) {
          throw new HttpsError('failed-precondition', 'Host has no Stripe account yet.');
        }

        step = 'retrieve_stripe_account';
        const stripe = getStripeClient();
        const account = await stripe.accounts.retrieve(stripeAccountId);
        const stripeStatus = computeStripeStatusFromAccount(account);
        const stripeOnboarded = stripeStatus === 'ready';
        const currentlyDueCount = Array.isArray(account ?.requirements ?.currently_due) ?
          account.requirements.currently_due.length : 0;

        step = 'save_profile_status';
        await userRef.set({
          stripeOnboarded,
          stripeStatus,
          stripeUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {
          merge: true,
        });

        logger.info('refreshStripeStatus success', {
          functionName: 'refreshStripeStatus',
          uid,
          stripeAccountId,
          stripeStatus,
          stripeOnboarded,
          currentlyDueCount,
        });

        return {
          accountId: stripeAccountId,
          stripeStatus,
          stripeOnboarded,
          currentlyDueCount,
        };
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }

        logger.error('refreshStripeStatus failed', {
          functionName: 'refreshStripeStatus',
          uid,
          step,
          stripeRequestId: getStripeRequestId(error),
          stripeType: error && error.type ? error.type : null,
          stripeCode: error && error.code ? error.code : null,
          error: error instanceof Error ? error.message : String(error),
        });
        throw new HttpsError('internal', 'Unable to refresh Stripe status.');
      }
    },
);

exports.getConnectStatus = onCall(
    {
      region: REGION,
      secrets: [STRIPE_SECRET_KEY],
    },
    async (request) => {
      const uid = resolveRequestUid(request);
      logger.info('getConnectStatus called', {
        functionName: 'getConnectStatus',
        uid,
      });

      let step = 'load_profile';
      try {
        const {
          userRef, userData,
        } = await getUserProfile(uid);
        step = 'assert_host_role';
        assertHost(userData);

        const stripeAccountId = getStringField(userData.stripeAccountId);
        if (!stripeAccountId) {
          throw new HttpsError('failed-precondition', 'Host has no Stripe account yet.');
        }

        step = 'retrieve_stripe_account';
        const stripe = getStripeClient();
        const account = await stripe.accounts.retrieve(stripeAccountId);

        const status = toConnectStatus(account);
        const payoutsEnabled = Boolean(account ?.payouts_enabled);
        const chargesEnabled = Boolean(account ?.charges_enabled);
        const requirements = {
          currentlyDue: Array.isArray(account ?.requirements ?.currently_due) ?
            account.requirements.currently_due : [],
          eventuallyDue: Array.isArray(account ?.requirements ?.eventually_due) ?
            account.requirements.eventually_due : [],
          pastDue: Array.isArray(account ?.requirements ?.past_due) ?
            account.requirements.past_due : [],
          pendingVerification: Array.isArray(account ?.requirements ?.pending_verification) ?
            account.requirements.pending_verification : [],
        };

        step = 'save_profile_status';
        await userRef.set({
          stripeOnboarded: status === 'enabled',
          stripeStatus: status === 'enabled' ? 'ready' : status,
          stripeConnectStatus: status,
          stripeUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {
          merge: true,
        });

        logger.info('getConnectStatus success', {
          functionName: 'getConnectStatus',
          uid,
          stripeAccountId,
          status,
          payoutsEnabled,
          chargesEnabled,
          currentlyDueCount: requirements.currentlyDue.length,
        });

        return {
          accountId: stripeAccountId,
          status,
          payoutsEnabled,
          chargesEnabled,
          requirements,
        };
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }

        logger.error('getConnectStatus failed', {
          functionName: 'getConnectStatus',
          uid,
          step,
          stripeRequestId: getStripeRequestId(error),
          stripeType: error && error.type ? error.type : null,
          stripeCode: error && error.code ? error.code : null,
          error: error instanceof Error ? error.message : String(error),
        });
        throw new HttpsError('internal', 'Unable to fetch Stripe Connect status.');
      }
    },
);

exports.acknowledgeHaccp = onCall(
    {
      region: REGION,
    },
    async (request) => {
      const uid = resolveRequestUid(request);
      logger.info('acknowledgeHaccp called', {
        functionName: 'acknowledgeHaccp',
        uid,
      });

      let step = 'load_profile';
      try {
        const {
          userRef, userData,
        } = await getUserProfile(uid);

        step = 'assert_host_role';
        assertHost(userData);

        const requestedVersion = getStringField(request.data ?.version);
        const version = requestedVersion || HACCP_VERSION_CURRENT;

        step = 'save_haccp_ack';
        await userRef.set({
          haccpAcceptedAt: admin.firestore.FieldValue.serverTimestamp(),
          haccpVersion: version,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {
          merge: true,
        });

        logger.info('acknowledgeHaccp success', {
          functionName: 'acknowledgeHaccp',
          uid,
          haccpVersion: version,
        });
        return {
          ok: true,
          haccpVersion: version,
        };
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }

        logger.error('acknowledgeHaccp failed', {
          functionName: 'acknowledgeHaccp',
          uid,
          step,
          error: error instanceof Error ? error.message : String(error),
        });
        throw new HttpsError('internal', 'Unable to save HACCP acknowledgement.');
      }
    },
);

exports.createOrderAndPaymentIntent = onCall(
    {
      region: REGION,
      secrets: [STRIPE_SECRET_KEY],
    },
    async (request) => {
      const uid = assertAuthenticated(request);
      const mealId = request.data ?.mealId;
      const portions = request.data ?.portions;
      const rawNote = request.data ?.note;
      const requestedServiceMode = getServiceModeField(
          request.data ?.serviceMode,
          ALLOWED_ORDER_SERVICE_MODES,
          'serviceMode',
      ) || SERVICE_MODE.ON_SITE;
      logger.info('createOrderAndPaymentIntent called', {
        uid,
        mealId: typeof mealId === 'string' ? mealId : null,
        portions: Number.isInteger(portions) ? portions : null,
        serviceMode: requestedServiceMode,
      });

      if (!mealId || typeof mealId !== 'string') {
        throw new HttpsError('invalid-argument', 'mealId is required.');
      }

      if (!Number.isInteger(portions) || portions <= 0 || portions > 500) {
        throw new HttpsError('invalid-argument', 'portions must be an integer between 1 and 500.');
      }

      if (rawNote !== undefined && typeof rawNote !== 'string') {
        throw new HttpsError('invalid-argument', 'note must be a string.');
      }

      const note = (rawNote || '').trim();
      if (note.length > 500) {
        throw new HttpsError('invalid-argument', 'note is too long.');
      }

      const [{
        userData: clientData,
      }, mealSnapshot] = await Promise.all([
        getUserProfile(uid),
        db.collection('meals').doc(mealId).get(),
      ]);
      assertClient(clientData);

      if (!mealSnapshot.exists) {
        throw new HttpsError('not-found', 'Meal not found.');
      }

      const meal = mealSnapshot.data();
      const priceCents = meal ?.priceCents;
      const hostId = getStringField(meal ?.hostId) ||
        getStringField(meal ?.ownerId);
      const rawMealServiceMode = getStringField(meal ?.serviceMode);
      let mealServiceMode = SERVICE_MODE.ON_SITE;
      if (rawMealServiceMode) {
        if (ALLOWED_MEAL_SERVICE_MODES.has(rawMealServiceMode)) {
          mealServiceMode = rawMealServiceMode;
        } else {
          logger.warn('Meal has invalid serviceMode, defaulting to on_site', {
            mealId,
            hostId: typeof hostId === 'string' ? hostId : null,
            rawMealServiceMode,
          });
        }
      }
      if (!Number.isInteger(priceCents) || priceCents <= 0) {
        throw new HttpsError('failed-precondition', 'Meal has an invalid price.');
      }
      if (!hostId) {
        throw new HttpsError('failed-precondition', 'Meal host is missing.');
      }
      if (mealServiceMode !== SERVICE_MODE.BOTH && mealServiceMode !== requestedServiceMode) {
        throw new HttpsError(
            'failed-precondition',
            'Selected service mode is not available for this meal.',
        );
      }

      const {
        userData: hostData,
      } = await getUserProfile(hostId);
      assertHost(hostData);
      const hostStripeAccountId = getStringField(hostData.stripeAccountId);
      if (!hostStripeAccountId) {
        throw new HttpsError('failed-precondition', 'Host Stripe account missing.', {
          message: `Host Stripe account missing in users/${hostId}.`,
          functionName: 'createOrderAndPaymentIntent',
          hostId,
          mealId,
        });
      }
      const hostStripeReady = hostData.stripeOnboarded === true ||
        hostData.stripeStatus === 'ready' ||
        hostData.stripeStatus === 'enabled';
      if (!hostStripeReady) {
        throw new HttpsError('failed-precondition', 'Host Stripe onboarding incomplete.');
      }

      const amount = priceCents * portions;
      if (!Number.isInteger(amount) || amount <= 0) {
        throw new HttpsError('failed-precondition', 'Invalid order amount.');
      }

      const orderRef = db.collection('orders').doc();
      const orderId = orderRef.id;
      const stripe = getStripeClient();
      const applicationFeeAmount = Math.round(amount * (PLATFORM_FEE_BPS / 10000));

      let paymentIntent;
      try {
        paymentIntent = await stripe.paymentIntents.create({
          amount,
          currency: 'eur',
          automatic_payment_methods: {
            enabled: true,
          },
          application_fee_amount: applicationFeeAmount,
          transfer_data: {
            destination: hostStripeAccountId,
          },
          metadata: {
            orderId,
            mealId,
            clientId: uid,
            hostId,
            serviceMode: requestedServiceMode,
          },
        }, {
          idempotencyKey: `create_order_${orderId}`,
        });
      } catch (error) {
        logger.error('Failed to create Stripe PaymentIntent', {
          orderId,
          mealId,
          clientId: uid,
          stripeType: error && error.type ? error.type : null,
          stripeCode: error && error.code ? error.code : null,
          stripeDeclineCode: error && error.decline_code ? error.decline_code : null,
          error: error instanceof Error ? error.message : String(error),
        });
        console.error('[createOrderAndPaymentIntent] payment_intent_failure', {
          orderId,
          mealId,
          clientId: uid,
          hostId,
          error: error instanceof Error ? {
            name: error.name,
            message: error.message,
            stack: error.stack,
          } : String(error),
        });
        throw new HttpsError('internal', 'Unable to create payment intent.');
      }

      if (!paymentIntent ?.id || !paymentIntent ?.client_secret) {
        logger.error('Stripe PaymentIntent response missing required fields', {
          orderId,
          mealId,
          clientId: uid,
          paymentIntentId: paymentIntent ?.id || null,
        });
        throw new HttpsError('internal', 'PaymentIntent response invalid.');
      }

      const paymentIntentOrderRef = db.collection(PAYMENT_INTENT_ORDERS_COLLECTION).doc(paymentIntent.id);
      try {
        await db.runTransaction(async (tx) => {
          const mappingSnapshot = await tx.get(paymentIntentOrderRef);
          const existingOrderId = getStringField(mappingSnapshot.data() ?.orderId);
          if (existingOrderId && existingOrderId !== orderId) {
            throw new Error(`PaymentIntent already mapped to another order: ${existingOrderId}`);
          }

          tx.create(orderRef, {
            mealId,
            clientId: uid,
            hostId,
            hostStripeAccountId,
            portions,
            note,
            amount,
            amountCents: amount,
            currency: 'eur',
            serviceMode: requestedServiceMode,
            mealServiceMode,
            paymentIntentId: paymentIntent.id,
            status: ORDER_STATUS.PENDING,
            paymentStatus: PAYMENT_STATUS.REQUIRES_PAYMENT,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          tx.set(paymentIntentOrderRef, {
            orderId,
            paymentIntentId: paymentIntent.id,
            clientId: uid,
            hostId,
            mealId,
            source: 'createOrderAndPaymentIntent',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {
            merge: true,
          });
        });
      } catch (error) {
        logger.error('Failed to persist order after PaymentIntent creation', {
          orderId,
          paymentIntentId: paymentIntent.id,
          mealId,
          clientId: uid,
          error: error instanceof Error ? error.message : String(error),
        });

        try {
          await stripe.paymentIntents.cancel(paymentIntent.id);
        } catch (cancelError) {
          logger.error('Failed to cancel orphaned PaymentIntent', {
            orderId,
            paymentIntentId: paymentIntent.id,
            error: cancelError instanceof Error ? cancelError.message : String(cancelError),
          });
        }

        throw new HttpsError('internal', 'Unable to create order.');
      }

      return {
        orderId,
        clientSecret: paymentIntent.client_secret,
      };
    },
);

exports.createPaymentIntentWithFee = onCall(
    {
      region: REGION,
      secrets: [STRIPE_SECRET_KEY],
    },
    async (request) => {
      const uid = assertAuthenticated(request);
      const orderId = getStringField(request.data ?.orderId);
      logger.info('createPaymentIntentWithFee called', {
        functionName: 'createPaymentIntentWithFee',
        uid,
        orderId,
      });

      if (!orderId) {
        throw new HttpsError('invalid-argument', 'orderId is required.');
      }

      let step = 'load_order';
      try {
        const orderRef = db.collection('orders').doc(orderId);
        const orderSnapshot = await orderRef.get();
        if (!orderSnapshot.exists) {
          throw new HttpsError('not-found', 'Order not found.');
        }

        const order = orderSnapshot.data() || {};
        if (order.clientId !== uid) {
          throw new HttpsError('permission-denied', 'Not your order.');
        }

        if (order.paymentStatus === PAYMENT_STATUS.PAID) {
          throw new HttpsError('failed-precondition', 'Order already paid.');
        }
        if (order.paymentStatus && order.paymentStatus !== PAYMENT_STATUS.REQUIRES_PAYMENT) {
          throw new HttpsError('failed-precondition', 'Order is not payable.');
        }

        const amount = Number.isInteger(order.amountCents) ? order.amountCents : order.amount;
        if (!Number.isInteger(amount) || amount <= 0) {
          throw new HttpsError('failed-precondition', 'Invalid order amount.');
        }

        const mealId = getStringField(order.mealId);
        const hostId = getStringField(order.hostId);
        if (!hostId) {
          throw new HttpsError('failed-precondition', 'Order host missing.');
        }

        step = 'load_host_profile';
        const {
          userData: hostData,
        } = await getUserProfile(hostId);
        assertHost(hostData);
        const hostStripeAccountId = getStringField(order.hostStripeAccountId) ||
          getStringField(hostData.stripeAccountId);
        if (!hostStripeAccountId) {
          throw new HttpsError('failed-precondition', 'Host Stripe account missing.', {
            message: `Host Stripe account missing in users/${hostId}.`,
            functionName: 'createPaymentIntentWithFee',
            hostId,
            orderId,
          });
        }
        const hostStripeReady = hostData.stripeOnboarded === true ||
          hostData.stripeStatus === 'ready' ||
          hostData.stripeStatus === 'enabled';
        if (!hostStripeReady) {
          throw new HttpsError('failed-precondition', 'Host Stripe onboarding incomplete.');
        }

        const stripe = getStripeClient();
        const applicationFeeAmount = Math.round(amount * (PLATFORM_FEE_BPS / 10000));
        const existingPaymentIntentId = getStringField(order.paymentIntentId);
        let paymentIntent = null;

        if (existingPaymentIntentId) {
          step = 'retrieve_existing_payment_intent';
          try {
            paymentIntent = await stripe.paymentIntents.retrieve(existingPaymentIntentId);
            if (paymentIntent.status === 'succeeded') {
              throw new HttpsError('failed-precondition', 'Order already paid.');
            }
            if (paymentIntent.status === 'canceled') {
              paymentIntent = null;
            }
          } catch (error) {
            if (error instanceof HttpsError) {
              throw error;
            }
            const stripeCode = error && error.code ? error.code : null;
            if (stripeCode === 'resource_missing') {
              logger.warn('Existing paymentIntent missing, recreating', {
                functionName: 'createPaymentIntentWithFee',
                orderId,
                paymentIntentId: existingPaymentIntentId,
              });
              paymentIntent = null;
            } else {
              throw error;
            }
          }
        }

        if (!paymentIntent) {
          step = 'create_payment_intent';
          paymentIntent = await stripe.paymentIntents.create({
            amount,
            currency: 'eur',
            automatic_payment_methods: {
              enabled: true,
            },
            application_fee_amount: applicationFeeAmount,
            transfer_data: {
              destination: hostStripeAccountId,
            },
            metadata: {
              orderId,
              mealId,
              clientId: uid,
              hostId,
            },
          }, {
            idempotencyKey: `create_payment_intent_${orderId}`,
          });
        }

        if (!paymentIntent ?.id || !paymentIntent ?.client_secret) {
          throw new HttpsError('internal', 'PaymentIntent response invalid.');
        }

        step = 'persist_order_and_mapping';
        await Promise.all([
          orderRef.set({
            paymentIntentId: paymentIntent.id,
            hostStripeAccountId,
            amountCents: amount,
            currency: 'eur',
            paymentStatus: PAYMENT_STATUS.REQUIRES_PAYMENT,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {
            merge: true,
          }),
          db.collection(PAYMENT_INTENT_ORDERS_COLLECTION).doc(paymentIntent.id).set({
            orderId,
            paymentIntentId: paymentIntent.id,
            clientId: uid,
            hostId,
            mealId,
            source: 'createPaymentIntentWithFee',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {
            merge: true,
          }),
        ]);

        return {
          orderId,
          paymentIntentId: paymentIntent.id,
          clientSecret: paymentIntent.client_secret,
        };
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }

        logger.error('createPaymentIntentWithFee failed', {
          functionName: 'createPaymentIntentWithFee',
          uid,
          orderId,
          step,
          stripeRequestId: getStripeRequestId(error),
          stripeType: error && error.type ? error.type : null,
          stripeCode: error && error.code ? error.code : null,
          stripeDeclineCode: error && error.decline_code ? error.decline_code : null,
          error: error instanceof Error ? error.message : String(error),
        });
        console.error('[createPaymentIntentWithFee] failure', {
          uid,
          orderId,
          step,
          error: error instanceof Error ? {
            name: error.name,
            message: error.message,
            stack: error.stack,
          } : String(error),
        });
        throw new HttpsError(
            'internal',
            `createPaymentIntentWithFee failed at step "${step}".`,
            {
              message: `Erreur interne creation PaymentIntent (step: ${step}).`,
              functionName: 'createPaymentIntentWithFee',
              orderId,
              step,
            },
        );
      }
    },
);

function
assertHostTransition(order, nextStatus) {
  if (order.status !== ORDER_STATUS.PENDING) {
    throw new HttpsError('failed-precondition', 'Only pending orders can be transitioned by host.');
  }

  if (nextStatus === ORDER_STATUS.CONFIRMED) {
    if (order.paymentStatus !== PAYMENT_STATUS.PAID) {
      throw new HttpsError('failed-precondition', 'Order must be paid before confirmation.');
    }
    return;
  }

  if (nextStatus === ORDER_STATUS.REJECTED) {
    if (order.paymentStatus === PAYMENT_STATUS.PAID) {
      throw new HttpsError('failed-precondition', 'Paid orders cannot be rejected.');
    }
    return;
  }

  throw new HttpsError('permission-denied', 'Host cannot apply this transition.');
}

function
assertClientTransition(order, nextStatus) {
  if (nextStatus !== ORDER_STATUS.CANCELLED) {
    throw new HttpsError('permission-denied', 'Client can only cancel an order.');
  }

  if (order.status !== ORDER_STATUS.PENDING) {
    throw new HttpsError('failed-precondition', 'Only pending orders can be cancelled.');
  }

  if (order.paymentStatus !== PAYMENT_STATUS.REQUIRES_PAYMENT) {
    throw new HttpsError('failed-precondition', 'Paid or failed orders cannot be cancelled by client.');
  }
}

exports.transitionOrderStatus = onCall(
    {
      region: REGION,
    },
    async (request) => {
      const uid = assertAuthenticated(request);
      const orderId = request.data ?.orderId;
      const nextStatus = request.data ?.nextStatus;

      if (!orderId || typeof orderId !== 'string') {
        throw new HttpsError('invalid-argument', 'orderId is required.');
      }
      if (!nextStatus || typeof nextStatus !== 'string') {
        throw new HttpsError('invalid-argument', 'nextStatus is required.');
      }

      const allowedStatuses = new Set([
        ORDER_STATUS.CONFIRMED,
        ORDER_STATUS.REJECTED,
        ORDER_STATUS.CANCELLED,
      ]);
      if (!allowedStatuses.has(nextStatus)) {
        throw new HttpsError('invalid-argument', 'Unsupported status transition.');
      }

      const orderRef = db.collection('orders').doc(orderId);
      const snapshot = await orderRef.get();
      if (!snapshot.exists) {
        throw new HttpsError('not-found', 'Order not found.');
      }

      const order = snapshot.data();
      if (!order) {
        throw new HttpsError('internal', 'Order payload missing.');
      }

      if (uid === order.hostId) {
        assertHostTransition(order, nextStatus);
      } else if (uid === order.clientId) {
        assertClientTransition(order, nextStatus);
      } else {
        throw new HttpsError('permission-denied', 'Only order participants can transition order status.');
      }

      await orderRef.set({
        status: nextStatus,
      }, {
        merge: true,
      });

      return {
        orderId,
        status: nextStatus,
      };
    },
);

exports.deleteAccountAndData = onCall(
    {
      region: REGION,
    },
    async (request) => {
      const uid = assertAuthenticated(request);
      logger.info('deleteAccountAndData called', {
        functionName: 'deleteAccountAndData',
        uid,
      });

      let step = 'delete_orders_client';
      let deletedOrdersClient = 0;
      let deletedOrdersHost = 0;
      let deletedMeals = 0;
      let deletedPaymentMappingsClient = 0;
      let deletedPaymentMappingsHost = 0;

      const deleteByQuery = async (queryBuilder) => {
        let deleted = 0;
        const batchSize = 200;
        let hasMore = true;
        while (hasMore) {
          const snapshot = await queryBuilder.limit(batchSize).get();
          if (snapshot.empty) {
            break;
          }

          const batch = db.batch();
          snapshot.docs.forEach((doc) => batch.delete(doc.ref));
          await batch.commit();
          deleted += snapshot.size;

          hasMore = snapshot.size === batchSize;
        }
        return deleted;
      };

      try {
        deletedOrdersClient = await deleteByQuery(
            db.collection('orders').where('clientId', '==', uid),
        );

        step = 'delete_orders_host';
        deletedOrdersHost = await deleteByQuery(
            db.collection('orders').where('hostId', '==', uid),
        );

        step = 'delete_meals_host';
        deletedMeals = await deleteByQuery(
            db.collection('meals').where('hostId', '==', uid),
        );

        step = 'delete_payment_mappings_client';
        deletedPaymentMappingsClient = await deleteByQuery(
            db.collection(PAYMENT_INTENT_ORDERS_COLLECTION).where('clientId', '==', uid),
        );

        step = 'delete_payment_mappings_host';
        deletedPaymentMappingsHost = await deleteByQuery(
            db.collection(PAYMENT_INTENT_ORDERS_COLLECTION).where('hostId', '==', uid),
        );

        step = 'delete_user_profile';
        await db.collection('users').doc(uid).set({
          accountDeletionRequestedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {
          merge: true,
        });
        await db.collection('users').doc(uid).delete();

        step = 'delete_auth_user';
        try {
          await admin.auth().deleteUser(uid);
        } catch (authError) {
          const authCode = authError && authError.code ? authError.code : null;
          if (authCode !== 'auth/user-not-found') {
            throw authError;
          }
        }

        logger.info('deleteAccountAndData success', {
          functionName: 'deleteAccountAndData',
          uid,
          deletedOrdersClient,
          deletedOrdersHost,
          deletedMeals,
          deletedPaymentMappingsClient,
          deletedPaymentMappingsHost,
        });

        return {
          ok: true,
          deletedOrdersClient,
          deletedOrdersHost,
          deletedMeals,
          deletedPaymentMappingsClient,
          deletedPaymentMappingsHost,
        };
      } catch (error) {
        logger.error('deleteAccountAndData failed', {
          functionName: 'deleteAccountAndData',
          uid,
          step,
          error: error instanceof Error ? error.message : String(error),
        });
        console.error('[deleteAccountAndData] failure', {
          uid,
          step,
          error: error instanceof Error ? {
            name: error.name,
            message: error.message,
            stack: error.stack,
          } : String(error),
        });
        throw new HttpsError(
            'internal',
            `deleteAccountAndData failed at step "${step}".`,
            {
              message: `Suppression de compte echouee (step: ${step}).`,
              functionName: 'deleteAccountAndData',
              uid,
              step,
            },
        );
      }
    },
);

function
collectStringValues(value) {
  if (typeof value === 'string') {
    const trimmed = value.trim();
    return trimmed ? [trimmed] : [];
  }

  if (!Array.isArray(value)) {
    return [];
  }

  return value
      .filter((item) => typeof item === 'string')
      .map((item) => item.trim())
      .filter((item) => item.length > 0);
}

function
extractStoragePath(candidate) {
  if (typeof candidate !== 'string') {
    return null;
  }

  const raw = candidate.trim();
  if (!raw) {
    return null;
  }

  if (raw.startsWith('gs://')) {
    const noScheme = raw.slice('gs://'.length);
    const firstSlash = noScheme.indexOf('/');
    if (firstSlash === -1) {
      return null;
    }
    return noScheme.slice(firstSlash + 1);
  }

  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    try {
      const parsed = new URL(raw);
      const marker = '/o/';
      const markerIndex = parsed.pathname.indexOf(marker);
      if (markerIndex === -1) {
        return null;
      }
      const encodedPath = parsed.pathname.slice(markerIndex + marker.length);
      return decodeURIComponent(encodedPath);
    } catch (error) {
      return null;
    }
  }

  return raw.replace(/^\/+/, '');
}

function
collectMealImagePaths(meal) {
  const candidates = [
    ...collectStringValues(meal ?.imagePath),
    ...collectStringValues(meal ?.imagePaths),
    ...collectStringValues(meal ?.storagePath),
    ...collectStringValues(meal ?.storagePaths),
    ...collectStringValues(meal ?.photoPath),
    ...collectStringValues(meal ?.photoPaths),
    ...collectStringValues(meal ?.imageURL),
    ...collectStringValues(meal ?.imageUrls),
    ...collectStringValues(meal ?.imageURLs),
  ];

  const normalized = candidates
      .map((path) => extractStoragePath(path))
      .filter((path) => typeof path === 'string' && path.length > 0);

  return [...new Set(normalized)];
}

async function
deleteMealStoragePaths(mealId, uid, storagePaths) {
  if (!storagePaths.length) {
    logger.info('deleteMeal storage skipped', {
      functionName: 'deleteMeal',
      uid,
      mealId,
      step: 'deletedStorage',
      deletedCount: 0,
      failedCount: 0,
    });
    return {
      deletedCount: 0,
      failedCount: 0,
    };
  }

  const bucket = admin.storage().bucket();
  let deletedCount = 0;
  let failedCount = 0;

  for (const storagePath of storagePaths) {
    try {
      await bucket.file(storagePath).delete({
        ignoreNotFound: true,
      });
      deletedCount += 1;
    } catch (error) {
      failedCount += 1;
      logger.warn('deleteMeal failed to delete storage object', {
        functionName: 'deleteMeal',
        uid,
        mealId,
        storagePath,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  logger.info('deleteMeal storage completed', {
    functionName: 'deleteMeal',
    uid,
    mealId,
    step: 'deletedStorage',
    deletedCount,
    failedCount,
  });

  return {
    deletedCount,
    failedCount,
  };
}

exports.deleteMeal = onCall(
    {
      region: REGION,
    },
    async (request) => {
      const uid = assertAuthenticated(request);
      const mealId = getStringField(request.data ?.mealId);

      logger.info('deleteMeal called', {
        functionName: 'deleteMeal',
        uid,
        mealId: mealId || null,
        step: 'requested',
      });

      if (!mealId) {
        throw new HttpsError('invalid-argument', 'mealId is required.');
      }

      let step = 'load_meal';
      try {
        let mealRef = db.collection('meals').doc(mealId);
        let snapshot = await mealRef.get();

        if (!snapshot.exists) {
          step = 'fallback_lookup_legacy_id';
          logger.warn('deleteMeal direct lookup missed, trying fallback by field id', {
            functionName: 'deleteMeal',
            uid,
            mealId,
          });

          const legacySnapshot = await db.collection('meals')
              .where('id', '==', mealId)
              .limit(1)
              .get();

          if (!legacySnapshot.empty) {
            const matchedDoc = legacySnapshot.docs[0];
            mealRef = matchedDoc.ref;
            snapshot = matchedDoc;
            logger.info('deleteMeal fallback matched meal document', {
              functionName: 'deleteMeal',
              uid,
              mealId,
              matchedDocumentId: matchedDoc.id,
            });
          }
        }

        if (!snapshot.exists) {
          throw new HttpsError('not-found', 'Meal not found.', {
            message: `Aucun document meals/${mealId} trouve.`,
            functionName: 'deleteMeal',
            mealId,
            step,
          });
        }

        const meal = snapshot.data() || {};
        const ownerId = getStringField(meal.hostId) ||
          getStringField(meal.ownerId) ||
          getStringField(meal.userId);

        if (!ownerId) {
          throw new HttpsError('failed-precondition', 'Meal owner is missing.');
        }

        if (ownerId !== uid) {
          throw new HttpsError('permission-denied', 'You can only delete your own meals.');
        }

        logger.info('deleteMeal authorized', {
          functionName: 'deleteMeal',
          uid,
          mealId,
          ownerId,
          documentId: mealRef.id,
          step: 'authorized',
        });

        const storagePaths = collectMealImagePaths(meal);

        step = 'delete_firestore';
        await mealRef.delete();
        logger.info('deleteMeal firestore deleted', {
          functionName: 'deleteMeal',
          uid,
          mealId,
          documentId: mealRef.id,
          step: 'deletedFirestore',
        });

        step = 'delete_storage';
        const {
          deletedCount,
          failedCount,
        } = await deleteMealStoragePaths(mealId, uid, storagePaths);

        logger.info('deleteMeal done', {
          functionName: 'deleteMeal',
          uid,
          mealId,
          documentId: mealRef.id,
          step: 'done',
          deletedStorageCount: deletedCount,
          failedStorageDeletes: failedCount,
        });

        return {
          ok: true,
          documentId: mealRef.id,
          deletedStorageCount: deletedCount,
          failedStorageDeletes: failedCount,
        };
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }

        logger.error('deleteMeal failed', {
          functionName: 'deleteMeal',
          uid,
          mealId,
          step,
          error: error instanceof Error ? error.message : String(error),
        });
        throw new HttpsError(
            'internal',
            `deleteMeal failed at step "${step}".`,
            {
              message: `Erreur interne suppression meal (step: ${step}).`,
              hint: 'Verifier ownerId/hostId, permissions et existence du document meals/{mealId}.',
              functionName: 'deleteMeal',
              uid,
              mealId,
              step,
            },
        );
      }
    },
);

exports.backfillMealLocations = onCall(
    {
      region: REGION,
    },
    async (request) => {
      const uid = assertAuthenticated(request);
      const isAdmin = request.auth ?.token ?.admin === true;
      const requestedOnlyMine = request.data ?.onlyMine !== false;
      if (!requestedOnlyMine && !isAdmin) {
        throw new HttpsError('permission-denied', 'Only admins can backfill all meals.');
      }
      const onlyMine = requestedOnlyMine || !isAdmin;
      const dryRun = request.data ?.dryRun === true;
      const fallbackLocation = new admin.firestore.GeoPoint(52.3676, 4.9041);
      const fallbackCity = 'Amsterdam';

      logger.info('backfillMealLocations called', {
        functionName: 'backfillMealLocations',
        uid,
        onlyMine,
        dryRun,
      });

      let step = 'query_meals';
      try {
        let query = db.collection('meals');
        if (onlyMine) {
          query = query.where('hostId', '==', uid);
        }

        const mealsSnapshot = await query.limit(500).get();
        let processedCount = 0;
        let updatedCount = 0;

        const batch = db.batch();
        mealsSnapshot.docs.forEach((doc) => {
          processedCount += 1;
          const meal = doc.data() || {};
          const hasLocation = Boolean(meal.location) || Boolean(meal.geoPoint);

          if (hasLocation) {
            return;
          }

          updatedCount += 1;
          if (!dryRun) {
            batch.set(doc.ref, {
              location: fallbackLocation,
              locationName: getStringField(meal.locationName) ||
                getStringField(meal.city) ||
                fallbackCity,
              city: getStringField(meal.city) || fallbackCity,
              locationBackfilledAt: admin.firestore.FieldValue.serverTimestamp(),
              locationBackfilledBy: uid,
            }, {
              merge: true,
            });
          }
        });

        step = 'commit_batch';
        if (!dryRun && updatedCount > 0) {
          await batch.commit();
        }

        logger.info('backfillMealLocations completed', {
          functionName: 'backfillMealLocations',
          uid,
          onlyMine,
          dryRun,
          processedCount,
          updatedCount,
        });

        return {
          ok: true,
          processedCount,
          updatedCount,
          dryRun,
        };
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }
        console.error('[backfillMealLocations] failure', {
          uid,
          onlyMine,
          dryRun,
          step,
          error: error instanceof Error ? {
            name: error.name,
            message: error.message,
            stack: error.stack,
          } : String(error),
        });
        logger.error('backfillMealLocations failed', {
          functionName: 'backfillMealLocations',
          uid,
          onlyMine,
          dryRun,
          step,
          error: error instanceof Error ? error.message : String(error),
        });
        throw new HttpsError(
            'internal',
            `backfillMealLocations failed at step "${step}".`,
            {
              message: `Erreur interne backfill locations (step: ${step}).`,
              hint: 'Verifier existence de la collection meals et permissions service account.',
              functionName: 'backfillMealLocations',
              uid,
              onlyMine,
              dryRun,
              step,
            },
        );
      }
    },
);

function
getStringField(value) {
  return typeof value === 'string' && value.trim().length > 0 ? value : null;
}

function
getServiceModeField(value, allowedModes, fieldName) {
  if (value === undefined || value === null) {
    return null;
  }
  const mode = getStringField(value);
  if (!mode || !allowedModes.has(mode)) {
    throw new HttpsError('invalid-argument', `${fieldName} is invalid.`);
  }
  return mode;
}

function
extractMetadataOrderId(stripeObject) {
  return getStringField(stripeObject ?.metadata ?.orderId);
}

function
extractPaymentIntentIdFromCharge(chargeObject) {
  const paymentIntent = chargeObject ?.payment_intent;
  if (typeof paymentIntent === 'string' && paymentIntent.trim().length > 0) {
    return paymentIntent;
  }
  if (paymentIntent && typeof paymentIntent.id === 'string' && paymentIntent.id.trim().length > 0) {
    return paymentIntent.id;
  }
  return null;
}

async function
enrichOrderIdFromPaymentIntentMetadata(stripe, paymentIntentId, currentOrderId, eventId, eventType) {
  if (currentOrderId) {
    return currentOrderId;
  }
  if (!paymentIntentId) {
    return null;
  }

  try {
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
    return getStringField(paymentIntent ?.metadata ?.orderId);
  } catch (error) {
    logger.warn('Failed to retrieve PaymentIntent metadata for webhook event', {
      eventId,
      eventType,
      paymentIntentId,
      error: error instanceof Error ? error.message : String(error),
    });
    return null;
  }
}

async function
recordOrphanStripeEvent({
  eventId, eventType, paymentIntentId, metadataOrderId,
}) {
  await db.collection('orphan_events').doc(eventId).set({
    eventId,
    eventType,
    paymentIntentId: paymentIntentId || null,
    metadataOrderId: metadataOrderId || null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {
    merge: true,
  });
}

async function
upsertPaymentIntentOrderMapping({
  paymentIntentId, orderId, source, eventId, eventType,
}) {
  try {
    await db.collection(PAYMENT_INTENT_ORDERS_COLLECTION).doc(paymentIntentId).set({
      orderId,
      paymentIntentId,
      source,
      lastEventId: eventId || null,
      lastEventType: eventType || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {
      merge: true,
    });
  } catch (error) {
    logger.warn('Failed to upsert payment intent mapping', {
      eventId,
      eventType,
      paymentIntentId,
      orderId,
      source,
      error: error instanceof Error ? error.message : String(error),
    });
  }
}

async function
findOrderRefByPaymentIntentOrMetadata({
  paymentIntentId, metadataOrderId, eventId, eventType,
}) {
  const mappingRef = db.collection(PAYMENT_INTENT_ORDERS_COLLECTION).doc(paymentIntentId);
  const mappingSnapshot = await mappingRef.get();
  if (mappingSnapshot.exists) {
    const mappedOrderId = getStringField(mappingSnapshot.data() ?.orderId);
    if (mappedOrderId) {
      const mappedOrderRef = db.collection('orders').doc(mappedOrderId);
      const mappedOrderSnapshot = await mappedOrderRef.get();
      if (mappedOrderSnapshot.exists) {
        return {
          orderRef: mappedOrderRef,
          lookupSource: 'paymentIntentMapping',
        };
      }
      logger.error('PaymentIntent mapping points to missing order', {
        eventId,
        eventType,
        paymentIntentId,
        mappedOrderId,
      });
    } else {
      logger.warn('PaymentIntent mapping missing orderId', {
        eventId,
        eventType,
        paymentIntentId,
      });
    }
  }

  const byPaymentIntentSnapshot = await db.collection('orders')
      .where('paymentIntentId', '==', paymentIntentId)
      .limit(1)
      .get();

  if (!byPaymentIntentSnapshot.empty) {
    const orderRef = byPaymentIntentSnapshot.docs[0].ref;
    await upsertPaymentIntentOrderMapping({
      paymentIntentId,
      orderId: orderRef.id,
      source: 'webhook.paymentIntentId',
      eventId,
      eventType,
    });
    return {
      orderRef,
      lookupSource: 'paymentIntentId',
    };
  }

  if (metadataOrderId) {
    const byOrderIdRef = db.collection('orders').doc(metadataOrderId);
    const byOrderIdSnapshot = await byOrderIdRef.get();
    if (byOrderIdSnapshot.exists) {
      const orderData = byOrderIdSnapshot.data() || {};
      if (orderData.paymentIntentId !== paymentIntentId) {
        await byOrderIdRef.set({
          paymentIntentId,
        }, {
          merge: true,
        });
        logger.warn('Backfilled paymentIntentId from Stripe metadata.orderId', {
          eventId,
          eventType,
          orderId: byOrderIdRef.id,
          paymentIntentId,
        });
      }
      await upsertPaymentIntentOrderMapping({
        paymentIntentId,
        orderId: byOrderIdRef.id,
        source: 'webhook.metadata.orderId',
        eventId,
        eventType,
      });
      return {
        orderRef: byOrderIdRef,
        lookupSource: 'metadata.orderId',
      };
    }
  }

  logger.error('Order not found for Stripe event', {
    eventId,
    eventType,
    paymentIntentId,
    metadataOrderId: metadataOrderId || null,
  });
  await recordOrphanStripeEvent({
    eventId,
    eventType,
    paymentIntentId,
    metadataOrderId,
  });
  return null;
}

async function
applyStripePaymentEventToOrder({
  orderRef, eventId, eventType, paymentIntentId, lookupSource,
}) {
  const isSuccessEvent = eventType === 'payment_intent.succeeded' || eventType === 'charge.succeeded';
  const isFailedEvent = eventType === 'payment_intent.payment_failed';
  if (!isSuccessEvent && !isFailedEvent) {
    logger.warn('Unsupported Stripe payment event type for order update', {
      eventId,
      eventType,
      paymentIntentId,
      orderId: orderRef.id,
    });
    return;
  }

  await db.runTransaction(async (tx) => {
    const orderSnap = await tx.get(orderRef);
    if (!orderSnap.exists) {
      logger.error('Order disappeared before Stripe event update', {
        eventId,
        eventType,
        paymentIntentId,
        orderId: orderRef.id,
      });
      return;
    }

    const order = orderSnap.data() || {};
    if (order.status !== ORDER_STATUS.PENDING) {
      logger.info('Ignoring Stripe event for non-pending order', {
        eventId,
        eventType,
        paymentIntentId,
        orderId: orderRef.id,
        lookupSource,
        currentStatus: order.status,
        currentPaymentStatus: order.paymentStatus,
      });
      return;
    }

    if (isSuccessEvent) {
      if (order.paymentStatus === PAYMENT_STATUS.PAID) {
        logger.info('Ignoring duplicate paid Stripe event', {
          eventId,
          eventType,
          paymentIntentId,
          orderId: orderRef.id,
          lookupSource,
        });
        return;
      }

      tx.set(orderRef, {
        paymentStatus: PAYMENT_STATUS.PAID,
        status: ORDER_STATUS.CONFIRMED,
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {
        merge: true,
      });
      return;
    }

    if (order.paymentStatus !== PAYMENT_STATUS.REQUIRES_PAYMENT) {
      logger.info('Ignoring payment_failed for transitioned order', {
        eventId,
        eventType,
        paymentIntentId,
        orderId: orderRef.id,
        lookupSource,
        currentPaymentStatus: order.paymentStatus,
      });
      return;
    }

    tx.set(orderRef, {
      paymentStatus: PAYMENT_STATUS.FAILED,
      paymentFailedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {
      merge: true,
    });
  });
}

async function
handleAccountUpdated(account) {
  const stripeAccountId = account.id;
  const stripeStatus = computeStripeStatusFromAccount(account);
  const onboarded = stripeStatus === 'ready';

  const snapshot = await db.collection('users')
      .where('stripeAccountId', '==', stripeAccountId)
      .limit(1)
      .get();

  if (snapshot.empty) {
    logger.info('No user found for stripeAccountId', {
      stripeAccountId,
    });
    return;
  }

  await snapshot.docs[0].ref.set({
    stripeOnboarded: onboarded,
    stripeStatus,
    stripeUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {
    merge: true,
  });
}

exports.stripeWebhook = onRequest(
    {
      region: REGION,
      secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET],
      cors: false,
    },
    async (req, res) => {
      if (req.method !== 'POST') {
        res.status(405).send('Method Not Allowed');
        return;
      }

      const signatureHeader = req.headers['stripe-signature'];
      const signature = Array.isArray(signatureHeader) ? signatureHeader[0] : signatureHeader;
      if (!signature || typeof signature !== 'string') {
        res.status(400).send('Missing stripe-signature header');
        return;
      }

      const stripe = getStripeClient();

      let event;
      try {
        // IMPORTANT: req.rawBody is used for Stripe signature verification.
        event = stripe.webhooks.constructEvent(
            req.rawBody,
            signature,
            STRIPE_WEBHOOK_SECRET.value(),
        );
      } catch (error) {
        logger.error('Stripe webhook signature verification failed', {
          error: error instanceof Error ? error.message : String(error),
        });
        res.status(400).send('Invalid signature');
        return;
      }

      try {
        switch (event.type) {
          case 'payment_intent.succeeded':
          case 'payment_intent.payment_failed':
          case 'charge.succeeded': {
            const stripeObject = event.data ?.object || {};
            let paymentIntentId;
            let metadataOrderId = extractMetadataOrderId(stripeObject);

            if (event.type === 'charge.succeeded') {
              paymentIntentId = extractPaymentIntentIdFromCharge(stripeObject);
              metadataOrderId = await enrichOrderIdFromPaymentIntentMetadata(
                  stripe,
                  paymentIntentId,
                  metadataOrderId,
                  event.id,
                  event.type,
              );
            } else {
              paymentIntentId = getStringField(stripeObject.id);
            }

            if (!paymentIntentId) {
              logger.error('Stripe webhook payload missing paymentIntentId', {
                eventId: event.id,
                eventType: event.type,
              });
              res.status(400).send('Invalid event payload');
              return;
            }

            const orderLookup = await findOrderRefByPaymentIntentOrMetadata({
              paymentIntentId,
              metadataOrderId,
              eventId: event.id,
              eventType: event.type,
            });

            if (!orderLookup) {
              res.status(200).json({
                received: true,
                orphan: true,
              });
              return;
            }

            await applyStripePaymentEventToOrder({
              orderRef: orderLookup.orderRef,
              lookupSource: orderLookup.lookupSource,
              eventId: event.id,
              eventType: event.type,
              paymentIntentId,
            });
            break;
          }

          case 'account.updated': {
            const account = event.data.object;
            await handleAccountUpdated(account);
            break;
          }

          default:
            logger.info('Unhandled Stripe event', {
              type: event.type,
            });
        }

        res.status(200).json({
          received: true,
        });
      } catch (error) {
        logger.error('Stripe webhook handler failed', error);
        res.status(500).send('Webhook handler failed');
      }
    },
);

exports.confirmApplePayPayment = onCall(
    {
      region: REGION,
      secrets: [STRIPE_SECRET_KEY],
    },
    async (request) => {
      const uid = assertAuthenticated(request);
      const orderId = request.data ?.orderId;
      const applePayToken = request.data ?.applePayToken;

      logger.info('confirmApplePayPayment called', {
        functionName: 'confirmApplePayPayment',
        uid,
        orderId: typeof orderId === 'string' ? orderId : null,
      });

      if (!orderId || typeof orderId !== 'string') {
        throw new HttpsError('invalid-argument', 'orderId is required.');
      }
      if (!applePayToken || typeof applePayToken !== 'string') {
        throw new HttpsError('invalid-argument', 'applePayToken is required.');
      }

      let step = 'load_order';
      try {
        const orderRef = db.collection('orders').doc(orderId);
        const orderSnapshot = await orderRef.get();

        if (!orderSnapshot.exists) {
          throw new HttpsError('not-found', 'Order not found.');
        }

        const order = orderSnapshot.data();
        if (!order) {
          throw new HttpsError('internal', 'Order payload missing.');
        }

        if (order.clientId !== uid) {
          throw new HttpsError('permission-denied', 'Not your order.');
        }

        const paymentIntentId = getStringField(order.paymentIntentId);
        if (!paymentIntentId) {
          throw new HttpsError('failed-precondition', 'Order missing paymentIntentId.');
        }

        if (order.paymentStatus === PAYMENT_STATUS.PAID) {
          logger.info('confirmApplePayPayment order already paid', {
            functionName: 'confirmApplePayPayment',
            uid,
            orderId,
            paymentIntentId,
          });
          return {
            ok: true,
            orderId,
            paymentIntentId,
            alreadyPaid: true,
          };
        }

        step = 'create_payment_method';
        const stripe = getStripeClient();
        const paymentMethod = await stripe.paymentMethods.create({
          type: 'card',
          card: {
            token: applePayToken,
          },
        });

        step = 'confirm_payment_intent';
        const confirmedIntent = await stripe.paymentIntents.confirm(paymentIntentId, {
          payment_method: paymentMethod.id,
        });

        if (confirmedIntent.status !== 'succeeded') {
          logger.warn('confirmApplePayPayment PaymentIntent not succeeded', {
            functionName: 'confirmApplePayPayment',
            uid,
            orderId,
            paymentIntentId,
            status: confirmedIntent.status,
          });
          throw new HttpsError('failed-precondition', 'Payment not confirmed.');
        }

        step = 'wait_webhook_confirmation';
        await orderRef.set({
          paymentConfirmationStartedAt: admin.firestore.FieldValue.serverTimestamp(),
          paymentStatus: PAYMENT_STATUS.REQUIRES_PAYMENT,
        }, {
          merge: true,
        });

        logger.info('confirmApplePayPayment success', {
          functionName: 'confirmApplePayPayment',
          uid,
          orderId,
          paymentIntentId,
        });

        return {
          ok: true,
          orderId,
          paymentIntentId,
          confirmationPending: true,
        };
      } catch (error) {
        if (error instanceof HttpsError) {
          throw error;
        }

        logger.error('confirmApplePayPayment failed', {
          functionName: 'confirmApplePayPayment',
          uid,
          orderId: typeof orderId === 'string' ? orderId : null,
          step,
          stripeRequestId: getStripeRequestId(error),
          stripeType: error && error.type ? error.type : null,
          stripeCode: error && error.code ? error.code : null,
          stripeDeclineCode: error && error.decline_code ? error.decline_code : null,
          error: error instanceof Error ? error.message : String(error),
        });
        throw new HttpsError('internal', 'Unable to confirm Apple Pay payment.');
      }
    },
);

exports.callOpenAIAgent = onRequest(
    {
      region: 'europe-west1',
      secrets: ['OPENAI_API_KEY'],
    },
    async (req, res) => {
      res.set('Access-Control-Allow-Origin', '*');
      res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }

      const bodyMessage = req.body &&
        typeof req.body.message === 'string' ? req.body.message : undefined;
      const queryMessageRaw = req.query.message;
      const queryMessage = Array.isArray(queryMessageRaw) ?
        queryMessageRaw[0] : queryMessageRaw;
      const message = (bodyMessage || queryMessage || '').trim();

      if (!message) {
        res.status(400).json({
          ok: false,
          error: 'message is required',
        });
        return;
      }

      try {
        if (!process.env.OPENAI_API_KEY) {
          throw new Error('OPENAI_API_KEY is not set');
        }

        setDefaultOpenAIKey(process.env.OPENAI_API_KEY);

        const agent = new Agent({
          name: 'HomelyBitesAgent',
          instructions: 'You are HomelyBites assistant. Reply with clear and concise answers.',
        });

        const result = await run(agent, message);
        const output = typeof result.finalOutput === 'string' ?
          result.finalOutput : JSON.stringify(result.finalOutput);

        res.status(200).json({
          ok: true,
          output,
        });
      } catch (error) {
        console.error(error);
        res.status(500).json({
          error: 'internal',
        });
      }
    },
);
