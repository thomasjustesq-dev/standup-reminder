# Standup Reminder

macOS menu bar standup / wellness reminder app.

## Who this applies to

**Every agent, not only Claude.** `AGENTS.md`, `GEMINI.md`, `.cursorrules` and
`.github/copilot-instructions.md` are thin redirects to this file. Do not copy
rules into those files — duplicated rules drift.

## Authority

1. Product truth lives in this repository's README and `docs/` (when present).
2. Sequencing: `docs/ROADMAP.md`. Implement only work on your
   `docs/ASSIGNMENT.md` row.
3. Coordination: `docs/WORKBOARD.md`. Do not invent process.

If something is ambiguous, append to `docs/OPEN_QUESTIONS.md` and implement the
most conservative reading.

## Coordination (dormant by default)

Multi-agent claim-first machinery exists under `docs/` and `scripts/` but is
**dormant at a fleet of one.** Do not open claims, fill ASSIGNMENT slots, or
expand process CI unless Thomas is running concurrent agents again.

Full protocol (when revived): `docs/WORKBOARD.md`. Failures: `docs/PROCESS_LESSONS.md`.

## Commands

```bash
scripts/status.sh
scripts/check-core-purity.sh
scripts/check-version-agree.sh
scripts/check-release-readiness.sh
swift test
# product: normal branch + PR; never push straight to main
```

## Session protocol

1. Read `docs/ROADMAP.md` for product sequence (solo mode).
2. Open a feature branch; implement; PR; do not push to `main`.
3. Append SESSION_LOG / OPEN_QUESTIONS / DECISIONS as needed.
4. Skip claim-first / write-surface unless ASSIGNMENT is explicitly filled for multi-agent.

## Style

- Prefer small, reviewable PRs.
- Solo: self-select from ROADMAP freely. Multi-agent: only ASSIGNMENT rows.

## Fleet inference preference

When selecting an LLM provider, prefer **Grok → Gemini → Kimi → OpenAI → Anthropic** (see `FLEET_INFERENCE.md`).

