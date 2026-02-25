# Debugging Empty Data Screens in HomelyBites

## Problem
ALL data screens are empty (Repas, Map, Host Dashboard, etc.)
Only titles/static UI render, no dynamic content appears anywhere.

## Comprehensive Debug Logging Added

I've added extensive debug logging throughout the app to help diagnose the root cause. All logs are wrapped in `#if DEBUG` so they only appear in debug builds.

---

## 🔍 How to Debug

### Step 1: Run the App
1. Open HomelyBites.xcworkspace in Xcode
2. Select a simulator (iPhone 16 or similar)
3. Press **Cmd+R** to run in Debug mode
4. Open Debug Console: **Cmd+Shift+Y**

### Step 2: Check Debug Console Logs

#### Look for these log patterns (in order):

##### 1️⃣ App Initialization
```
🚀 [HomelyBitesApp] App initializing...
🔄 [HomelyBitesApp] Configuring Firebase...
✅ [HomelyBitesApp] Firebase configured successfully
🔄 [HomelyBitesApp] Creating AppContainer and SessionViewModel...
✅ [HomelyBitesApp] App initialization complete
```

**✅ PASS:** Firebase and app container initialized successfully
**❌ FAIL:** If you see errors here, Firebase configuration is broken

##### 2️⃣ Authentication State
```
🔄 [SessionViewModel] Starting auth state listener...
✅ [SessionViewModel] Auth state changed - User authenticated: <uid>
🔄 [SessionViewModel] Fetching user profile for uid: <uid>
✅ [SessionViewModel] User profile loaded: <name>
✅ [SessionViewModel] User role: client (or host)
✅ [SessionViewModel] Bootstrap complete. isAuthenticated: true
```

**✅ PASS:** User authenticated and profile loaded
**❌ FAIL:** If you see `⚠️ No user (signed out)`, authentication failed
**❌ FAIL:** If user fetch fails, Firestore permissions or user document missing

##### 3️⃣ Data Fetching (Meals Screen)
```
🔄 [MealListViewModel] Starting to fetch meals...
🔄 [MealListViewModel] Auth user: <uid>
🔄 [FirestoreService.fetchMeals] Starting Firestore query for meals collection...
✅ [FirestoreService.fetchMeals] Firestore query completed
✅ [FirestoreService.fetchMeals] Document count: 5
🔄 [FirestoreService.fetchMeals] Decoding meal document: <doc-id>
✅ [FirestoreService.fetchMeals] Returning 5 sorted meals
✅ [MealListViewModel] Successfully fetched 5 meals
✅ [MealListViewModel] First meal: Poulet rôti aux herbes
```

**✅ PASS:** Meals fetched and displayed
**❌ FAIL:** If document count is 0, Firestore `meals` collection is empty
**❌ FAIL:** If decoding fails, meal document structure doesn't match `Meal` model

##### 4️⃣ Map Screen
```
🔄 [MapViewModel] Starting to load map pins...
✅ [MapViewModel] Fetched 5 meal documents from Firestore
⚠️ [MapViewModel] Skipping document <id> - no valid coordinates
✅ [MapViewModel] Successfully parsed 3 pins with valid coordinates
```

**✅ PASS:** Map pins loaded
**❌ FAIL:** If all documents skipped, meals missing location data (GeoPoint)

##### 5️⃣ Host Dashboard
```
🔄 [HostDashboardViewModel] Starting to listen for orders for host: <uid>
🔄 [HostDashboardViewModel] Starting refresh for host: <uid>
✅ [HostDashboardViewModel] Received 2 orders via listener
✅ [HostDashboardViewModel] Refresh complete: 2 orders, 3 meals
```

**✅ PASS:** Host data loaded
**❌ FAIL:** If orders/meals count is 0, Firestore collections empty for this host

---

## 🚨 Common Issues & Fixes

### Issue #1: No Authenticated User
**Symptom:** `⚠️ [SessionViewModel] No user (signed out)`

**Cause:** User not signed in or authentication state listener not triggered

**Fix:**
1. Check if you can see the login screen
2. Try signing in with test credentials
3. Check Xcode console for Firebase auth errors
4. Verify GoogleService-Info.plist is present and valid

