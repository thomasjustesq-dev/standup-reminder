#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

pass=0
fail=0
ok() { echo "OK  $*"; pass=$((pass + 1)); }
bad() { echo "FAIL  $*"; fail=$((fail + 1)); }

order_line="$(rg -n 'Preference order' scripts/fleet-inference-canary.sh || true)"
echo "$order_line" | rg -q 'grok → gemini → kimi → openai → anthropic' \
  && ok "preference comment" || bad "preference comment"

ids=()
while IFS= read -r line; do
  if [[ "$line" =~ \"([a-z]+)\| ]]; then
    ids+=("${BASH_REMATCH[1]}")
  fi
done < scripts/fleet-inference-canary.sh
expected="grok gemini kimi openai anthropic"
got="${ids[*]}"
if [[ "$got" == "$expected" ]]; then
  ok "ORDER array $got"
else
  bad "ORDER array got '$got' want '$expected'"
fi

if env -u XAI_API_KEY -u GEMINI_API_KEY -u MOONSHOT_API_KEY -u OPENAI_API_KEY \
    -u ANTHROPIC_API_KEY -u CLAUDE_CODE_OAUTH_TOKEN \
  bash scripts/fleet-inference-canary.sh >/tmp/fleet-canary-empty.out 2>&1; then
  bad "empty secrets should fail"
else
  ok "empty secrets fail closed"
fi

if OPENAI_COMPAT_MODEL=gpt-4o-mini bash scripts/openai-compatible-inference-preflight.sh >/dev/null 2>&1; then
  bad "openai-compat missing key"
else
  ok "openai-compat missing key fails"
fi

if bash scripts/gemini-inference-preflight.sh >/dev/null 2>&1; then
  bad "gemini missing key"
else
  ok "gemini missing key fails"
fi

# ORDER first entry is grok
first="$(printf '%s\n' "${ids[0]}")"
[[ "$first" == "grok" ]] && ok "first preference grok" || bad "first preference $first"

echo "pass=$pass fail=$fail"
[[ "$fail" -eq 0 ]]
