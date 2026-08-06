#!/usr/bin/env bash
# Fail if StandUpReminderCore imports AppKit / UIKit / WatchKit / AVFoundation.
# The core is the pure schedule + config + iCloud layer shared by platforms.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/Sources/StandUpReminderCore"
if [[ ! -d "$CORE" ]]; then
  echo "missing $CORE" >&2
  exit 1
fi
hits=$(rg -n 'import (AppKit|UIKit|WatchKit|AVFoundation|EventKit|ServiceManagement)' "$CORE" || true)
if [[ -n "$hits" ]]; then
  echo "StandUpReminderCore must stay platform-pure (no AppKit/UIKit/etc):" >&2
  echo "$hits" >&2
  exit 1
fi
echo "Core purity OK"
