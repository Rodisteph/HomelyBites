#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PBXPROJ="$ROOT_DIR/HomelyBites.xcodeproj/project.pbxproj"
APP_SWIFT="$ROOT_DIR/HomelyBites/HomelyBitesApp.swift"
PLIST="$ROOT_DIR/GoogleService-Info.plist"

if [[ ! -f "$PBXPROJ" ]]; then
  echo "ERROR: missing $PBXPROJ"
  exit 1
fi

if [[ ! -f "$PLIST" ]]; then
  echo "ERROR: missing $PLIST"
  exit 1
fi

PROJECT_BUNDLE_ID="$(rg -n "PRODUCT_BUNDLE_IDENTIFIER = " "$PBXPROJ" | head -n1 | sed -E 's/.*PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);/\1/')"
PLIST_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "$PLIST")"

echo "PROJECT_BUNDLE_ID=$PROJECT_BUNDLE_ID"
echo "PLIST_BUNDLE_ID=$PLIST_BUNDLE_ID"

if [[ "$PROJECT_BUNDLE_ID" != "$PLIST_BUNDLE_ID" ]]; then
  echo "ERROR: bundle id mismatch between Xcode project and GoogleService-Info.plist"
  exit 1
fi

if ! rg -n "FirebaseApp\\.configure\\(" "$APP_SWIFT" >/dev/null; then
  echo "ERROR: FirebaseApp.configure() not found in $APP_SWIFT"
  exit 1
fi

echo "FirebaseApp.configure() found in $APP_SWIFT"

APP_BUNDLE="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*Build/Products/Debug-iphonesimulator/HomelyBites.app' -type d | rg -v 'Index\.noindex' | head -n1 || true)"
if [[ -z "${APP_BUNDLE:-}" ]]; then
  echo "WARN: built app bundle not found in DerivedData (run xcodebuild first)"
  exit 0
fi

EMBEDDED_PLIST="$APP_BUNDLE/GoogleService-Info.plist"
if [[ ! -f "$EMBEDDED_PLIST" ]]; then
  echo "ERROR: $EMBEDDED_PLIST is missing from app bundle"
  exit 1
fi

EMBEDDED_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "$EMBEDDED_PLIST")"
echo "APP_BUNDLE=$APP_BUNDLE"
echo "EMBEDDED_PLIST_BUNDLE_ID=$EMBEDDED_BUNDLE_ID"

if [[ "$EMBEDDED_BUNDLE_ID" != "$PROJECT_BUNDLE_ID" ]]; then
  echo "ERROR: embedded GoogleService-Info.plist has wrong BUNDLE_ID"
  exit 1
fi

echo "OK: Firebase iOS config is coherent (project/plist/embedded plist)."
