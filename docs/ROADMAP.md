# Roadmap — Standup Reminder

## What to work on next

**Only if your ASSIGNMENT row is filled.**

1. Read the Task ID on your card.
2. Claim-first, then implement inside the write surface.
3. Do not self-select when ASSIGNMENT is empty.

## Status

| Item | Status | Notes |
| --- | --- | --- |
| Multi-agent coordination package | **Done** | Landed 2026-08-04; **dormant at fleet of one** |
| Identity lock + runtime clear + adaptive sync | **Done** | Landed 2026-08-06 |
| Diagnostics HTTPS gate + fire-gate pure eval | **Done** | 2026-08-06 |
| Packaging version align (Formula/Cask) | **Done** | 4.2.2; Cask still needs a real notarized zip asset |
| Pause sync, path isolation, guided modes, weekly review | **Done** | 2026-08-06 improvement pass |
| Authority lease TTL + phone degradation | **Done** | 2026-08-10 · 15m TTL, local schedule when Mac offline |
| PhoneModel split + diagnostics dump CLI | **Done** | 2026-08-10 |
| First notarized GitHub release + Cask sha | **Next** | Needs Apple secrets + portal App Group/iCloud · `scripts/check-release-readiness.sh` |
| Next product work | **Later** | CloudKit / pedometer / Focus Filters only after ship |

## Related

- [`ASSIGNMENT.md`](ASSIGNMENT.md)
- [`WORKBOARD.md`](WORKBOARD.md)
