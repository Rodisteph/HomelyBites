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
  return new Stripe(STRIPE_SECRET_KEY.value());
}

function
assertAuthenticated(request) {
  if (!request.auth ?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }
  return request.auth.uid;
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

exports.createConnectAccount = onCall(
    {
      region: REGION,
      secrets: [STRIPE_SECRET_KEY],
    },
    async (request) => {
      const uid = assertAuthenticated(request);
      const {
        userRef, userData,
      } = await getUserProfile(uid);
      assertHost(userData);

      if (userData.stripeAccountId) {
        return {
          accountId: userData.stripeAccountId,
          stripeOnboarded: Boolean(userData.stripeOnboarded),
          alreadyExists: true,
        };
      }

      const stripe = getStripeClient();
      const account = await stripe.accounts.create({
        type: 'express',
        email: request.auth.token.email || undefined,
        metadata: {
          uid,
        },
      });

      await userRef.set({
        stripeAccountId: account.id,
        stripeOnboarded: false,
      }, {
        merge: true,
      });

      return {
        accountId: account.id,
        stripeOnboarded: false,
        alreadyExists: false,
      };
    },
);

exports.createOnboardingLink = onCall(
    {
      region: REGION,
      secrets: [STRIPE_SECRET_KEY],
    },
    async (request) => {
      const uid = assertAuthenticated(request);
      const {
        userData,
      } = await getUserProfile(uid);
      assertHost(userData);

      if (!userData.stripeAccountId) {
        throw new HttpsError(
            'failed-precondition',
            'Host has no Stripe account yet. Call createConnectAccount first.',
        );
      }

      const stripe = getStripeClient();
      const link = await stripe.accountLinks.create({
        account: userData.stripeAccountId,
        refresh_url: ONBOARDING_REFRESH_URL,
        return_url: ONBOARDING_RETURN_URL,
        type: 'account_onboarding',
      });

      return {
        url: link.url,
        expiresAt: link.expires_at,
      };
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
      const hostId = meal ?.hostId;
      if (!Number.isInteger(priceCents) || priceCents <= 0) {
        throw new HttpsError('failed-precondition', 'Meal has an invalid price.');
      }
      if (!hostId || typeof hostId !== 'string') {
        throw new HttpsError('failed-precondition', 'Meal host is missing.');
      }

      const {
        userData: hostData,
      } = await getUserProfile(hostId);
      assertHost(hostData);
      const hostStripeAccountId = hostData.stripeAccountId;
      if (!hostStripeAccountId || typeof hostStripeAccountId !== 'string') {
        throw new HttpsError('failed-precondition', 'Host Stripe account missing.');
      }
      if (!hostData.stripeOnboarded) {
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
          },
        }, {
          idempotencyKey: `create_order_${orderId}`,
        });
      } catch (error) {
        logger.error('Failed to create Stripe PaymentIntent', {
          orderId,
          mealId,
          clientId: uid,
          error: error instanceof Error ? error.message : String(error),
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

function
getStringField(value) {
  return typeof value === 'string' && value.trim().length > 0 ? value : null;
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
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
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
  const onboarded = Boolean(account.charges_enabled && account.payouts_enabled);

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
