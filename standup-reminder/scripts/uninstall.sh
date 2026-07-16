#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Uninstall on macOS." >&2
  exit 1
fi

APP="${HOME}/Applications/StandUpReminder.app"
CLI="${HOME}/.local/bin/standup-reminder"
SUPPORT="${HOME}/Library/Application Support/StandUpReminder"
LEGACY_LABEL="com.user.standupreminder"

osascript -e 'tell application "Stand Up Reminder" to quit' 2>/dev/null || true
killall StandUpReminder 2>/dev/null || true

if launchctl print "gui/$(id -u)/${LEGACY_LABEL}" >/dev/null 2>&1; then
  launchctl bootout "gui/$(id -u)/${LEGACY_LABEL}" 2>/dev/null || true
fi
rm -f "${HOME}/Library/LaunchAgents/${LEGACY_LABEL}.plist"

rm -rf "${APP}"
rm -f "${CLI}"

echo "Removed app and CLI."
echo "Config/stats left at ${SUPPORT} (delete manually if desired)."
echo "Logs: ~/Library/Logs/standup-reminder.log"
