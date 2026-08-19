#!/usr/bin/env bash
# Pick the first healthy BYOK provider and export Copilot CLI env vars.
# Order: grok → openai (Codex) → kimi → gemini.
# Native GitHub Copilot is last (leave COPILOT_PROVIDER_* unset).
# Do not export ANTHROPIC_API_KEY.
#
# Copilot Agents secrets arrive as XAI_API_KEY etc. Actions-only runs may
# only have ACTIONS_* copies — never clobber a non-empty Agents value.

set -euo pipefail

XAI_API_KEY="${XAI_API_KEY:-${ACTIONS_XAI_API_KEY:-}}"
OPENAI_API_KEY="${OPENAI_API_KEY:-${ACTIONS_OPENAI_API_KEY:-}}"
MOONSHOT_API_KEY="${MOONSHOT_API_KEY:-${ACTIONS_MOONSHOT_API_KEY:-}}"
KIMI_API_KEY="${KIMI_API_KEY:-${ACTIONS_KIMI_API_KEY:-}}"
GEMINI_API_KEY="${GEMINI_API_KEY:-${ACTIONS_GEMINI_API_KEY:-}}"

umask 077
PROBE_FILE="$(mktemp "${TMPDIR:-/tmp}/fleet-select.XXXXXX.json")"
trap 'rm -f -- "$PROBE_FILE"' EXIT

log() { printf '%s\n' "$*"; }

healthy_openai_compat() {
  local base="$1" key="$2"
  local http
  http="$(
    curl --silent --show-error --connect-timeout 8 --max-time 15 \
      --output "$PROBE_FILE" --write-out '%{http_code}' \
      --header "Authorization: Bearer ${key}" \
      --header "Content-Type: application/json" \
      "${base%/}/models" || true
  )"
  [[ "$http" == "200" ]]
}

healthy_gemini() {
  local key="$1" model="$2"
  local http
  http="$(
    curl --silent --show-error --connect-timeout 8 --max-time 15 \
      --output "$PROBE_FILE" --write-out '%{http_code}' \
      --header "x-goog-api-key: ${key}" \
      "https://generativelanguage.googleapis.com/v1beta/openai/models/${model}" || true
  )"
  if [[ "$http" == "200" ]]; then
    return 0
  fi
  http="$(
    curl --silent --show-error --connect-timeout 8 --max-time 15 \
      --output "$PROBE_FILE" --write-out '%{http_code}' \
      --header "x-goog-api-key: ${key}" \
      "https://generativelanguage.googleapis.com/v1beta/openai/models" || true
  )"
  [[ "$http" == "200" ]]
}

export_provider() {
  local name="$1" base="$2" key="$3" model="$4" ptype="$5"
  log "fleet-select: using ${name} model=${model}"
  if [[ -n "${GITHUB_ENV:-}" ]]; then
    {
      printf 'COPILOT_PROVIDER_BASE_URL=%s\n' "$base"
      printf 'COPILOT_PROVIDER_API_KEY=%s\n' "$key"
      printf 'COPILOT_PROVIDER_TYPE=%s\n' "$ptype"
      printf 'COPILOT_MODEL=%s\n' "$model"
      printf 'FLEET_INFERENCE_PROVIDER=%s\n' "$name"
    } >> "$GITHUB_ENV"
  fi
  mkdir -p "${HOME:-/tmp}"
  {
    printf 'export COPILOT_PROVIDER_BASE_URL=%q\n' "$base"
    printf 'export COPILOT_PROVIDER_API_KEY=%q\n' "$key"
    printf 'export COPILOT_PROVIDER_TYPE=%q\n' "$ptype"
    printf 'export COPILOT_MODEL=%q\n' "$model"
    printf 'export FLEET_INFERENCE_PROVIDER=%q\n' "$name"
  } > "${HOME}/.fleet-inference.env"
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf 'Selected BYOK provider: **%s** (`%s`)\n' "$name" "$model" >> "$GITHUB_STEP_SUMMARY"
  fi
}

if [[ -n "${XAI_API_KEY:-}" ]] && healthy_openai_compat "https://api.x.ai/v1" "$XAI_API_KEY"; then
  export_provider grok "https://api.x.ai/v1" "$XAI_API_KEY" "${XAI_INFERENCE_MODEL:-grok-4.6}" openai
  exit 0
fi
log "fleet-select: grok unavailable"

if [[ -n "${OPENAI_API_KEY:-}" ]] && healthy_openai_compat "https://api.openai.com/v1" "$OPENAI_API_KEY"; then
  export_provider openai "https://api.openai.com/v1" "$OPENAI_API_KEY" "${OPENAI_INFERENCE_MODEL:-gpt-5.6-sol}" openai
  exit 0
fi
log "fleet-select: openai unavailable"

kimi_key="${MOONSHOT_API_KEY:-${KIMI_API_KEY:-}}"
if [[ -n "${kimi_key}" ]] && healthy_openai_compat "https://api.moonshot.ai/v1" "$kimi_key"; then
  export_provider kimi "https://api.moonshot.ai/v1" "$kimi_key" "${KIMI_INFERENCE_MODEL:-kimi-k2.7-code}" openai
  exit 0
fi
log "fleet-select: kimi unavailable"

if [[ -n "${GEMINI_API_KEY:-}" ]] && healthy_gemini "$GEMINI_API_KEY" "${GEMINI_INFERENCE_MODEL:-gemini-3.7-flash}"; then
  export_provider gemini "https://generativelanguage.googleapis.com/v1beta/openai" "$GEMINI_API_KEY" "${GEMINI_INFERENCE_MODEL:-gemini-3.7-flash}" openai
  exit 0
fi
log "fleet-select: gemini unavailable"

log "fleet-select: no healthy BYOK provider; Copilot will use GitHub-hosted models"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  printf 'No healthy BYOK provider. Falling back to GitHub-hosted Copilot.\n' >> "$GITHUB_STEP_SUMMARY"
fi
exit 0
