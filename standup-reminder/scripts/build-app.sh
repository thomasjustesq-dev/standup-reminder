#!/usr/bin/env bash
# Build StandUpReminder.app (macOS only).
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Building the app requires macOS with Xcode / Swift toolchain." >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="StandUpReminder"
APP_DIR="${ROOT_DIR}/dist/${APP_NAME}.app"

cd "${ROOT_DIR}"

# Prefer XcodeGen bundle (includes widget) when available.
if command -v xcodegen >/dev/null 2>&1 && [[ -f project.yml ]]; then
  echo "→ xcodegen generate + xcodebuild (app + widget)"
  xcodegen generate
  xcodebuild -scheme StandUpReminder -configuration Release -derivedDataPath "${ROOT_DIR}/.derivedData" build
  BUILT=$(find "${ROOT_DIR}/.derivedData" -name "${APP_NAME}.app" -type d | head -n1)
  rm -rf "${APP_DIR}"
  mkdir -p "${ROOT_DIR}/dist"
  cp -R "${BUILT}" "${APP_DIR}"
else
  echo "→ swift build -c release (menu bar app; widget via xcodegen optional)"
  swift build -c release --product "${APP_NAME}"
  BIN_OUT="$(swift build -c release --show-bin-path)/${APP_NAME}"
  rm -rf "${APP_DIR}"
  mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
  cp "${BIN_OUT}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
  cp "${ROOT_DIR}/Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"
  chmod +x "${APP_DIR}/Contents/MacOS/${APP_NAME}"
fi

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "${APP_DIR}" || true
fi

echo "Built: ${APP_DIR}"
echo "Optional: ./scripts/notarize.sh  (Developer ID + notarytool)"
