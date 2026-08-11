#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../../scripts/xai-inference-preflight.sh
source "$ROOT/scripts/xai-inference-preflight.sh"

pass=0
fail=0
ok() { echo "OK  $*"; pass=$((pass + 1)); }
bad() { echo "FAIL  $*"; fail=$((fail + 1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Default model pin
[[ "$(xai_preflight_model)" == "grok-3" ]] && ok "default model" || bad "default model"

# Success shape
printf '%s\n' '{"id":"x","choices":[{"message":{"role":"assistant","content":"ok"}}]}' > "$tmp/ok.json"
xai_preflight_response_is_success 0 200 "$tmp/ok.json" && ok "success parse" || bad "success parse"

# Auth failure code
printf '%s\n' '{"code":"invalid-argument","error":"Incorrect API key provided."}' > "$tmp/bad.json"
[[ "$(xai_preflight_error_code "$tmp/bad.json")" == "invalid-argument" ]] && ok "error code" || bad "error code"

# Missing key fails without network
unset XAI_API_KEY || true
if xai_preflight_main >/dev/null 2>&1; then
  bad "missing key should fail"
else
  ok "missing key fails closed"
fi

echo "pass=$pass fail=$fail"
[[ "$fail" -eq 0 ]]
