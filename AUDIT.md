# HomelyBites — Audit Complet (App Store Readiness)

Date: 2026-02-25
Status: **En préparation pour l'App Store**

---

## 📊 Vue d'ensemble

- **Fichiers Swift**: 44
- **Dépendances externes**: Stripe (À SUPPRIMER), Firebase, PassKit
- **Target iOS**: iOS 17.0+
- **Architecture**: SwiftUI + Combine + Firebase

---

## 🔴 Problèmes Bloquants (CRITIQUE)

### 1. Stripe SDK (À SUPPRIMER)
**Impact**: Apple exige Apple Pay pour les paiements d'apps Food & Drink

Fichiers affectés:
```
HomelyBites/Core/Services/StripeInitializer.swift
HomelyBites/Core/Services/StripeService.swift
HomelyBites/HomelyBitesApp.swift
HomelyBites/Features/Checkout/CheckoutView.swift
HomelyBites/Features/Checkout/CheckoutViewModel.swift
```

**Action**: Phase 4 va supprimer Stripe et garder uniquement Apple Pay

### 2. Clés Privacy Manquantes dans Info.plist
**Impact**: App Review rejection automatique

Clés manquantes:
- ❌ `NSCameraUsageDescription` - Pour upload de photos de repas
- ❌ `NSPhotoLibraryUsageDescription` - Pour sélection de photos

**Action**: Phase 5 va ajouter ces descriptions

### 3. Version et Build Number
**Impact**: Requis pour soumettre à App Store Connect

Actuellement:
- `CFBundleShortVersionString`: $(MARKETING_VERSION) ← doit être 1.0.0
- `CFBundleVersion`: $(CURRENT_PROJECT_VERSION) ← doit être 1

**Action**: Phase 5 va définir les versions explicites

---

## 🟡 Problèmes Importants (HAUTE PRIORITÉ)

### 1. Icône de l'app manquante/incomplète
**Impact**: Requis pour l'App Store

**Action**: Phase 2 va générer toutes les tailles (20pt → 1024pt)

### 2. Color Assets non standardisés
**Impact**: Design incohérent, pas de support dark mode optimal

Actuellement: Couleurs définies via `Color(hex:)` dans AppTheme.swift
Problème: Pas de support natif dark mode

**Action**: Phase 3 va créer des Color Assets dans xcassets

### 3. Entitlements incomplets
**Impact**: Peut bloquer certaines fonctionnalités

Actuellement:
- ✅ Apple Pay merchant ID: `merchant.com.homelybites.app`
- ❌ APS Environment (pour push notifications)

**Action**: Phase 5 va ajouter APS environment

---

## 🟢 Problèmes Mineurs (AMÉLIORATION)

### 1. Force Unwraps (!)
**Impact**: Risque de crash en production

Occurrences trouvées: ~30 (la plupart dans guard statements, acceptable)

Exemples critiques:
- Aucun force unwrap dangereux détecté
- Tous les `!` sont dans des contextes sûrs (isEmpty checks, optional chaining)

**Recommandation**: Audit visuel manuel OK, aucune action requise

### 2. TODO/FIXME
**Impact**: Code possiblement incomplet

Résultat: ✅ Aucun TODO ou FIXME trouvé

### 3. Strings en français hardcodées
**Impact**: Pas de localisation

Exemples:
- "Votre position est utilisee..." dans Info.plist
- Messages d'erreur dans CloudFunctionsService.swift

**Recommandation**:
- Phase 1: Garder le français pour la V1
- V2: Ajouter Localizable.strings pour EN/FR

---

## 📋 Dépendances

### SPM Packages (Package.swift ou project.pbxproj)
```
✅ Firebase iOS SDK (~> 12.9.0)
   - FirebaseAuth
   - FirebaseFirestore
   - FirebaseFunctions
   - FirebaseStorage

🔴 Stripe iOS SDK (~> 25.6.2) ← À SUPPRIMER
   - StripePaymentSheet
   - StripeCore

✅ PassKit (système) ← Pour Apple Pay
```

**Action Phase 4**: Supprimer Stripe de Package.swift

---

## 🔐 Info.plist — État Actuel

