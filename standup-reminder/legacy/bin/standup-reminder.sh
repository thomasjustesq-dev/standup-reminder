#!/usr/bin/env bash
# Stand Up Reminder — shows a macOS notification during configured work hours.
# Designed for macOS (iMac, MacBook, Mac Mini, Mac Studio).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${STANDUP_REMINDER_CONFIG:-$SCRIPT_DIR/../config.env}"

# Defaults (overridden by config.env when present)
START_HOUR=9
END_HOUR=17
WEEKDAYS_ONLY=1
SKIP_WHEN_LOCKED=1
NOTIFICATION_TITLE="Stand Up Reminder"
NOTIFICATION_BODY="Time to stand up and move around for a minute or two."
SOUND_NAME="Glass"
LUNCH_ENABLED=1
LUNCH_HOUR=12
LUNCH_MINUTE=0
LUNCH_TITLE="Lunch Reminder"
LUNCH_BODY="It's noon — time to take a break and eat lunch."
LUNCH_SOUND_NAME="Glass"
LOG_FILE="${HOME}/Library/Logs/standup-reminder.log"

# Set by CLI: standup | lunch | auto
REMINDER_MODE="auto"
FORCE=0

load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
  fi
}

log() {
  mkdir -p "$(dirname "$LOG_FILE")"
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE"
}

is_weekday() {
  local dow
  dow="$(date '+%u')" # 1=Mon … 7=Sun
  [[ "$dow" -ge 1 && "$dow" -le 5 ]]
}

within_work_hours() {
  local hour
  hour="$(date '+%H')"
  hour=$((10#$hour))
  # Inclusive of START_HOUR, exclusive of END_HOUR (e.g. 9–17 → until 4:59pm)
  [[ "$hour" -ge "$START_HOUR" && "$hour" -lt "$END_HOUR" ]]
}

# Returns 0 when the Mac login session reports the screen as locked.
is_screen_locked() {
  /usr/bin/python3 -c '
try:
    import Quartz
    d = Quartz.CGSessionCopyCurrentDictionary() or {}
    raise SystemExit(0 if d.get("CGSSessionScreenIsLocked", 0) else 1)
except Exception:
    raise SystemExit(1)
' 2>/dev/null
}

is_lunch_time() {
  [[ "${LUNCH_ENABLED}" == "1" ]] || return 1

  local hour minute
  hour="$(date '+%H')"
  minute="$(date '+%M')"
  hour=$((10#$hour))
  minute=$((10#$minute))

  [[ "$hour" -eq "$LUNCH_HOUR" && "$minute" -eq "$LUNCH_MINUTE" ]]
}

show_notification() {
  local title="$1"
  local body="$2"
  local sound="$3"

  /usr/bin/osascript \
    -e "display notification \"${body//\"/\\\"}\" with title \"${title//\"/\\\"}\" sound name \"${sound//\"/\\\"}\""
}

should_remind() {
  if [[ "$FORCE" == "1" ]]; then
    return 0
  fi

  if [[ "$WEEKDAYS_ONLY" == "1" ]] && ! is_weekday; then
    log "skip: weekend"
    return 1
  fi

  if ! within_work_hours; then
    log "skip: outside work hours (${START_HOUR}:00–${END_HOUR}:00)"
    return 1
  fi

  if [[ "$SKIP_WHEN_LOCKED" == "1" ]] && is_screen_locked; then
    log "skip: screen locked"
    return 1
  fi

  return 0
}

resolve_reminder() {
  # Sets REMINDER_KIND, TITLE, BODY, SOUND for the notification to show.
  case "$REMINDER_MODE" in
    lunch)
      REMINDER_KIND="lunch"
      TITLE="$LUNCH_TITLE"
      BODY="$LUNCH_BODY"
      SOUND="${LUNCH_SOUND_NAME:-$SOUND_NAME}"
      ;;
    standup)
      REMINDER_KIND="standup"
      TITLE="$NOTIFICATION_TITLE"
      BODY="$NOTIFICATION_BODY"
      SOUND="$SOUND_NAME"
      ;;
    auto)
      if [[ "$FORCE" != "1" ]] && is_lunch_time; then
        REMINDER_KIND="lunch"
        TITLE="$LUNCH_TITLE"
        BODY="$LUNCH_BODY"
        SOUND="${LUNCH_SOUND_NAME:-$SOUND_NAME}"
      else
        REMINDER_KIND="standup"
        TITLE="$NOTIFICATION_TITLE"
        BODY="$NOTIFICATION_BODY"
        SOUND="$SOUND_NAME"
      fi
      ;;
  esac
}

usage() {
  cat <<'EOF'
Usage: standup-reminder.sh [options]

  (no args)        Run once: notify if within work hours
                   (lunch message at noon; stand-up otherwise)
  --test           Send the stand-up notification immediately
  --test-lunch     Send the lunch notification immediately
  --force          Same as --test
  --help           Show this help
EOF
}

main() {
  load_config

  case "${1:-}" in
    --help|-h)
      usage
      exit 0
      ;;
    --test|--force)
      FORCE=1
      REMINDER_MODE="standup"
      ;;
    --test-lunch)
      FORCE=1
      REMINDER_MODE="lunch"
      ;;
    "")
      FORCE=0
      REMINDER_MODE="auto"
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac

  if ! should_remind; then
    exit 0
  fi

  resolve_reminder
  show_notification "$TITLE" "$BODY" "$SOUND"
  log "notified (${REMINDER_KIND}): $BODY"
}

main "$@"
