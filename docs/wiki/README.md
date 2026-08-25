# Stand Up Reminder internal wiki

In-repo copy of the internal handbook. After the GitHub Wiki tab has been clicked once (“Create the first page”), `scripts/publish_wiki.sh` publishes these pages to [the Wiki](https://github.com/thomasjustesq-dev/standup-reminder/wiki). GitHub will 404 that URL until that first click; this directory is the living copy either way.

Start at [Home](Home.md). Agents: [Start here](Start-Here.md).

| Page | Purpose |
| --- | --- |
| [Home](Home.md) | What the app is, document authority, how to navigate |
| [Start here](Start-Here.md) | First fifteen minutes for an agent |
| [Current status](Current-Status.md) | Operating posture as of the pinned SHA |
| [Architecture](Architecture.md) | Three apps, shared core, identity, sync |
| [Operating rules](Operating-Rules.md) | CLAUDE.md and product invariants |
| [Traps](Traps.md) | Known ways to break the app or the checkout |
| [Contributing](Contributing.md) | PR, wiki hygiene, release |

Canonical living documents remain `README.md`, `CLAUDE.md`, `docs/ROADMAP.md`, `docs/DECISIONS.md`, and `NEXT.md`. Snapshot: `origin/main` `9f8d5c4` (2026-08-19).
