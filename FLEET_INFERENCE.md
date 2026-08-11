# Fleet inference preference

Thomas (2026-08-11): when choosing an LLM provider for automation, agents, or
canaries, prefer this order:

1. **Grok** — `XAI_API_KEY` (api.x.ai)
2. **Gemini** — `GEMINI_API_KEY`
3. **Kimi** — `MOONSHOT_API_KEY`
4. **OpenAI** — `OPENAI_API_KEY`
5. **Anthropic** — `ANTHROPIC_API_KEY` / `CLAUDE_CODE_OAUTH_TOKEN`

Health check: `.github/workflows/inference-canary.yml` → `scripts/fleet-inference-canary.sh`.
Missing secrets are SKIP; present-but-broken secrets fail the canary.
Preferred provider = first healthy entry in the list above.
