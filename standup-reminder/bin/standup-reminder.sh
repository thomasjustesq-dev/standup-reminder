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
LOG_FILE="${HOME}/Library/Logs/standup-reminder.log"

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

show_notification() {
  local title="$1"
  local body="$2"
  local sound="$3"

  /usr/bin/osascript \
    -e "display notification \"${body//\"/\\\"}\" with title \"${title//\"/\\\"}\" sound name \"${sound//\"/\\\"}\""
}

should_remind() {
  if [[ "${FORCE:-0}" == "1" ]]; then
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

usage() {
  cat <<'EOF'
Usage: standup-reminder.sh [--test|--force|--help]

  (no args)   Run once: notify if within work hours
  --test      Send a notification immediately (ignores schedule)
  --force     Same as --test
  --help      Show this help
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
      ;;
    "")
      FORCE=0
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

  show_notification "$NOTIFICATION_TITLE" "$NOTIFICATION_BODY" "$SOUND_NAME"
  log "notified: $NOTIFICATION_BODY"
}

main "$@"
