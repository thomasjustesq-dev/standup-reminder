# Fleet inference preference

Thomas (2026-08-19): **BYOK first, GitHub-hosted Copilot last.** Do not spend
Copilot premium requests when one of these keys is healthy.

GitHub-hosted runners have no localhost OAuth proxies. Use console keys:

1. **Grok** — `XAI_API_KEY`, `https://api.x.ai/v1`, model `grok-4.6`
2. **Codex** — `OPENAI_API_KEY`, `https://api.openai.com/v1`, model `gpt-5.6-sol`
3. **Kimi** — `MOONSHOT_API_KEY` (fallback `KIMI_API_KEY`), `https://api.moonshot.ai/v1`, model `kimi-k2.7-code`
4. **Gemini** — `GEMINI_API_KEY`, AI Studio, model `gemini-3.7-flash`
5. **GitHub Copilot (native)** — only if every key above is missing or unhealthy

Do **not** export `ANTHROPIC_API_KEY` into Copilot BYOK. That console key is
credit-dead. Claude Code Review may still use `CLAUDE_CODE_OAUTH_TOKEN`.

Copilot cloud agent reads Agents secrets as env vars, then
`.github/workflows/copilot-setup-steps.yml` runs
`scripts/fleet-inference-select.sh` and exports `COPILOT_PROVIDER_BASE_URL`,
`COPILOT_PROVIDER_API_KEY`, `COPILOT_PROVIDER_TYPE`, and `COPILOT_MODEL`.

Health canary: `.github/workflows/inference-canary.yml` →
`scripts/fleet-inference-canary.sh`. Missing secrets are SKIP. Present-but-broken
secrets fail that rung and the selector continues. Preferred provider = first
healthy entry.

Local Mac Copilot CLI uses a separate OAuth-proxy chain (`llm-degrade`); this
file is the GitHub-runner contract.
