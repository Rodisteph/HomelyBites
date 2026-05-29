#!/bin/bash
# ============================================================
# 🍽️  HomelyBites — Script de reconstruction MVVM propre
# ============================================================
# Usage : bash setup_homelybites.sh
#
# Ce script :
#   1. Installe XcodeGen si nécessaire (via Homebrew)
#   2. Copie HomelyBites-Clean/ vers ~/Desktop/HomelyBites-Clean/
#   3. Génère HomelyBites.xcodeproj via XcodeGen
#   4. Ouvre le projet dans Xcode
# ============================================================

set -e

# Chemin du dossier contenant ce script (= HomelyBites-Clean/)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEST=~/Desktop/HomelyBites-Clean

echo ""
echo "🍽️  HomelyBites — Reconstruction MVVM"
echo "======================================="
echo ""

# ─── Étape 1 : Homebrew ─────────────────────────────────────
echo "📦 [1/4] Vérification de Homebrew..."
if ! command -v brew &>/dev/null; then
    echo "   → Installation de Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    [[ $(uname -m) == "arm64" ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
fi
echo "   ✅ Homebrew OK"

# ─── Étape 2 : XcodeGen ─────────────────────────────────────
echo ""
echo "⚙️  [2/4] Vérification de XcodeGen..."
if ! command -v xcodegen &>/dev/null; then
    echo "   → Installation de XcodeGen..."
    brew install xcodegen
fi
echo "   ✅ XcodeGen OK ($(xcodegen --version))"

# ─── Étape 3 : Copier les sources ───────────────────────────
echo ""
echo "📁 [3/4] Copie des sources vers ~/Desktop/HomelyBites-Clean/..."

if [ -d "$DEST" ]; then
    echo "   → Suppression de l'ancien dossier..."
    rm -rf "$DEST"
fi

cp -r "$SCRIPT_DIR" "$DEST"
echo "   ✅ Sources copiées"

# ─── Étape 4 : Générer le projet Xcode ──────────────────────
echo ""
echo "🔨 [4/4] Génération du projet Xcode..."
cd "$DEST"
xcodegen generate

echo ""
echo "======================================="
echo "✅  HomelyBites.xcodeproj généré !"
echo "======================================="
echo ""
echo "📋 Structure MVVM créée :"
echo "   Core/"
echo "   ├── Models/     AppUser · Meal · Order · OrderStatus · PaymentStatus · UserRole"
echo "   ├── Services/   AuthService · FirestoreService · CloudFunctionsService"
echo "   └── Utils/      AppError · AppConfig · CurrencyFormatter · ViewModifiers · StripeInitializer"
echo "   Features/"
echo "   ├── Auth/       AuthView + AuthViewModel"
echo "   ├── Checkout/   CheckoutView + CheckoutViewModel"
echo "   ├── Host/       HostDashboardView + HostDashboardViewModel"
echo "   ├── Meals/      MealListView/VM · MealDetailView/VM · CreateMealView/VM"
echo "   ├── Orders/     OrdersView + OrdersViewModel"
echo "   ├── Root/       RootView + SessionViewModel"
echo "   └── Settings/   SettingsView"
echo "   Shared/"
echo "   └── SafariView"
echo ""
echo "🔑 Avant de compiler dans Xcode :"
echo "   1. Project → Signing & Capabilities → sélectionne ton Team"
echo "   2. project.yml ligne 'STRIPE_PUBLISHABLE_KEY' → remplace par ta vraie clé pk_test_..."
echo "   3. Ajoute GoogleService-Info.plist dans le projet (Firebase config)"
echo ""
echo "🚀 Ouverture dans Xcode..."
open "$DEST/HomelyBites.xcodeproj"
