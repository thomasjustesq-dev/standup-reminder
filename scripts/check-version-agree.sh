#!/usr/bin/env bash
# Fail if marketing version / build disagree across sources of truth.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ID="$ROOT/Sources/StandUpReminderCore/AppIdentity.swift"
MARKETING=$(sed -n 's/.*static let marketing = "\([^"]*\)".*/\1/p' "$ID" | head -1)
BUILD=$(sed -n 's/.*static let build = "\([^"]*\)".*/\1/p' "$ID" | head -1)
if [[ -z "$MARKETING" || -z "$BUILD" ]]; then
  echo "Could not read AppVersion from AppIdentity.swift" >&2
  exit 1
fi
fail=0
check() {
  local file="$1" pattern="$2" expect="$3" label="$4"
  if ! grep -qE "$pattern" "$file" 2>/dev/null; then
    echo "MISSING $label in $file (want $expect)" >&2
    fail=1
  fi
}
check "$ROOT/Resources/Info.plist" "CFBundleShortVersionString|$MARKETING" "$MARKETING" "marketing"
# PlistBuddy for exact
plist_m=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist" 2>/dev/null || true)
plist_b=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT/Resources/Info.plist" 2>/dev/null || true)
if [[ "$plist_m" != "$MARKETING" ]]; then echo "Info.plist marketing $plist_m != $MARKETING" >&2; fail=1; fi
if [[ "$plist_b" != "$BUILD" ]]; then echo "Info.plist build $plist_b != $BUILD" >&2; fail=1; fi
if ! grep -q "version \"$MARKETING\"" "$ROOT/Formula/standup-reminder.rb"; then
  echo "Formula version mismatch" >&2; fail=1
fi
if ! grep -q "version \"$MARKETING\"" "$ROOT/Casks/standup-reminder.rb"; then
  echo "Cask version mismatch" >&2; fail=1
fi
if ! grep -q "CFBundleShortVersionString: \"$MARKETING\"" "$ROOT/project.yml"; then
  echo "project.yml marketing mismatch" >&2; fail=1
fi
if [[ $fail -ne 0 ]]; then exit 1; fi
echo "Version agree: $MARKETING ($BUILD)"
