#!/usr/bin/env bash
# Build (if needed) and install Stand Up Reminder to ~/Applications, then launch it.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Install on a Mac (iMac / MacBook / Mac Mini / Mac Studio)." >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="StandUpReminder.app"
SRC_APP="${ROOT_DIR}/dist/${APP_NAME}"
DEST_DIR="${HOME}/Applications"
DEST_APP="${DEST_DIR}/${APP_NAME}"

# Remove legacy LaunchAgent if present from v1 shell installer
LEGACY_LABEL="com.user.standupreminder"
if launchctl print "gui/$(id -u)/${LEGACY_LABEL}" >/dev/null 2>&1; then
  echo "→ removing legacy LaunchAgent ${LEGACY_LABEL}"
  launchctl bootout "gui/$(id -u)/${LEGACY_LABEL}" 2>/dev/null || true
fi
rm -f "${HOME}/Library/LaunchAgents/${LEGACY_LABEL}.plist"
rm -rf "${HOME}/Library/Application Support/StandUpReminder/bin"

if [[ ! -d "${SRC_APP}" ]]; then
  echo "→ app not found; building…"
  "${ROOT_DIR}/scripts/build-app.sh"
fi

mkdir -p "${DEST_DIR}"
rm -rf "${DEST_APP}"
cp -R "${SRC_APP}" "${DEST_APP}"

# CLI symlink
mkdir -p "${HOME}/.local/bin"
ln -sf "${DEST_APP}/Contents/MacOS/StandUpReminder" "${HOME}/.local/bin/standup-reminder"

echo "→ launching ${DEST_APP}"
open "${DEST_APP}"

echo
echo "Installed to ${DEST_APP}"
echo "CLI (add ~/.local/bin to PATH if needed):"
echo "  standup-reminder status"
echo "  standup-reminder pause | resume | snooze | test | test-lunch"
echo
echo "If macOS blocks the app: right-click → Open, or allow in System Settings → Privacy & Security."
