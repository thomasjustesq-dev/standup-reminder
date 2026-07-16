#!/usr/bin/env bash
# Install Stand Up Reminder as a per-user LaunchAgent on macOS.

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This installer is for macOS only (detected: $(uname -s))." >&2
  echo "Copy this folder to your Mac, then run ./install.sh there." >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/Library/Application Support/StandUpReminder"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
LABEL="com.user.standupreminder"
PLIST_PATH="${LAUNCH_AGENTS_DIR}/${LABEL}.plist"
SCRIPT_PATH="${INSTALL_DIR}/bin/standup-reminder.sh"

# shellcheck disable=SC1091
source "${ROOT_DIR}/config.env"

START_HOUR="${START_HOUR:-9}"
END_HOUR="${END_HOUR:-17}"
INTERVAL_MINUTES="${INTERVAL_MINUTES:-30}"
WEEKDAYS_ONLY="${WEEKDAYS_ONLY:-1}"

if (( 60 % INTERVAL_MINUTES != 0 )); then
  echo "INTERVAL_MINUTES must divide 60 evenly (got ${INTERVAL_MINUTES})." >&2
  exit 1
fi

echo "Installing Stand Up Reminder → ${INSTALL_DIR}"

mkdir -p "${INSTALL_DIR}/bin" "${LAUNCH_AGENTS_DIR}" "${HOME}/Library/Logs"

cp "${ROOT_DIR}/bin/standup-reminder.sh" "${INSTALL_DIR}/bin/standup-reminder.sh"
cp "${ROOT_DIR}/config.env" "${INSTALL_DIR}/config.env"
chmod +x "${INSTALL_DIR}/bin/standup-reminder.sh"

generate_plist() {
  local minutes=()
  local m=0
  while (( m < 60 )); do
    minutes+=("$m")
    m=$((m + INTERVAL_MINUTES))
  done

  local weekdays=()
  if [[ "$WEEKDAYS_ONLY" == "1" ]]; then
    # launchd: 0 and 7 = Sunday; 1 = Monday … 6 = Saturday
    weekdays=(1 2 3 4 5)
  else
    weekdays=(0 1 2 3 4 5 6)
  fi

  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${SCRIPT_PATH}</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>STANDUP_REMINDER_CONFIG</key>
    <string>${INSTALL_DIR}/config.env</string>
  </dict>
  <key>StandardOutPath</key>
  <string>${HOME}/Library/Logs/standup-reminder.launchd.out.log</string>
  <key>StandardErrorPath</key>
  <string>${HOME}/Library/Logs/standup-reminder.launchd.err.log</string>
  <key>StartCalendarInterval</key>
  <array>
EOF

  local hour weekday minute
  for weekday in "${weekdays[@]}"; do
    for (( hour = START_HOUR; hour < END_HOUR; hour++ )); do
      for minute in "${minutes[@]}"; do
        cat <<EOF
    <dict>
      <key>Weekday</key>
      <integer>${weekday}</integer>
      <key>Hour</key>
      <integer>${hour}</integer>
      <key>Minute</key>
      <integer>${minute}</integer>
    </dict>
EOF
      done
    done
  done

  cat <<'EOF'
  </array>
</dict>
</plist>
EOF
}

# Unload existing agent if present
if launchctl print "gui/$(id -u)/${LABEL}" >/dev/null 2>&1; then
  launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
fi

generate_plist >"${PLIST_PATH}"

launchctl bootstrap "gui/$(id -u)" "${PLIST_PATH}"
launchctl enable "gui/$(id -u)/${LABEL}"

echo
echo "Installed and started."
echo "  Schedule : every ${INTERVAL_MINUTES} min, ${START_HOUR}:00–$((END_HOUR - 1)):$((60 - INTERVAL_MINUTES))$([[ "$WEEKDAYS_ONLY" == "1" ]] && echo ", weekdays only")"
echo "  Agent    : ${PLIST_PATH}"
echo "  Config   : ${INSTALL_DIR}/config.env"
echo "  Logs     : ~/Library/Logs/standup-reminder.log"
echo
echo "Test notifications now:"
echo "  \"${SCRIPT_PATH}\" --test"
echo "  \"${SCRIPT_PATH}\" --test-lunch"
echo
echo "Allow alerts if macOS prompts you (System Settings → Notifications → Script Editor / osascript)."
