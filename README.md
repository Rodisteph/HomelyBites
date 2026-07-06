# HomelyBites 🍲

An iOS marketplace connecting **home cooks with local buyers** — browse home-cooked meals nearby, order and pay in-app; hosts manage their kitchen from a dedicated dashboard.

Built end-to-end: SwiftUI app + Firebase backend + Stripe payments through secured Cloud Functions.

## Features

- **Two-sided marketplace** — buyer and host roles with dedicated flows (browse & order vs. create meals & track sales).
- **Payments** — Stripe checkout (incl. Apple Pay); PaymentIntents are created **server-side** in Cloud Functions, never in the app.
- **Auth & data** — Firebase Auth sessions, realtime Firestore sync with offline cache.
- **Host dashboard** — meal creation with pricing/location, order tracking.
- **Design system** — custom typography (DM Sans), reusable components.

## Architecture

```
HomelyBites-Clean/          ← current codebase (full MVVM rewrite, iOS 17 @Observable)
├── Core/
│   ├── Models/             AppUser · Meal · Order · UserRole (+ Firestore mappers)
│   ├── Services/           AuthService · FirestoreService · CloudFunctionsService · StripeInitializer
│   └── Utils/              AppError · AppConfig · CurrencyFormatter · Firestore+Async
├── Features/               Meals · Checkout · Host · Settings (View + ViewModel per feature)
└── Shared/                 Reusable UI

functions/                  Node.js Cloud Functions — Stripe PaymentIntents & webhooks
```

- **Feature-based MVVM**: each feature owns its View + ViewModel; models and services live in `Core`.
- **Money never touches the client**: the app calls a Cloud Function, the function talks to Stripe and verifies webhooks.
- **No secrets in the repo**: API keys live in server config and gitignored local plists.

## Stack

SwiftUI · MVVM (`@Observable`) · Firebase Auth · Firestore · Cloud Functions (Node.js) · Stripe & Apple Pay · GitHub Actions

---

**Rodrigo Bouabida** — ex-executive chef, now iOS developer. This app is where both careers meet.
📄 [Interactive CV](https://rodisteph.github.io/CV) · [Steady, my habit tracker](https://github.com/Rodisteph/steady)
