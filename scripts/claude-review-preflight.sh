#!/usr/bin/env bash

# Prove that the credential used by claude-code-action can perform a minimal
# inference. Diagnostics intentionally use only transport status, HTTP status,
# and the structured error type; response messages and generated content are
# never printed.

ANTHROPIC_PREFLIGHT_TEMP_DIR=""

anthropic_preflight_response_is_success() {
  local curl_status="$1"
  local http_status="$2"
  local response_file="$3"

  [[ "$curl_status" -eq 0 ]] || return 1
  [[ "$http_status" == "200" ]] || return 1
  jq -e '
    type == "object"
    and .type == "message"
    and (.content | type == "array")
  ' "$response_file" >/dev/null 2>&1
}

anthropic_preflight_error_type() {
  local response_file="$1"
  local parsed

  if ! parsed="$(jq -r '
    if ((.error? | type) == "object")
       and ((.error.type? | type) == "string")
       and ((.error.type | length) > 0)
    then .error.type
    elif ((.type? | type) == "string") and (.type | test("_error$"))
    then .type
    else "unknown_error"
    end
  ' "$response_file" 2>/dev/null)"; then
    printf '%s\n' "malformed_response"
    return 0
  fi

  printf '%s\n' "$parsed"
}

# The model under test. The workflow declares it once (see the `env:` block in
# .github/workflows/claude-code-review.yml) and exports it here, so the probe
# and the review step can never disagree about which model was proven.
#
# The fallback is a literal rather than a hard failure so the script stays
# runnable by hand outside CI. Keep it equal to the workflow's value.
anthropic_preflight_model() {
  printf '%s' "${CLAUDE_REVIEW_MODEL:-claude-haiku-4-5}"
}

# True when GET /v1/models succeeds — i.e. the credential authenticates and the
# transport works, so an inference failure is about the account rather than the
# secret. Deliberately reports only success/failure; the body is never read out.
# Overridable so the diagnostic stays unit-testable without network access.
anthropic_preflight_can_list_models() {
  local auth_header
  if [[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
    auth_header="Authorization: Bearer ${CLAUDE_CODE_OAUTH_TOKEN}"
  elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    auth_header="x-api-key: ${ANTHROPIC_API_KEY}"
  else
    return 1
  fi

  curl --silent --show-error --output /dev/null --fail \
    --connect-timeout 10 --max-time 20 \
    "https://api.anthropic.com/v1/models?limit=1" \
    --header "anthropic-version: 2023-06-01" \
    --header "$auth_header" 2>/dev/null
}

anthropic_preflight_diagnostic() {
  local curl_status="$1"
  local http_status="$2"
  local response_file="$3"
  local error_type
  local advice

  if [[ "$curl_status" -ne 0 ]]; then
    printf '%s\n' \
      "Anthropic Messages preflight failed (transport error ${curl_status}). Check runner egress and api.anthropic.com availability."
    return 0
  fi

  error_type="$(anthropic_preflight_error_type "$response_file")"

  # A proxy or malformed upstream response may omit the structured type. Use
  # the HTTP class only as a fallback; never surface the response message.
  if [[ "$error_type" == "unknown_error" || "$error_type" == "malformed_response" ]]; then
    case "$http_status" in
      401) error_type="authentication_error" ;;
      402) error_type="billing_error" ;;
      403) error_type="permission_error" ;;
      429) error_type="rate_limit_error" ;;
      500|502|503|529) error_type="service_error" ;;
    esac
  fi

  case "$error_type" in
    authentication_error)
      advice="The configured credential was rejected; rotate or replace the repository secret."
      ;;
    permission_error)
      advice="The credential is valid but lacks access to the requested model or workspace."
      ;;
    billing_error)
      advice="The Anthropic account cannot fund inference; inspect billing and credit status."
      ;;
    rate_limit_error)
      advice="Anthropic rate-limited the probe; inspect account limits before retrying the review."
      ;;
    overloaded_error|api_error|service_error)
      advice="Anthropic reported a service failure; confirm service health and retry on a new head."
      ;;
    invalid_request_error|not_found_error)
      # The body is a fixed minimal Messages call, so the model is the only
      # variable in it — which makes "repin the model" the tempting read. On
      # 2026-08-04 that read was wrong: every model returned this same status,
      # because the account could not run inference at all. Metadata reads kept
      # working the whole time, so a models-list probe separates the two cases
      # and stops the next person burning a CI cycle per candidate model.
      if anthropic_preflight_can_list_models; then
        advice="The credential authenticates and can list models but cannot run inference (every model returns this). This is account-level, not a repo problem: check data retention, workspace, and billing in the Anthropic Console. Repinning CLAUDE_REVIEW_MODEL will not help."
      else
        advice="The credential cannot use model $(anthropic_preflight_model) and cannot list models; verify the secret and its workspace before repinning CLAUDE_REVIEW_MODEL."
      fi
      ;;
    malformed_response)
      advice="Anthropic returned a non-JSON response; inspect service or proxy health without publishing the body."
      ;;
    *)
      advice="Inspect Anthropic account and service health; the response body is intentionally suppressed."
      ;;
  esac

  printf '%s\n' \
    "Anthropic Messages preflight failed (HTTP ${http_status}; type ${error_type}). ${advice}"
}