| Clé | État | Valeur |
|-----|------|--------|
| CFBundleDisplayName | ✅ | HomelyBites |
| CFBundleShortVersionString | 🟡 | $(MARKETING_VERSION) → doit être 1.0.0 |
| CFBundleVersion | 🟡 | $(CURRENT_PROJECT_VERSION) → doit être 1 |
| NSLocationWhenInUseUsageDescription | ✅ | "Votre position est utilisee..." |
| NSCameraUsageDescription | ❌ | MANQUANT |
| NSPhotoLibraryUsageDescription | ❌ | MANQUANT |
| CFBundleURLTypes | ✅ | homelybites:// + Google OAuth |

---

## 🎯 Checklist Technique

### Code Quality
- [x] Pas de TODO/FIXME
- [x] Pas de force unwraps dangereux
- [ ] Stripe à supprimer (Phase 4)
- [x] Architecture propre (SwiftUI + MVVM)

### Assets
- [ ] Icône app (toutes tailles) → Phase 2
- [ ] Color Assets pour dark mode → Phase 3
- [x] Polices custom (Cormorant Garamond + DM Sans)

### Configuration
- [ ] Info.plist: privacy descriptions complètes → Phase 5
- [ ] Info.plist: versions explicites → Phase 5
- [ ] Entitlements: Apple Pay + APS → Phase 5
- [x] Deep links configurés (homelybites://)

### Build
- [x] Debug build réussit
- [ ] Release archive → Phase 6

---

## 🚀 Plan d'Action (Phases)

### Phase 2 — Icône (10 min)
Script Python génère toutes les tailles requises

### Phase 3 — Color Assets (15 min)
Crée les assets dans xcassets + met à jour AppTheme.swift

### Phase 4 — Supprimer Stripe (30 min)
⚠️ Phase critique
- Supprime imports Stripe dans 5 fichiers
- Réécrit CheckoutView/ViewModel pour Apple Pay only
- Supprime StripeInitializer.swift
- Supprime Stripe de Package.swift

### Phase 5 — Checklist App Store (20 min)
- Ajoute privacy descriptions
- Définit versions 1.0.0 / build 1
- Complète entitlements
- Génère APPSTORE_CHECKLIST.md

### Phase 6 — Build Release (10 min)
Compile en Release pour vérifier

### Phase 7 — Commit (5 min)
Push final sur GitHub

---

## ✅ Conformité App Store Guidelines

| Guideline | Status | Notes |
|-----------|--------|-------|
| 2.1 App Completeness | 🟡 | En cours |
| 2.3 Accurate Metadata | ⏳ | À remplir dans App Store Connect |
| 3.1.1 In-App Purchase | ✅ | Apple Pay (0% commission pour services physiques) |
| 4.0 Design | 🟡 | Icône à finaliser |
| 5.1.1 Data Collection | ⚠️ | Privacy Policy URL requise |
| 5.1.2 Data Use | ✅ | Location, Camera, Photos justifiés |

---

## 📝 Notes pour App Store Connect

### Informations à préparer
- [ ] Nom: HomelyBites
- [ ] Sous-titre: "Home-cooked meals, delivered with love"
- [ ] Description (4000 chars max)
- [ ] Mots-clés: home cooking, local food, homemade meals, food delivery
- [ ] Catégorie: Food & Drink
- [ ] URL de support: [À définir]
- [ ] Privacy Policy URL: [À créer]

### Screenshots requis
- [ ] iPhone 6.7" (iPhone 15 Pro Max) — minimum 3
- [ ] iPhone 6.5" (iPhone 14 Plus) — minimum 3
- [ ] iPad Pro 12.9" — si support iPad

### App Review
- [ ] Compte de test: email + password pour Apple reviewer
- [ ] Notes de review: expliquer Firebase Auth + Apple Pay

---

## 🎯 Score de Préparation

**56% prêt** (5/9 critères majeurs)

✅ Prêt:
- Code quality
- Architecture
- Polices custom
- Deep links
- Entitlements Apple Pay

🔧 En cours (Phases 2-7):
- Icône app
- Color Assets
- Suppression Stripe
- Privacy descriptions
- Build Release

---

**Prochaine étape**: Phase 2 — Génération de l'icône
