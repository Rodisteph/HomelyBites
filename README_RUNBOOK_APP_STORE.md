# Runbook App Store - HomelyBites

## 1. Prerequisites
- Xcode 15+ (iOS 17+ SDK)
- Node.js 20 (for Cloud Functions)
- Firebase CLI: `npm i -g firebase-tools`
- Apple Developer Program access
- Stripe account (test + live keys)

## 2. Firebase Setup
1. Connect project:
```bash
firebase login
firebase use --add
```
2. Verify iOS app config:
- `GoogleService-Info.plist` is present in target
- Bundle ID matches Firebase app
3. Deploy Firestore rules:
```bash
firebase deploy --only firestore:rules
```

## 3. Cloud Functions Setup
1. Install dependencies:
```bash
cd functions
npm install
cd ..
```
2. Configure Stripe secrets:
```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
```
3. Deploy:
```bash
firebase deploy --only functions
```

## 4. Stripe Webhook Setup
1. Get webhook function URL:
```bash
firebase functions:list
```
2. In Stripe Dashboard > Developers > Webhooks:
- Add endpoint = `stripeWebhook` URL
- Events:
  - `payment_intent.succeeded`
  - `payment_intent.payment_failed`
  - `charge.succeeded`
  - `account.updated`
3. Save `whsec_...` in Firebase secret (`STRIPE_WEBHOOK_SECRET`) and redeploy functions.

## 5. Payment Flow Contract (Production)
1. App creates order (`paymentStatus=requires_payment`, `status=pending`).
2. App requests client secret via `createPaymentIntentWithFee(orderId)`.
3. PaymentSheet handles payment.
4. Webhook is source of truth:
- success -> `paymentStatus=paid`, `status=confirmed`
- failure -> `paymentStatus=failed`
5. App UI listens `orders/{orderId}` and shows "Confirmation en cours..." until webhook update.

## 6. iOS Build & Archive
1. Resolve packages and build:
```bash
xcodebuild -resolvePackageDependencies -scheme HomelyBites
xcodebuild -scheme HomelyBites -destination 'generic/platform=iOS' build
```
2. In Xcode:
- Product > Archive
- Validate archive
- Upload to App Store Connect

## 7. TestFlight Checklist
- Host onboarding Stripe works (`stripeOnboarded` updates)
- Client payment completes via PaymentSheet
- Order status transitions by webhook only
- Delete account removes Firebase Auth user + Firestore data
- Privacy Policy / Terms links open from Settings
- Password reset email is sent from login screen

## 8. App Store Submission Checklist
- App Privacy section filled in App Store Connect
- Terms of Use and Privacy Policy URLs published
- Support URL + Marketing URL set
- Screenshots for iPhone/iPad prepared
- Version/Build incremented
- Final regression pass on physical device
