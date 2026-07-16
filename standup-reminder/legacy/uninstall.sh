#!/usr/bin/env bash
# Remove Stand Up Reminder LaunchAgent and installed files.

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This uninstaller is for macOS only." >&2
  exit 1
fi

INSTALL_DIR="${HOME}/Library/Application Support/StandUpReminder"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
LABEL="com.user.standupreminder"
PLIST_PATH="${LAUNCH_AGENTS_DIR}/${LABEL}.plist"

echo "Uninstalling Stand Up Reminder…"

if launchctl print "gui/$(id -u)/${LABEL}" >/dev/null 2>&1; then
  launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
fi

rm -f "${PLIST_PATH}"
rm -rf "${INSTALL_DIR}"

echo "Removed LaunchAgent and ${INSTALL_DIR}"
echo "Logs left in ~/Library/Logs/standup-reminder*.log (delete manually if you want)."
