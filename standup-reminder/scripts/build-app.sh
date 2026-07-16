#!/usr/bin/env bash
# Build StandUpReminder.app (macOS only).
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Building the app requires macOS with Xcode / Swift toolchain." >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/.build"
APP_NAME="StandUpReminder"
APP_DIR="${ROOT_DIR}/dist/${APP_NAME}.app"
BIN_OUT="${BUILD_DIR}/release/${APP_NAME}"

cd "${ROOT_DIR}"

echo "→ swift build -c release"
swift build -c release --product "${APP_NAME}"

# Resolve binary path (SPM layout can vary slightly by arch)
if [[ ! -x "${BIN_OUT}" ]]; then
  BIN_OUT="$(swift build -c release --show-bin-path)/${APP_NAME}"
fi

echo "→ packaging ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"

cp "${BIN_OUT}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp "${ROOT_DIR}/Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"
chmod +x "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# Ad-hoc sign so macOS will launch locally (Gatekeeper may still prompt on first open).
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "${APP_DIR}" || true
fi

echo "Built: ${APP_DIR}"
