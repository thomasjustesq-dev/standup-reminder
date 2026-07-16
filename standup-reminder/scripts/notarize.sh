#!/usr/bin/env bash
# Notarize a Release .app with your Apple Developer account.
#
# Prerequisites:
#   - Apple Developer Program membership
#   - App-specific password: https://appleid.apple.com
#   - Developer ID Application certificate in Keychain
#
# Usage:
#   export APPLE_ID="you@example.com"
#   export APPLE_TEAM_ID="ABCDE12345"
#   export APPLE_APP_PASSWORD="aaaa-bbbb-cccc-dddd"
#   ./scripts/build-app.sh
#   ./scripts/notarize.sh
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Notarization requires macOS." >&2
  exit 1
fi

: "${APPLE_ID:?Set APPLE_ID}"
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID}"
: "${APPLE_APP_PASSWORD:?Set APPLE_APP_PASSWORD}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${ROOT_DIR}/dist/StandUpReminder.app"
ZIP="${ROOT_DIR}/dist/StandUpReminder.zip"
IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application}"

if [[ ! -d "$APP" ]]; then
  echo "Missing $APP — run ./scripts/build-app.sh first." >&2
  exit 1
fi

echo "→ codesign (Developer ID)"
codesign --force --deep --options runtime --sign "$IDENTITY" "$APP"
codesign --verify --verbose "$APP"

echo "→ zip for notarytool"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "→ submit notarization"
xcrun notarytool submit "$ZIP" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_PASSWORD" \
  --wait

echo "→ staple"
xcrun stapler staple "$APP"
spctl --assess --type execute -vv "$APP" || true

echo "Notarized: $APP"
echo "Distribute the .app or zip. For Sparkle/GitHub updates, attach this build to a release."