anthropic_preflight_cleanup() {
  [[ -n "$ANTHROPIC_PREFLIGHT_TEMP_DIR" ]] || return 0
  rm -f -- \
    "$ANTHROPIC_PREFLIGHT_TEMP_DIR/request.json" \
    "$ANTHROPIC_PREFLIGHT_TEMP_DIR/response.json"
  rmdir -- "$ANTHROPIC_PREFLIGHT_TEMP_DIR" 2>/dev/null || true
}

anthropic_preflight_escape_workflow_command() {
  local value="$1"

  # GitHub workflow commands percent-decode these sequences. Escape percent
  # first so response-derived text cannot synthesize a newline or command.
  value="${value//%/%25}"
  value="${value//$'\r'/%0D}"
  value="${value//$'\n'/%0A}"
  printf '%s' "$value"
}

anthropic_preflight_emit_failure() {
  local diagnostic="$1"
  local escaped_diagnostic

  escaped_diagnostic="$(anthropic_preflight_escape_workflow_command "$diagnostic")"
  printf '::error::%s\n' "$escaped_diagnostic" >&2
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf 'Claude review blocked: %s\n' "$diagnostic" >> "$GITHUB_STEP_SUMMARY"
  fi
}

anthropic_preflight_main() {
  set -euo pipefail
  umask 077

  if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    anthropic_preflight_emit_failure \
      "Anthropic Messages preflight cannot run because curl or jq is unavailable."
    return 1
  fi

  local temp_parent="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
  if [[ ! -d "$temp_parent" ]]; then
    anthropic_preflight_emit_failure \
      "Anthropic Messages preflight cannot create a private response directory."
    return 1
  fi

  ANTHROPIC_PREFLIGHT_TEMP_DIR="$(mktemp -d "${temp_parent%/}/anthropic-preflight.XXXXXX")"
  trap anthropic_preflight_cleanup EXIT

  local request_file="$ANTHROPIC_PREFLIGHT_TEMP_DIR/request.json"
  local response_file="$ANTHROPIC_PREFLIGHT_TEMP_DIR/response.json"
  local -a auth_headers

  if [[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
    auth_headers=(
      --header "Authorization: Bearer ${CLAUDE_CODE_OAUTH_TOKEN}"
      --header "anthropic-beta: oauth-2025-04-20"
    )
  elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    auth_headers=(--header "x-api-key: ${ANTHROPIC_API_KEY}")
  else
    anthropic_preflight_emit_failure \
      "Anthropic Messages preflight has no credential. Configure ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN."
    return 1
  fi

  if ! jq -n -c \
      --arg model "$(anthropic_preflight_model)" \
      '{model: $model, max_tokens: 1, messages: [{role: "user", content: "Reply with OK."}]}' \
      > "$request_file"; then
    anthropic_preflight_emit_failure \
      "Anthropic Messages preflight could not construct its JSON request."
    return 1
  fi

  local http_status
  local curl_status
  set +e
  http_status="$(curl \
    --silent \
    --show-error \
    --connect-timeout 10 \
    --max-time 45 \
    --request POST \
    --output "$response_file" \
    --write-out '%{http_code}' \
    "https://api.anthropic.com/v1/messages" \
    --header "anthropic-version: 2023-06-01" \
    --header "content-type: application/json" \
    "${auth_headers[@]}" \
    --data-binary "@$request_file")"
  curl_status=$?
  set -e

  if anthropic_preflight_response_is_success "$curl_status" "$http_status" "$response_file"; then
    printf '%s\n' \
      "Anthropic Messages inference preflight passed (HTTP 200; response type message)."
    return 0
  fi

  local diagnostic
  diagnostic="$(anthropic_preflight_diagnostic "$curl_status" "$http_status" "$response_file")"
  anthropic_preflight_emit_failure "$diagnostic"
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  anthropic_preflight_main "$@"
fi
