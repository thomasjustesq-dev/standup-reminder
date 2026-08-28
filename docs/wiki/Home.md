# Stand Up Reminder internal wiki

Stand Up Reminder is a movement-break companion: a macOS 14+ menu bar app, an iPhone app, and an Apple Watch companion on one shared scheduler core. It reminds Thomas to stand, stretch, and take lunch/wind-down breaks without fighting meetings, Focus, or a locked screen. It is a single-user wellness tool, not a team product and not a fitness tracker.

This wiki is the internal handbook. It orients operators and agents. It does not replace `README.md`, `CLAUDE.md`, `docs/ROADMAP.md`, or a decision in `docs/DECISIONS.md`. If this page and a governing document disagree, the governing document wins.

Living checkout: [`https://github.com/thomasjustesq-dev/standup-reminder`](https://github.com/thomasjustesq-dev/standup-reminder). Canonical disk path: `/Volumes/Crucial X8/GitHub/standup-reminder`. This handbook was refreshed for v4.2.4 on 2026-08-27.

## Current posture, in one paragraph

Product is **v4.2.4 (build 10)**. The GitHub release is signed, notarized, stapled, and universal for Intel and Apple Silicon; the Homebrew Cask points at its verified zip. Settings/profile sync is automatic, Quiet Apps provides frontmost-app reminder suppression, and the iPhone target has real HealthKit workout reads and mindful-session writes. Identity is locked to `com.thomasjust.standupreminder` (App Group and iCloud container match). The phone honors Mac presence and next-fire only while the runtime stamp is ≤15 minutes old; otherwise it runs a full local schedule and shows “Mac offline · local schedule.”

Read [Current status](Current-Status.md) before doing work. Read [Traps](Traps.md) before touching the menu bar extra, codesign, or bundle IDs.

## How to use this wiki

If you are an agent opening the repo for the first time, start at [Start here](Start-Here.md). If you are about to change scheduling, sync, or identity, read [Operating rules](Operating-Rules.md) and [Architecture](Architecture.md). If you are shipping, read `docs/DISTRIBUTION.md` and `NEXT.md` — then verify them against GitHub Releases, because those files lag.

Canonical copy: [`docs/wiki/`](https://github.com/thomasjustesq-dev/standup-reminder/tree/main/docs/wiki). The GitHub Wiki tab is the same handbook once initialized. GitHub does not create `standup-reminder.wiki.git` until a logged-in user clicks “Create the first page” once; after that, `scripts/publish_wiki.sh` pushes this tree. Do not let a wiki page become a second living spec.

## Document authority

1. `README.md` — product truth (features, identity, platforms).
2. `CLAUDE.md` — agent contract. `AGENTS.md`, `GEMINI.md`, `.cursorrules`, and `.github/copilot-instructions.md` are thin redirects; do not copy rules into them.
3. `docs/ROADMAP.md` — sequence. `docs/ASSIGNMENT.md` is the self-serve menu only when concurrent agents return; it is empty by design in solo mode.
4. `docs/DECISIONS.md` — append-only product and process decisions.
5. `NEXT.md` and `docs/DISTRIBUTION.md` — ship checklist. Treat as operational notes, not as newer than GitHub Releases.
6. This wiki — orientation.

## Identity (do not invent new values)

| Surface | Value |
| --- | --- |
| Bundle ID (Mac / iOS) | `com.thomasjust.standupreminder` |
| App Group | `group.com.thomasjust.standupreminder` |
| iCloud container | `iCloud.com.thomasjust.standupreminder` |
| Application Support | `~/Library/Application Support/StandUpReminder/` |

The Application Support folder name is **not** derived from the bundle ID. Local config survives a reverse-DNS rename. After the old `com.user.*` / `iCloud.com.user.*` identifiers, enable sync on one device to seed the new container automatically.

## What this wiki is not

It is not a claim on a worktree. It is not permission to revive claim-first. It is not a second ROADMAP. It is not a place to store Developer ID passwords, `.p12` bytes, notary credentials, or HealthKit payloads.
