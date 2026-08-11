#!/usr/bin/env bash
# Minimal Gemini generateContent preflight. Never prints response text.
# Env: GEMINI_API_KEY (required), GEMINI_INFERENCE_MODEL (default gemini-2.0-flash)

gemini_preflight_main() {
  set -euo pipefail
  umask 077

  local model="${GEMINI_INFERENCE_MODEL:-gemini-2.0-flash}"

  if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    printf '::error::Gemini preflight cannot run because curl or jq is unavailable.\n' >&2
    return 1
  fi
  if [[ -z "${GEMINI_API_KEY:-}" ]]; then
    printf '::error::GEMINI_API_KEY is not set.\n' >&2
    return 1
  fi

  local temp_parent="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
  local td
  td="$(mktemp -d "${temp_parent%/}/gemini-preflight.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf -- '$td'" EXIT

  local request_file="$td/request.json"
  local response_file="$td/response.json"
  jq -n '{contents:[{parts:[{text:"ping"}]}],generationConfig:{maxOutputTokens:1}}' \
    > "$request_file"

  local url="https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent"
  local http_status curl_status
  set +e
  http_status="$(
    curl --silent --show-error \
      --connect-timeout 10 --max-time 30 \
      --output "$response_file" \
      --write-out '%{http_code}' \
      "$url" \
      --header "x-goog-api-key: ${GEMINI_API_KEY}" \
      --header "Content-Type: application/json" \
      --data @"$request_file"
  )"
  curl_status=$?
  set -e

  if [[ "$curl_status" -eq 0 && "$http_status" == "200" ]] && \
     jq -e 'type=="object" and ((.candidates|type)=="array") and ((.candidates|length)>0)' \
       "$response_file" >/dev/null 2>&1; then
    printf 'Gemini inference preflight OK (model %s)\n' "$model"
    return 0
  fi

  local code
  code="$(jq -r '
    if ((.error?.status? | type) == "string") and ((.error.status | length) > 0) then .error.status
    elif ((.error?.code? | type) == "number") then (.error.code|tostring)
    else "unknown_error" end
  ' "$response_file" 2>/dev/null || printf 'malformed_response')"

  if [[ "$curl_status" -ne 0 ]]; then
    printf '::error::Gemini preflight transport error %s.\n' "$curl_status" >&2
  else
    printf '::error::Gemini preflight failed (HTTP %s; code %s; model %s). Rotate GEMINI_API_KEY or check model access.\n' \
      "$http_status" "$code" "$model" >&2
  fi
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  gemini_preflight_main "$@"
fi
