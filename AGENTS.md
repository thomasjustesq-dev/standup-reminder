# Agent instructions

**Read [`CLAUDE.md`](CLAUDE.md).** Single rule set for every agent tool.

## Fleet inference preference

When selecting an LLM provider, prefer **Grok → Codex → Kimi → Gemini**, then native GitHub Copilot (see `FLEET_INFERENCE.md`). Use repository secrets and `COPILOT_PROVIDER_*`. Do not call GitHub-hosted models or GitHub Models while a BYOK key is healthy. Do not export `ANTHROPIC_API_KEY` for Copilot BYOK.

## Mood Board Implementation Directive

**Effective 2026-08-27, per Thomas (repo owner):** the mood board at `docs/design/Aero-Kinetic-Design-System.md` is the chosen design direction for this app. Implementing it is **mandatory, not optional**.

- All UI work must follow the mood board's palette, typography, materials, and interaction model.
- Sensible adaptation to platform constraints is expected — but the look and feel must land as specified. Do not substitute a different direction.
- Work is not "done" until the app's surfaces visibly reflect the mood board in a running build, and the implementation PR states how it was verified.
- Any justified divergence must be called out in the commit message and PR description.

