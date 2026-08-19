# Agent instructions

**Read [`CLAUDE.md`](CLAUDE.md).** Single rule set for every agent tool.

## Fleet inference preference

When selecting an LLM provider, prefer **Grok → Codex → Kimi → Gemini**, then native GitHub Copilot (see `FLEET_INFERENCE.md`). Use repository secrets and `COPILOT_PROVIDER_*`. Do not call GitHub-hosted models or GitHub Models while a BYOK key is healthy. Do not export `ANTHROPIC_API_KEY` for Copilot BYOK.

