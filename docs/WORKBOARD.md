            # Workboard — agent coordination protocol

            Entry point for multi-agent coordination on **Standup Reminder**. Live claim state lives
            in one file per claim under `docs/claims/`.

            Lessons: [`PROCESS_LESSONS.md`](PROCESS_LESSONS.md). Scaled from PENUMBRA via
            OVERLAND / Child-Support-Calculator (2026-08-04).

            ## Reading order at session start

            1. This file.
            2. [`ASSIGNMENT.md`](ASSIGNMENT.md) — empty slot means do not self-select.
            3. [`LIVE_CLAIMS.md`](LIVE_CLAIMS.md).
            4. `gh pr list` for your tool.
            5. [`ROADMAP.md`](ROADMAP.md) § "What to work on next".

            ## Claim-first

            Land the claim on the default branch **before** implementation:

            1. Branch `agent/{tool}/task-{slug}`.
            2. Claim file + ASSIGNMENT row (`Status: Active`, `Pull Request: none`).
            3. Claim-only PR; auto-merge when green.
            4. Implement; open work PR; set claim to `PR Open`.

            `scripts/claim-open.sh` does registration in one step.

            **Why:** a claim only on your topic branch is invisible to every other agent.

            ## Fast paths

            | Class | Paths | Label | CI | Merge |
            | --- | --- | --- | --- | --- |
            | Registry | `docs/claims/**`, `LIVE_CLAIMS`, `ASSIGNMENT` | `claims-only` | guard | squash auto-merge |
            | Docs/process | `docs/**`, `.github/**`, `scripts/**`, `*.md` | `docs-process` | guard | squash auto-merge |
            | Product | everything else | none | full suite (if any) | rebase manual |

            Classifier: `scripts/classify-paths.sh`.

            ## Write surface

            Every claim declares paths it will write, or `none` for read-only.
            Whole-tree roots alone are forbidden as a sole surface.
            `scripts/check-write-surface.sh` enforces the lease on `agent/*` branches.

            ## Conflict hot spots

            | Surface | Why | Lease |
            | --- | --- | --- |
            | `Sources/` | Shared product surface | Prefer one live claim |
| `Tests/` | Shared product surface | Prefer one live claim |
| `docs/` | Shared product surface | Prefer one live claim |
| `scripts/` | Shared product surface | Prefer one live claim |
            | `docs/DECISIONS.md`, `SESSION_LOG.md`, `OPEN_QUESTIONS.md` | Append-only | Union merge |
            | `.github/workflows/`, coordination scripts | Process | One process claim |

            ## Union-merged logs

            `.gitattributes` carries `merge=union` for DECISIONS, SESSION_LOG, OPEN_QUESTIONS.

            ## Merge cadence

            1. Serial landing when product PRs share a hot spot.
            2. Named merge-wave owner when multiple product PRs must land together.
            3. Own-PR babysit only by default.
            4. Prefer `strict: false` on required status checks.

            ## Branch naming

            - `agent/{tool}/task-{slug}` for product and maintenance
            - `process/{slug}` for foundation process PRs (no claim required)

            ## Related

            - [`../CLAUDE.md`](../CLAUDE.md)
            - [`ASSIGNMENT.md`](ASSIGNMENT.md)
            - [`PROCESS_LESSONS.md`](PROCESS_LESSONS.md)
