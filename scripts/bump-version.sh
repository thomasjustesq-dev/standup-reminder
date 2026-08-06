#!/usr/bin/env bash
# Bump marketing version + build across every source of truth.
# Usage: ./scripts/bump-version.sh 4.2.2 8
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKETING="${1:-}"
BUILD="${2:-}"
if [[ -z "$MARKETING" || -z "$BUILD" ]]; then
  echo "usage: $0 <marketing e.g. 4.2.2> <build e.g. 8>" >&2
  exit 1
fi

# AppIdentity.swift
perl -i -pe "s/static let marketing = \".*\"/static let marketing = \"$MARKETING\"/" \
  "$ROOT/Sources/StandUpReminderCore/AppIdentity.swift"
perl -i -pe "s/static let build = \".*\"/static let build = \"$BUILD\"/" \
  "$ROOT/Sources/StandUpReminderCore/AppIdentity.swift"

# Mac Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $MARKETING" "$ROOT/Resources/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$ROOT/Resources/Info.plist"

# Widget Info.plist
if [[ -f "$ROOT/Sources/StandUpReminderWidget/Info.plist" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $MARKETING" \
    "$ROOT/Sources/StandUpReminderWidget/Info.plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" \
    "$ROOT/Sources/StandUpReminderWidget/Info.plist" 2>/dev/null || true
fi

# project.yml iOS/Watch versions
perl -i -pe "s/CFBundleShortVersionString: \"[0-9.]+\"/CFBundleShortVersionString: \"$MARKETING\"/g" \
  "$ROOT/project.yml"
perl -i -pe "s/CFBundleVersion: \"[0-9]+\"/CFBundleVersion: \"$BUILD\"/g" \
  "$ROOT/project.yml"

# Formula + Cask
perl -i -pe "s/version \"[0-9.]+\"/version \"$MARKETING\"/" "$ROOT/Formula/standup-reminder.rb"
perl -i -pe "s/version \"[0-9.]+\"/version \"$MARKETING\"/" "$ROOT/Casks/standup-reminder.rb"

# README header if present
perl -i -pe "s/^# Stand Up Reminder · v[0-9.]+/# Stand Up Reminder · v$MARKETING/" "$ROOT/README.md" || true

echo "Bumped to $MARKETING ($BUILD)"
echo "Verify: grep -R \"$MARKETING\" Resources project.yml Formula Casks Sources/StandUpReminderCore/AppIdentity.swift | head"
