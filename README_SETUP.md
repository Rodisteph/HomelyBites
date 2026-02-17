# HomelyBites - Setup & Deploy

## 1) Prerequisites
- Xcode 15+ (iOS 17 SDK)
- Firebase CLI (`npm i -g firebase-tools`)
- Stripe account + Stripe CLI (optional but recommended)

## 2) iOS configuration
1. Open project:
   - `open HomelyBites.xcodeproj`
2. In Xcode, add Swift Packages:
   - Firebase iOS SDK: `https://github.com/firebase/firebase-ios-sdk`
   - Products: `FirebaseAuth`, `FirebaseFirestore`, `FirebaseFirestoreSwift`, `FirebaseFunctions`, `FirebaseCore`
   - Stripe iOS SDK: `https://github.com/stripe/stripe-ios`
   - Products: `StripePaymentSheet`, `StripeCore`
3. Add `GoogleService-Info.plist` into `HomelyBites/` target.
4. Set Stripe publishable key in `HomelyBites/Info.plist`:
   - `STRIPE_PUBLISHABLE_KEY = pk_test_xxx` (safe in app)
5. Bundle identifier placeholder is already:
   - `com.tonbundle.homelybites`

## 3) Firebase project
From repo root:

```bash
firebase login
firebase use --add
```

Deploy Firestore rules:

```bash
firebase deploy --only firestore:rules
```

## 4) Cloud Functions install/deploy

```bash
cd functions
npm install
cd ..
```

Set secrets:

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
# set after webhook endpoint creation (step 5)
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
```

Deploy functions:

```bash
firebase deploy --only functions
```

Functions deployed:
- `createConnectAccount`
- `createOnboardingLink`
- `createPaymentIntentWithFee`
- `stripeWebhook`

## 5) Stripe webhook setup
1. Get function URL:
   - `firebase functions:list`
   - Copy HTTPS URL for `stripeWebhook`
2. Stripe Dashboard -> Developers -> Webhooks -> Add endpoint.
3. Events:
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
   - `account.updated`
4. Copy signing secret (`whsec_...`) and set it:

```bash
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
firebase deploy --only functions:stripeWebhook
```

## 6) Deep links
App URL scheme is configured in `Info.plist`:
- `homelybites://onboarding/return`
- `homelybites://onboarding/refresh`

These URLs are used by `createOnboardingLink` in Cloud Functions.

## 7) Test checklist
1. Create host account in app.
2. Host taps `Activer paiements` and completes Stripe onboarding.
3. Host creates meal (or `Seed 2 meals de test`).
4. Create client account.
5. Client opens meal detail -> `Reserver & payer`.
6. PaymentSheet completes payment.
7. Check `orders/{orderId}` updated by webhook:
   - `paymentStatus = paid`
   - `status = confirmed`
