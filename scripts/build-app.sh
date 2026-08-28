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
# -allowProvisioningUpdates lets automatic signing create/refresh Mac profiles.
if command -v xcodegen >/dev/null 2>&1 && command -v xcodebuild >/dev/null 2>&1 && xcodebuild -version >/dev/null 2>&1 && [[ -f project.yml ]]; then
  echo "→ xcodegen generate + xcodebuild (app + widget)"
  xcodegen generate
  xcodebuild \
    -scheme StandUpReminder \
    -configuration Release \
    -derivedDataPath "${ROOT_DIR}/.derivedData" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-BBTNHBK7VX}" \
    CODE_SIGN_STYLE=Automatic \
    ARCHS="${ARCHS:-arm64 x86_64}" \
    ONLY_ACTIVE_ARCH=NO \
    build
  BUILT=$(find "${ROOT_DIR}/.derivedData/Build/Products" -name "${APP_NAME}.app" -type d | head -n1)
  if [[ -z "${BUILT}" ]]; then
    echo "error: xcodebuild finished but ${APP_NAME}.app not found under .derivedData" >&2
    exit 1
  fi
  rm -rf "${APP_DIR}"
  mkdir -p "${ROOT_DIR}/dist"
  cp -R "${BUILT}" "${APP_DIR}"
  # Keep Xcode's Development / Developer ID signature. Do not ad-hoc re-sign.
else
  echo "→ swift build -c release (menu bar app; widget via xcodegen optional)"
  swift build -c release --product "${APP_NAME}"
  BIN_OUT="$(swift build -c release --show-bin-path)/${APP_NAME}"
  rm -rf "${APP_DIR}"
  mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
  cp "${BIN_OUT}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
  cp "${ROOT_DIR}/Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"
  chmod +x "${APP_DIR}/Contents/MacOS/${APP_NAME}"
  if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "${APP_DIR}" || true
  fi
fi

echo "Built: ${APP_DIR}"
codesign --verify --deep --strict "${APP_DIR}" 2>/dev/null && echo "codesign: OK" || echo "codesign: ad-hoc / unverified"
echo "Optional: ./scripts/notarize.sh  (Developer ID Application + notarytool)"
