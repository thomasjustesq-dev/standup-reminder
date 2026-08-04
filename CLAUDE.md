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

## Multi-agent coordination (PENUMBRA lessons, scaled)

- **Claim-first:** land a claim on `main` before product work
  (`scripts/claim-open.sh`).
- **ASSIGNMENT.md** is the only self-serve menu. Empty slot = not available.
- **Write surfaces:** declare paths; do not overlap live claims.
- **One live claim per tool.**
- Empty slot: babysit your own PRs, merge green claims-only bot PRs, take a
  standing maintenance Task ID, or ask Thomas.

Full protocol: `docs/WORKBOARD.md`. Failures: `docs/PROCESS_LESSONS.md`.

## Commands

```bash
scripts/status.sh
scripts/claim-open.sh --tool Grok --task process/example --slug example --surface none
scripts/coordination-guard.sh
scripts/archive-merged-claims.sh --apply
```

## Session protocol

1. Read `docs/ASSIGNMENT.md` and `docs/LIVE_CLAIMS.md`.
2. Claim-first if starting product work.
3. Stay inside the declared write surface.
4. Append SESSION_LOG / OPEN_QUESTIONS / DECISIONS as needed.
5. Never push directly to `main`.

## Style

- Prefer small, reviewable PRs.
- Do not self-select ROADMAP items when ASSIGNMENT is empty.
