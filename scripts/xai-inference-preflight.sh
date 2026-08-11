#!/usr/bin/env bash
# Prove the repository XAI_API_KEY can authenticate and run a minimal
# chat-completions inference against api.x.ai. Diagnostics intentionally use
# only transport status, HTTP status, and structured error codes — response
# message text is never printed.

XAI_PREFLIGHT_TEMP_DIR=""

xai_preflight_model() {
  printf '%s' "${XAI_INFERENCE_MODEL:-grok-3}"
}

xai_preflight_response_is_success() {
  local curl_status="$1"
  local http_status="$2"
  local response_file="$3"

  [[ "$curl_status" -eq 0 ]] || return 1
  [[ "$http_status" == "200" ]] || return 1
  jq -e '
    type == "object"
    and ((.choices | type) == "array")
    and ((.choices | length) > 0)
  ' "$response_file" >/dev/null 2>&1
}

xai_preflight_error_code() {
  local response_file="$1"
  local parsed

  if ! parsed="$(jq -r '
    if ((.code? | type) == "string") and ((.code | length) > 0)
    then .code
    elif ((.error? | type) == "string") and ((.error | length) > 0)
    then "error_message"
    elif ((.error? | type) == "object")
         and ((.error.code? | type) == "string")
         and ((.error.code | length) > 0)
    then .error.code
    else "unknown_error"
    end
  ' "$response_file" 2>/dev/null)"; then
    printf '%s\n' "malformed_response"
    return 0
  fi
  printf '%s\n' "$parsed"
}

xai_preflight_can_list_models() {
  [[ -n "${XAI_API_KEY:-}" ]] || return 1
  curl --silent --show-error --output /dev/null --fail \
    --connect-timeout 10 --max-time 20 \
    "https://api.x.ai/v1/models" \
    --header "Authorization: Bearer ${XAI_API_KEY}" 2>/dev/null
}

xai_preflight_diagnostic() {
  local curl_status="$1"
  local http_status="$2"
  local response_file="$3"
  local error_code
  local advice

  if [[ "$curl_status" -ne 0 ]]; then
    printf '%s\n' \
      "xAI chat-completions preflight failed (transport error ${curl_status}). Check runner egress and api.x.ai availability."
    return 0
  fi

  error_code="$(xai_preflight_error_code "$response_file")"
  if [[ "$error_code" == "unknown_error" || "$error_code" == "malformed_response" ]]; then
    case "$http_status" in
      401) error_code="authentication_error" ;;
      402) error_code="billing_error" ;;
      403) error_code="permission_error" ;;
      429) error_code="rate_limit_error" ;;
      500|502|503|529) error_code="service_error" ;;
    esac
  fi

  case "$error_code" in
    authentication_error|invalid-argument)
      advice="The configured XAI_API_KEY was rejected; rotate the repository secret from console.x.ai."
      ;;
    permission_error)
      advice="The credential is valid but lacks access to the requested model."
      ;;
    billing_error)
      advice="The xAI account cannot fund inference; inspect billing/credits at console.x.ai."
      ;;
    rate_limit_error)
      advice="xAI rate-limited the probe; inspect account limits before relying on Grok inference."
      ;;
    service_error)
      advice="xAI reported a service failure; confirm service health and retry."
      ;;
    malformed_response)
      advice="xAI returned a non-JSON response; inspect service or proxy health without publishing the body."
      ;;
    *)
      if xai_preflight_can_list_models; then
        advice="The credential authenticates and can list models but cannot run inference for model $(xai_preflight_model). Check model access and account limits; repinning XAI_INFERENCE_MODEL may not help."
      else
        advice="Inspect XAI_API_KEY and xAI account health; the response body is intentionally suppressed."
      fi
      ;;
  esac

  printf '%s\n' \
    "xAI chat-completions preflight failed (HTTP ${http_status}; code ${error_code}). ${advice}"
}

xai_preflight_cleanup() {
  [[ -n "$XAI_PREFLIGHT_TEMP_DIR" ]] || return 0
  rm -f -- \
    "$XAI_PREFLIGHT_TEMP_DIR/request.json" \
    "$XAI_PREFLIGHT_TEMP_DIR/response.json"
  rmdir -- "$XAI_PREFLIGHT_TEMP_DIR" 2>/dev/null || true
}

xai_preflight_escape_workflow_command() {
  local value="$1"
  value="${value//%/%25}"
  value="${value//$'\r'/%0D}"
  value="${value//$'\n'/%0A}"
  printf '%s' "$value"
}

xai_preflight_emit_failure() {
  local diagnostic="$1"
  local escaped_diagnostic
  escaped_diagnostic="$(xai_preflight_escape_workflow_command "$diagnostic")"
  printf '::error::%s\n' "$escaped_diagnostic" >&2
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf 'xAI inference canary blocked: %s\n' "$diagnostic" >> "$GITHUB_STEP_SUMMARY"
  fi
}

xai_preflight_main() {
  set -euo pipefail
  umask 077

  if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    xai_preflight_emit_failure \
      "xAI preflight cannot run because curl or jq is unavailable."
    return 1
  fi

  if [[ -z "${XAI_API_KEY:-}" ]]; then
    xai_preflight_emit_failure \
      "XAI_API_KEY is not set. Store it as a repository Actions secret and pass secrets.XAI_API_KEY into the canary step."
    return 1
  fi

  local temp_parent="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
  if [[ ! -d "$temp_parent" ]]; then
    xai_preflight_emit_failure \
      "xAI preflight cannot create a private response directory."
    return 1
  fi

  XAI_PREFLIGHT_TEMP_DIR="$(mktemp -d "${temp_parent%/}/xai-preflight.XXXXXX")"
  trap xai_preflight_cleanup EXIT

  local request_file="$XAI_PREFLIGHT_TEMP_DIR/request.json"
  local response_file="$XAI_PREFLIGHT_TEMP_DIR/response.json"
  local model
  model="$(xai_preflight_model)"

  jq -n \
    --arg model "$model" \
    '{
      model: $model,
      messages: [{role: "user", content: "ping"}],
      max_tokens: 1,
      temperature: 0
    }' > "$request_file"

  local http_status curl_status
  set +e
  http_status="$(
    curl --silent --show-error \
      --connect-timeout 10 --max-time 30 \
      --output "$response_file" \
      --write-out '%{http_code}' \
      "https://api.x.ai/v1/chat/completions" \
      --header "Authorization: Bearer ${XAI_API_KEY}" \
      --header "Content-Type: application/json" \
      --data @"$request_file"
  )"
  curl_status=$?
  set -e

  if xai_preflight_response_is_success "$curl_status" "$http_status" "$response_file"; then
    printf 'xAI inference preflight OK (model %s)\n' "$model"
    return 0
  fi

  xai_preflight_emit_failure \
    "$(xai_preflight_diagnostic "$curl_status" "$http_status" "$response_file")"
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  xai_preflight_main "$@"
fi
