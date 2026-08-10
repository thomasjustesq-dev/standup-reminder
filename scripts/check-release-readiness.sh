#!/usr/bin/env bash
# Local readiness gate for first notarized release.
# Does not print secret values. Exit 0 = ready enough to attempt tag/release.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0
warn() { echo "WARN: $*" >&2; }
die() { echo "FAIL: $*" >&2; fail=1; }
ok() { echo "OK: $*"; }

echo "=== Stand Up Reminder release readiness ==="

bash scripts/check-core-purity.sh || die "core purity"
bash scripts/check-version-agree.sh || die "version agree"

if swift test >/dev/null 2>&1; then
  ok "swift test"
else
  die "swift test failed"
fi

MARKETING=$(grep 'static let marketing' Sources/StandUpReminderCore/AppIdentity.swift | sed 's/.*"\(.*\)".*/\1/')
BUILD=$(grep 'static let build' Sources/StandUpReminderCore/AppIdentity.swift | sed 's/.*"\(.*\)".*/\1/')
ok "version $MARKETING ($BUILD)"

# Secrets — present vs missing only
need_env=(
  APPLE_ID
  APPLE_TEAM_ID
  APPLE_APP_PASSWORD
)
need_repo_secrets_doc=(
  APPLE_CERTIFICATES_P12
  APPLE_CERTIFICATES_PASSWORD
  APP_STORE_CONNECT_KEY_ID
  APP_STORE_CONNECT_ISSUER_ID
  APP_STORE_CONNECT_PRIVATE_KEY
)

for v in "${need_env[@]}"; do
  if [[ -n "${!v:-}" ]]; then ok "env $v set"
  else warn "env $v not set (needed for scripts/notarize.sh manual path)"
  fi
done

echo "GitHub Actions release secrets (configure in repo settings if using tag-triggered release.yml):"
for v in "${need_repo_secrets_doc[@]}"; do
  echo "  - $v"
done
echo "  - SPARKLE_ED_PRIVATE_KEY (optional)"

echo
echo "Portal checklist (manual — cannot automate):"
echo "  [ ] App ID $MARKETING capabilities: App Groups group.com.thomasjust.standupreminder"
echo "  [ ] iCloud container iCloud.com.thomasjust.standupreminder on Mac + iOS App IDs"
echo "  [ ] Developer ID Application cert exported as .p12 for CI (or local signing)"
echo "  [ ] After first install: Push to iCloud once to seed new container"
echo
echo "Ship steps:"
echo "  1. Confirm portal boxes above"
echo "  2. git tag v$MARKETING && git push origin v$MARKETING   # if Actions secrets set"
echo "     OR: ./scripts/build-app.sh && ./scripts/notarize.sh"
echo "  3. Fill Casks/standup-reminder.rb sha256 from release zip"
echo "  4. brew install --cask ./Casks/standup-reminder.rb  # smoke"

if [[ "$fail" -ne 0 ]]; then
  echo "=== NOT READY ($fail check(s) failed) ===" >&2
  exit 1
fi
echo "=== code ready; portal + secrets are still on you ==="
exit 0
