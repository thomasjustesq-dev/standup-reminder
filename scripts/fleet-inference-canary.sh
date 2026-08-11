#!/usr/bin/env bash
# Probe fleet inference secrets in Thomas's preferred order:
#   grok → gemini → kimi → openai → anthropic
# Missing secrets are SKIP. Present-but-broken secrets are FAIL.
# Exit 0 if at least one present secret can infer; else 1.
# Prints the preferred (first healthy) provider for step summary.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Preference order is intentional and load-bearing. Do not reorder without
# Thomas. Each entry: id|display|probe-function-name
ORDER=(
  "grok|Grok (xAI)|probe_grok"
  "gemini|Gemini|probe_gemini"
  "kimi|Kimi (Moonshot)|probe_kimi"
  "openai|OpenAI|probe_openai"
  "anthropic|Anthropic|probe_anthropic"
)

preferred=""
ok_count=0
fail_count=0
skip_count=0
configured_count=0

summary_line() {
  printf '%s\n' "$1"
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf '%s\n' "$1" >> "$GITHUB_STEP_SUMMARY"
  fi
}

probe_grok() {
  [[ -n "${XAI_API_KEY:-}" ]] || return 2
  bash scripts/xai-inference-preflight.sh
}

probe_gemini() {
  [[ -n "${GEMINI_API_KEY:-}" ]] || return 2
  bash scripts/gemini-inference-preflight.sh
}

probe_kimi() {
  [[ -n "${MOONSHOT_API_KEY:-}" ]] || return 2
  OPENAI_COMPAT_API_KEY="$MOONSHOT_API_KEY" \
  OPENAI_COMPAT_BASE_URL="${MOONSHOT_BASE_URL:-https://api.moonshot.ai/v1}" \
  OPENAI_COMPAT_MODEL="${KIMI_INFERENCE_MODEL:-moonshot-v1-8k}" \
  OPENAI_COMPAT_LABEL="Kimi/Moonshot" \
    bash scripts/openai-compatible-inference-preflight.sh
}

probe_openai() {
  [[ -n "${OPENAI_API_KEY:-}" ]] || return 2
  OPENAI_COMPAT_API_KEY="$OPENAI_API_KEY" \
  OPENAI_COMPAT_BASE_URL="${OPENAI_BASE_URL:-https://api.openai.com/v1}" \
  OPENAI_COMPAT_MODEL="${OPENAI_INFERENCE_MODEL:-gpt-4o-mini}" \
  OPENAI_COMPAT_LABEL="OpenAI" \
    bash scripts/openai-compatible-inference-preflight.sh
}

probe_anthropic() {
  if [[ -z "${ANTHROPIC_API_KEY:-}" && -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
    return 2
  fi
  if [[ -z "${CLAUDE_REVIEW_MODEL:-}" ]]; then
    CLAUDE_REVIEW_MODEL="$(
      sed -n 's/^  CLAUDE_REVIEW_MODEL: *//p' \
        .github/workflows/claude-code-review.yml 2>/dev/null | head -1
    )"
    export CLAUDE_REVIEW_MODEL
  fi
  CLAUDE_REVIEW_MODEL="${CLAUDE_REVIEW_MODEL:-claude-haiku-4-5}"
  export CLAUDE_REVIEW_MODEL
  bash scripts/claude-review-preflight.sh
}

summary_line "## Fleet inference canary"
summary_line ""
summary_line "Preference order: **grok → gemini → kimi → openai → anthropic**"
summary_line ""
summary_line "| # | Provider | Status |"
summary_line "|---|---|---|"

rank=0
for entry in "${ORDER[@]}"; do
  rank=$((rank + 1))
  IFS='|' read -r id display probe_fn <<< "$entry"
  set +e
  "$probe_fn"
  rc=$?
  set -e
  case "$rc" in
    0)
      configured_count=$((configured_count + 1))
      ok_count=$((ok_count + 1))
      status="OK"
      if [[ -z "$preferred" ]]; then
        preferred="$id"
      fi
      ;;
    2)
      skip_count=$((skip_count + 1))
      status="SKIP (secret not set)"
      ;;
    *)
      configured_count=$((configured_count + 1))
      fail_count=$((fail_count + 1))
      status="FAIL"
      ;;
  esac
  summary_line "| ${rank} | ${display} (\`${id}\`) | ${status} |"
  echo "fleet-canary: ${id} -> ${status}"
done

summary_line ""
if [[ -n "$preferred" ]]; then
  summary_line "**Preferred provider (first healthy): \`${preferred}\`**"
  echo "fleet-canary: preferred=${preferred}"
else
  summary_line "**Preferred provider: none healthy**"
  echo "fleet-canary: preferred=none"
fi

echo "fleet-canary: ok=${ok_count} fail=${fail_count} skip=${skip_count} configured=${configured_count}"

if [[ "$configured_count" -eq 0 ]]; then
  echo "::error::No fleet inference secrets are configured (XAI/GEMINI/MOONSHOT/OPENAI/ANTHROPIC)."
  exit 1
fi
if [[ "$ok_count" -eq 0 ]]; then
  echo "::error::Every configured fleet inference secret failed preflight (ok=0 fail=${fail_count})."
  exit 1
fi
if [[ "$fail_count" -gt 0 ]]; then
  echo "::warning::${fail_count} configured provider(s) failed preflight; preferred=${preferred:-none}"
fi
exit 0
