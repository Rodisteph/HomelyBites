#!/usr/bin/env bash
set -u -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="${ROOT_DIR}/smoke_test_$(date +%Y%m%d_%H%M%S).log"

SKIP_BUILD=0
SKIP_LINT=0

pass_count=0
fail_count=0
warn_count=0

print_help() {
  cat <<'EOF'
Usage: ./scripts/smoke_test_app_store.sh [options]

Options:
  --skip-build    Skip xcodebuild checks
  --skip-lint     Skip functions lint checks
  --help          Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --skip-lint)
      SKIP_LINT=1
      shift
      ;;
    --help|-h)
      print_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      print_help
      exit 2
      ;;
  esac
done

section() {
  echo
  echo "=================================================="
  echo "$1"
  echo "=================================================="
}

pass() {
  pass_count=$((pass_count + 1))
  echo "[PASS] $1"
}

fail() {
  fail_count=$((fail_count + 1))
  echo "[FAIL] $1"
}

warn() {
  warn_count=$((warn_count + 1))
  echo "[WARN] $1"
}

run_step() {
  local title="$1"
  shift

  echo
  echo "-> $title"
  if "$@" >>"$LOG_FILE" 2>&1; then
    pass "$title"
  else
    fail "$title"
    echo "   last logs:"
    tail -n 20 "$LOG_FILE" || true
  fi
}

manual_check() {
  local title="$1"
  local answer

  while true; do
    printf "[MANUAL] %s ? [y/n/s] " "$title"
    read -r answer
    case "$answer" in
      y|Y)
        pass "$title"
        return
        ;;
      n|N)
        fail "$title"
        return
        ;;
      s|S)
        warn "$title (skipped)"
        return
        ;;
      *)
        echo "Please answer y (yes), n (no), or s (skip)."
        ;;
    esac
  done
}

section "HomelyBites Smoke Test"
echo "Repo: $ROOT_DIR"
echo "Log file: $LOG_FILE"
echo "Started at: $(date)"
echo
echo "Writing command output to log file..."
echo "Smoke test started: $(date)" >"$LOG_FILE"

section "Automated Checks"

if [[ -x "$ROOT_DIR/scripts/verify_firebase_ios_config.sh" ]]; then
  run_step "Verify Firebase iOS config" "$ROOT_DIR/scripts/verify_firebase_ios_config.sh"
else
  warn "scripts/verify_firebase_ios_config.sh missing or not executable"
fi

if command -v node >/dev/null 2>&1; then
  run_step "Functions syntax check (node --check)" node --check "$ROOT_DIR/functions/index.js"
else
  warn "node not found (skip functions syntax check)"
fi

if [[ $SKIP_LINT -eq 0 ]]; then
  if command -v npm >/dev/null 2>&1; then
    run_step "Functions lint (npm --prefix functions run lint)" npm --prefix "$ROOT_DIR/functions" run lint
  else
    warn "npm not found (skip lint)"
  fi
else
  warn "Functions lint skipped by flag"
fi

if [[ $SKIP_BUILD -eq 0 ]]; then
  if command -v xcodebuild >/dev/null 2>&1; then
    run_step "Resolve package dependencies" xcodebuild -resolvePackageDependencies -scheme HomelyBites -project "$ROOT_DIR/HomelyBites.xcodeproj"
    run_step "Build iOS app (generic platform)" xcodebuild -scheme HomelyBites -project "$ROOT_DIR/HomelyBites.xcodeproj" -destination "generic/platform=iOS" build CODE_SIGNING_ALLOWED=NO
  else
    warn "xcodebuild not found (skip iOS build)"
  fi
else
  warn "iOS build checks skipped by flag"
fi

section "Manual Validation"
echo "Run these in the app while this script stays open."
manual_check "Login host works"
manual_check "Activate payments works and no internal function error"
manual_check "users/{uid}.stripeAccountId appears in Firestore"
manual_check "Host onboarding status is visible in dashboard"
manual_check "Client can open meal and start checkout"
manual_check "After PaymentSheet success, UI shows confirmation pending state"
manual_check "Webhook updates order to paymentStatus=paid and status=confirmed"
manual_check "Delete meal works for its owner host"
manual_check "Settings: password reset email sent"
manual_check "Settings: delete account action completes"

section "Summary"
echo "PASS=$pass_count"
echo "FAIL=$fail_count"
echo "WARN=$warn_count"
echo "Log: $LOG_FILE"
echo "Finished at: $(date)"

if [[ $fail_count -gt 0 ]]; then
  echo
  echo "Smoke test failed. Check log file for details."
  exit 1
fi

echo
echo "Smoke test passed."
exit 0
