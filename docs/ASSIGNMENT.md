# Daily assignment card

**Authority:** this file is the only self-serve menu. `ROADMAP.md` sequences
product; this file answers *who works today*.

If every continuous slot is **empty**, agents may only:

1. Babysit **their own** open PRs.
2. Merge green **claims-only** bot PRs.
3. Take a Task ID from the **standing maintenance menu**.
4. Ask Thomas.

**Do not self-select** from ROADMAP when this card is empty.

**Solo human mode (default):** Thomas is the only author. Ignore agent slots.
Open a normal product branch/PR; leave this card empty. The claim package is
**dormant** until multi-agent concurrency returns — see PROCESS_LESSONS
“What this repo should not adopt.”

## Current assignments

**Card date:** 2026-08-26 · **mode: solo / dormant claims**

Pinned to `origin/main` `14aad14` (PR #21). LIVE_CLAIMS is empty.

| Slot | Owner | Task ID | Claim on main? | Work PR | Notes |
| --- | --- | --- | --- | --- | --- |
| Continuous — Grok | | | | | dormant. Menubar icon #21 merged 2026-08-15; wiki #23 merged 2026-08-25. Do not revive claim-first. |
| Continuous — Codex | | | | | dormant |
| Continuous — Kimi | | | | | dormant |
| On-demand — Claude | | | | | dormant |
| Human — Thomas | | | n/a | n/a | Product PRs without claim tax. Wiki tab first page then `scripts/publish_wiki.sh`. |

## Standing maintenance menu

| Task ID | Allowed write surface | Notes |
| --- | --- | --- |
| `process/claim-archive` | `docs/claims/` | Archive closed claims |
| `process/live-claims-fresh` | `docs/LIVE_CLAIMS.md` | Regenerate index |
| `process/bot-pr-babysit` | none | Merge green claims-only PRs |

## Related

- [`LIVE_CLAIMS.md`](LIVE_CLAIMS.md)
- [`WORKBOARD.md`](WORKBOARD.md)
