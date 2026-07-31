#!/usr/bin/env bash
# Bump the whole app family to a new version in one shot.
#
#   ./scripts/bump-version.sh 4.3.0 8
#
# Touches every file that pins a version — project.yml (all targets),
# Resources/Info.plist, and the two Homebrew files — then verifies the result
# with check-versions.sh. Doing this by hand is how the widget extensions ended
# up shipping 4.2.0 while the app said 4.2.1.
#
# The Resources/*-Info.plist files are not touched: xcodegen writes those from
# project.yml on the next `xcodegen generate`.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $(basename "$0") <version> <build>" >&2
  echo "  e.g. $(basename "$0") 4.3.0 8" >&2
  exit 1
fi

VERSION="$1"
BUILD="$2"

if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: version must look like 4.3.0, got '${VERSION}'" >&2
  exit 1
fi
if [[ ! "${BUILD}" =~ ^[0-9]+$ ]]; then
  echo "error: build must be an integer, got '${BUILD}'" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# project.yml — every target's info: block.
sed -i '' -E \
  -e "s/^([[:space:]]*CFBundleShortVersionString:[[:space:]]*)\"[^\"]*\"/\1\"${VERSION}\"/" \
  -e "s/^([[:space:]]*CFBundleVersion:[[:space:]]*)\"[^\"]*\"/\1\"${BUILD}\"/" \
  project.yml

# Resources/Info.plist — the one hand-maintained plist. Edited in place rather
# than through PlistBuddy, which rewrites the file with its keys alphabetized
# and turns a two-line version bump into a whole-file diff.
# ${1} not $1: the version starts with a digit, and $1 followed by a digit
# parses as capture group 1N.
perl -0pi -e "s{(<key>CFBundleShortVersionString</key>\s*<string>)[^<]*}{\${1}${VERSION}}" Resources/Info.plist
perl -0pi -e "s{(<key>CFBundleVersion</key>\s*<string>)[^<]*}{\${1}${BUILD}}" Resources/Info.plist

# Homebrew formula and cask — marketing version only, no build number.
sed -i '' -E "s/^([[:space:]]*version )\"[^\"]*\"/\1\"${VERSION}\"/" \
  Formula/standup-reminder.rb Casks/standup-reminder.rb

echo "→ bumped to ${VERSION} (build ${BUILD})"
./scripts/check-versions.sh

cat <<EOF

Next:
  xcodegen generate          # rewrites the generated plists
  git commit -am "chore: bump version to ${VERSION} (build ${BUILD})"
  git tag v${VERSION} && git push origin v${VERSION}
EOF