---

### Issue #2: Firestore Permission Denied
**Symptom:**
```
❌ [FirestoreService.fetchMeals] Firestore query failed
❌ [FirestoreService.fetchMeals] Error code: 7
❌ [FirestoreService.fetchMeals] Error description: Missing or insufficient permissions
```

**Cause:** Firestore security rules blocking reads

**Fix:**
1. Go to Firebase Console → Firestore Database → Rules
2. Temporarily set test rules (DEVELOPMENT ONLY):
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```
3. Publish rules and retest

---

### Issue #3: Empty Firestore Collections
**Symptom:** `✅ Document count: 0`

**Cause:** No data in Firestore database

**Fix:**
1. Go to Firebase Console → Firestore Database
2. Check if `meals`, `users`, `orders` collections exist
3. If empty, create test data:
   - For hosts: Use "Seed 2 meals de test" button in Host Dashboard
   - Manually add a meal document in Firebase Console

---

### Issue #4: Document Decoding Failure
**Symptom:**
```
❌ [FirestoreService.fetchMeals] Failed to decode meal
❌ Type 'Meal' expected field 'title' but it was missing
```

**Cause:** Firestore document structure doesn't match Swift `Meal` model

**Fix:**
1. Check Firebase Console → Firestore → meals collection
2. Verify each meal document has required fields:
   - `title` (String)
   - `description` (String)
   - `priceCents` (Number)
   - `hostId` (String)
   - `hostName` (String)
   - `availablePortions` (Number)
3. Delete any malformed documents

---

### Issue #5: Missing Location Data (Map Empty)
**Symptom:** `⚠️ Skipping document <id> - no valid coordinates`

**Cause:** Meal documents missing location GeoPoint

**Fix:**
1. In Host Dashboard, use "Backfill location (dev only)" button
2. OR manually add to each meal document in Firebase:
   - Field: `location`
   - Type: GeoPoint
   - Value: latitude: 52.3676, longitude: 4.9041 (Amsterdam)

---

## 📊 Verification Checklist

Use this checklist to systematically diagnose the issue:

- [ ] **Firebase configured** - See `✅ Firebase configured successfully`
- [ ] **Auth listener started** - See `🔄 Starting auth state listener`
- [ ] **User authenticated** - See `✅ User authenticated: <uid>`
- [ ] **User profile loaded** - See `✅ User profile loaded: <name>`
- [ ] **Bootstrap complete** - See `isAuthenticated: true`
- [ ] **Meals fetch started** - See `🔄 Starting to fetch meals`
- [ ] **Firestore query completed** - See document count > 0
- [ ] **Meals decoded successfully** - No decoding errors
- [ ] **Meals array populated** - See `✅ Successfully fetched X meals`
- [ ] **UI updates on main thread** - All ViewModels use `@MainActor`

---

## 🛠️ Advanced Debugging

### Enable More Verbose Logging

If the issue is still unclear, add breakpoints:

1. **MealListViewModel.swift** → Line ~20 (`meals = fetchedMeals`)
2. **SessionViewModel.swift** → Line ~70 (`self.appUser = ...`)
3. **FirestoreService.swift** → Line ~58 (`let meals = try...`)

Run app, when breakpoint hits, inspect:
- `fetchedMeals` or `meals` count
- `self.appUser` properties
- Use `po meals` in console to print data

---

## 📝 Report Findings

After running through the debug steps, report:

1. **Where does the log flow stop?** (App init? Auth? Firestore?)
2. **Any error messages?** (Copy full error with domain + code)
3. **Document counts?** (How many meals/orders in Firestore?)
4. **Authentication status?** (Is user signed in? What uid?)

This will help pinpoint the exact issue!

---

## ✅ Success Criteria

When everything works, you should see:

1. ✅ Firebase initialized
2. ✅ User authenticated with valid uid
3. ✅ User profile loaded with name + role
4. ✅ Meals fetched with count > 0
5. ✅ UI displays meals, orders, map pins

---

**Last Updated:** 2025-02-25
**Debug Logging Version:** 1.0
