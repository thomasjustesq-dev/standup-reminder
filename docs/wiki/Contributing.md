# Contributing

This is a single-user Swift app. Correctness includes schedule cadence, identity, iCloud merge, and the authority lease — not only “it compiles.”

## Solo (default)

1. Read [Start here](Start-Here.md) and [Current status](Current-Status.md).
2. Open a feature branch from `origin/main`. Worktrees belong under `/Volumes/Crucial X8/GitHub/standup-reminder-worktrees/`.
3. Implement. Keep the PR small.
4. Run `scripts/check-core-purity.sh`, `scripts/check-version-agree.sh`, and `swift test`.
5. Open a PR against `main`. Do not push `main`.

Skip claim-first and write-surface unless `docs/ASSIGNMENT.md` is explicitly filled for multi-agent. Do not steal an active claim if concurrent agents return.

## Multi-agent (dormant)

Full protocol: `docs/WORKBOARD.md`. Land the claim on `main` **before** implementation (`scripts/claim-open.sh`). Write surfaces must match the diff. Exclusive hot spots: `Sources/`, `Tests/`, `docs/`, `scripts/`. Append-only union merge on `docs/DECISIONS.md`, `docs/SESSION_LOG.md`, `docs/OPEN_QUESTIONS.md`.

## Pull requests

Explain what changed and why; identity / sync / lease implications if any; tests run; what you did not do.

Do not commit secrets, `.p12` files, notary passwords, Health exports, or webcam frames. Do not add `runs-on: self-hosted`. Do not copy `CLAUDE.md` rules into `AGENTS.md` / `GEMINI.md` / `.cursorrules`.

Label path classes (`claims-only`, `docs-process`) are applied by `scripts/classify-paths.sh`. Docs/process is the right bucket for this handbook.

## Version and ship

```bash
./scripts/bump-version.sh 4.2.2 8
./scripts/check-release-readiness.sh
```

Tag `v<ver>` only when Info.plist agrees and release secrets are actually present. After a zip exists, keep `Casks/standup-reminder.rb` `sha256` in lockstep. Sparkle appcast stays a template until Sparkle is linked in a distribution build.

First multi-device install after an identity change: **Push to iCloud once**.

## Wiki maintenance

Edit `docs/wiki/` on a branch. After the Wiki tab exists, run `scripts/publish_wiki.sh` so `_Sidebar.md`, `_Footer.md`, and the page files land on `standup-reminder.wiki.git`. Do not let the Wiki tab drift from `docs/wiki/`. Do not put secrets or `.p12` material in wiki pages. Pin a `main` SHA in Home when you refresh status.

In-repo `docs/wiki/README.md` is the GitHub-tree index; it is **not** published (the script skips it). GitHub Wiki’s home page is `Home.md`.

## Coordination

Read `Projects/Claude Code/_Live.md` and the standup-reminder briefing before writing. Register your glob. A live-board row is not a substitute for a claim if claims are revived. Do not put repo/dev state in `Claude Memory/Session Context.md`.
