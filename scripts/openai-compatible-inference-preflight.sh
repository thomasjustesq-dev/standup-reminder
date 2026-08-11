#!/usr/bin/env bash
# Minimal chat-completions preflight for OpenAI-compatible endpoints.
# Env:
#   OPENAI_COMPAT_API_KEY  (required)
#   OPENAI_COMPAT_BASE_URL (default https://api.openai.com/v1)
#   OPENAI_COMPAT_MODEL    (required)
#   OPENAI_COMPAT_LABEL    (default openai-compatible) — for diagnostics only
#
# Never prints response message text.

openai_compat_preflight_main() {
  set -euo pipefail
  umask 077

  local label="${OPENAI_COMPAT_LABEL:-openai-compatible}"
  local base="${OPENAI_COMPAT_BASE_URL:-https://api.openai.com/v1}"
  base="${base%/}"

  if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    printf '::error::%s preflight cannot run because curl or jq is unavailable.\n' "$label" >&2
    return 1
  fi
  if [[ -z "${OPENAI_COMPAT_API_KEY:-}" ]]; then
    printf '::error::%s preflight missing OPENAI_COMPAT_API_KEY.\n' "$label" >&2
    return 1
  fi
  if [[ -z "${OPENAI_COMPAT_MODEL:-}" ]]; then
    printf '::error::%s preflight missing OPENAI_COMPAT_MODEL.\n' "$label" >&2
    return 1
  fi

  local temp_parent="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
  local td
  td="$(mktemp -d "${temp_parent%/}/openai-compat-preflight.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf -- '$td'" EXIT

  local request_file="$td/request.json"
  local response_file="$td/response.json"
  jq -n --arg model "$OPENAI_COMPAT_MODEL" \
    '{model:$model,messages:[{role:"user",content:"ping"}],max_tokens:1,temperature:0}' \
    > "$request_file"

  local http_status curl_status
  set +e
  http_status="$(
    curl --silent --show-error \
      --connect-timeout 10 --max-time 30 \
      --output "$response_file" \
      --write-out '%{http_code}' \
      "${base}/chat/completions" \
      --header "Authorization: Bearer ${OPENAI_COMPAT_API_KEY}" \
      --header "Content-Type: application/json" \
      --data @"$request_file"
  )"
  curl_status=$?
  set -e

  if [[ "$curl_status" -eq 0 && "$http_status" == "200" ]] && \
     jq -e 'type=="object" and ((.choices|type)=="array") and ((.choices|length)>0)' \
       "$response_file" >/dev/null 2>&1; then
    printf '%s inference preflight OK (model %s)\n' "$label" "$OPENAI_COMPAT_MODEL"
    return 0
  fi

  local code
  code="$(jq -r '
    if ((.error?.type? | type) == "string") and ((.error.type | length) > 0) then .error.type
    elif ((.error?.code? | type) == "string") and ((.error.code | length) > 0) then .error.code
    elif ((.code? | type) == "string") and ((.code | length) > 0) then .code
    else "unknown_error" end
  ' "$response_file" 2>/dev/null || printf 'malformed_response')"

  if [[ "$curl_status" -ne 0 ]]; then
    printf '::error::%s preflight transport error %s (base %s).\n' "$label" "$curl_status" "$base" >&2
  else
    printf '::error::%s preflight failed (HTTP %s; code %s; model %s). Check the repository secret and account limits.\n' \
      "$label" "$http_status" "$code" "$OPENAI_COMPAT_MODEL" >&2
  fi
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  openai_compat_preflight_main "$@"
fi
