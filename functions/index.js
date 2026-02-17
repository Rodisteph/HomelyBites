const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const Stripe = require("stripe");

admin.initializeApp();
const db = admin.firestore();

const REGION = "europe-west1";
const PLATFORM_FEE_BPS = 1500; // 15.00%

const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");

const ONBOARDING_RETURN_URL = "homelybites://onboarding/return";
const ONBOARDING_REFRESH_URL = "homelybites://onboarding/refresh";

function getStripeClient() {
  return new Stripe(STRIPE_SECRET_KEY.value());
}

function assertAuthenticated(request) {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  return request.auth.uid;
}

async function getUserProfile(uid) {
  const userRef = db.collection("users").doc(uid);
  const userSnapshot = await userRef.get();

  if (!userSnapshot.exists) {
    throw new HttpsError("failed-precondition", "User profile not found.");
  }

  return {
    userRef,
    userData: userSnapshot.data(),
  };
}

function assertHost(userData) {
  if (userData.role !== "host") {
    throw new HttpsError("permission-denied", "Host account required.");
  }
}

exports.createConnectAccount = onCall(
    {
      region: REGION,
      secrets: [STRIPE_SECRET_KEY],
    },
    async (request) => {
      const uid = assertAuthenticated(request);
      const {userRef, userData} = await getUserProfile(uid);
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
        type: "express",
        email: request.auth.token.email || undefined,
        metadata: {
          uid,
        },
      });

      await userRef.set({
        stripeAccountId: account.id,
        stripeOnboarded: false,
      }, {merge: true});

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
      const {userData} = await getUserProfile(uid);
      assertHost(userData);

      if (!userData.stripeAccountId) {
        throw new HttpsError(
            "failed-precondition",
            "Host has no Stripe account yet. Call createConnectAccount first.",
        );
      }

      const stripe = getStripeClient();
      const link = await stripe.accountLinks.create({
        account: userData.stripeAccountId,
        refresh_url: ONBOARDING_REFRESH_URL,
        return_url: ONBOARDING_RETURN_URL,
        type: "account_onboarding",
      });

      return {
        url: link.url,
        expiresAt: link.expires_at,
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
      const orderId = request.data?.orderId;

      if (!orderId || typeof orderId !== "string") {
        throw new HttpsError("invalid-argument", "orderId is required.");
      }

      const orderRef = db.collection("orders").doc(orderId);
      const orderSnapshot = await orderRef.get();

      if (!orderSnapshot.exists) {
        throw new HttpsError("not-found", "Order not found.");
      }

      const order = orderSnapshot.data();

      if (order.clientId !== uid) {
        throw new HttpsError("permission-denied", "Order does not belong to caller.");
      }

      if (order.paymentStatus !== "requires_payment") {
        throw new HttpsError(
            "failed-precondition",
            "Order is not in requires_payment state.",
        );
      }

      if (!order.hostStripeAccountId || typeof order.hostStripeAccountId !== "string") {
        throw new HttpsError("failed-precondition", "Host Stripe account missing.");
      }

      if (!Number.isInteger(order.amountCents) || order.amountCents <= 0) {
        throw new HttpsError("failed-precondition", "Invalid amountCents on order.");
      }

      const currency = (order.currency || "eur").toLowerCase();
      if (currency !== "eur") {
        throw new HttpsError("failed-precondition", "Only EUR is supported in MVP.");
      }

      const stripe = getStripeClient();

      if (order.paymentIntentId) {
        const existingIntent = await stripe.paymentIntents.retrieve(order.paymentIntentId);
        if (existingIntent?.client_secret) {
          return {clientSecret: existingIntent.client_secret};
        }
      }

      const applicationFeeAmount = Math.round(order.amountCents * (PLATFORM_FEE_BPS / 10000));

      const paymentIntent = await stripe.paymentIntents.create({
        amount: order.amountCents,
        currency,
        automatic_payment_methods: {
          enabled: true,
        },
        application_fee_amount: applicationFeeAmount,
        transfer_data: {
          destination: order.hostStripeAccountId,
        },
        metadata: {
          orderId,
          mealId: order.mealId,
          clientId: order.clientId,
          hostId: order.hostId,
        },
      });

      await orderRef.set({
        paymentIntentId: paymentIntent.id,
      }, {merge: true});

      if (!paymentIntent.client_secret) {
        throw new HttpsError("internal", "PaymentIntent client_secret is missing.");
      }

      return {
        clientSecret: paymentIntent.client_secret,
      };
    },
);

async function updateOrderByPaymentIntent(paymentIntentId, payload) {
  const snapshot = await db.collection("orders")
      .where("paymentIntentId", "==", paymentIntentId)
      .limit(1)
      .get();

  if (snapshot.empty) {
    logger.warn("Order not found for paymentIntentId", {paymentIntentId});
    return;
  }

  const ref = snapshot.docs[0].ref;
  await ref.set(payload, {merge: true});
}

async function handleAccountUpdated(account) {
  const stripeAccountId = account.id;
  const onboarded = Boolean(account.charges_enabled && account.payouts_enabled);

  const snapshot = await db.collection("users")
      .where("stripeAccountId", "==", stripeAccountId)
      .limit(1)
      .get();

  if (snapshot.empty) {
    logger.info("No user found for stripeAccountId", {stripeAccountId});
    return;
  }

  await snapshot.docs[0].ref.set({
    stripeOnboarded: onboarded,
  }, {merge: true});
}

exports.stripeWebhook = onRequest(
    {
      region: REGION,
      secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET],
      cors: false,
    },
    async (req, res) => {
      if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
      }

      const signature = req.headers["stripe-signature"];
      if (!signature) {
        res.status(400).send("Missing stripe-signature header");
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
        logger.error("Stripe webhook signature verification failed", error);
        res.status(400).send(`Webhook Error: ${error.message}`);
        return;
      }

      try {
        switch (event.type) {
          case "payment_intent.succeeded": {
            const paymentIntent = event.data.object;
            await updateOrderByPaymentIntent(paymentIntent.id, {
              paymentStatus: "paid",
              status: "confirmed",
            });
            break;
          }

          case "payment_intent.payment_failed": {
            const paymentIntent = event.data.object;
            await updateOrderByPaymentIntent(paymentIntent.id, {
              paymentStatus: "failed",
            });
            break;
          }

          case "account.updated": {
            const account = event.data.object;
            await handleAccountUpdated(account);
            break;
          }

          default:
            logger.info("Unhandled Stripe event", {type: event.type});
        }

        res.status(200).json({received: true});
      } catch (error) {
        logger.error("Stripe webhook handler failed", error);
        res.status(500).send("Webhook handler failed");
      }
    },
);
