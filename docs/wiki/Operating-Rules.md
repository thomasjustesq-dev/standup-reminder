# Operating rules

Short form of `CLAUDE.md` plus the product invariants that actually change code. `AGENTS.md`, `GEMINI.md`, `.cursorrules`, and `.github/copilot-instructions.md` redirect here. Do not copy this file into them.

## Authority

1. Product truth lives in `README.md` and `docs/`.
2. Sequencing: `docs/ROADMAP.md`. In solo mode, self-select from it. In multi-agent mode, implement only the `docs/ASSIGNMENT.md` row.
3. Coordination: `docs/WORKBOARD.md`. Do not invent process.
4. Ambiguity: append `docs/OPEN_QUESTIONS.md` and take the conservative reading.

A decision in `docs/DECISIONS.md` supersedes README/CLAUDE where it names the change.

## Coordination (dormant)

Claim-first, ASSIGNMENT slots, and write-surface tax stay in the tree and are **not required** at a fleet of one. Do not open claims, fill ASSIGNMENT, or expand process CI unless concurrent agents return. Failures that justified the package: `docs/PROCESS_LESSONS.md`. Revive protocol: `docs/WORKBOARD.md`.

Solo session: feature branch → implement → PR. Never push `main`. Append SESSION_LOG / OPEN_QUESTIONS / DECISIONS as needed (`merge=union`).

## Product invariants

1. **Do not invent identity.** Bundle ID, App Group, and iCloud container are `com.thomasjust.standupreminder` and the matching `group.` / `iCloud.` strings. Widgets and Watch only append the suffixes already in `AppIdentity`.
2. **Application Support is `StandUpReminder/`.** Not derived from the bundle ID. Do not “fix” that to match reverse-DNS.
3. **Authority lease TTL is 15 minutes.** Followers honor Mac presence/next-fire only while `runtime.json` `updatedAt` is fresh. Stale meeting presence must not silence the phone. The constant is enough; do not add a config UI for it unless a decision says so.
4. **Mac is the quiet-rule primary.** iOS schedules notifications. Do not pretend the phone can see Calendar / Focus / idle / deep work in the background.
5. **Core purity.** `StandUpReminderCore` stays free of AppKit/UIKit/WatchKit/AVFoundation/EventKit/ServiceManagement. If a change needs those, it does not belong in core.
6. **Newest-wins runtime, not a CRDT.** JSON-over-iCloud cannot be a live lease without TTL. `RuntimeMerge` already clears snooze/skip when the newer doc has no active value. Do not invent vector clocks.
7. **Corrupt config is preserved.** Failed decode → `*.corrupt` + in-memory defaults. Do not overwrite a bad file with a silent default write.
8. **Diagnostics stay local** unless a validated HTTPS public-host endpoint is set.
9. **Webcam stillness is on-device.** Face boxes only. Never upload frames.
10. **HealthKit is read-only and optional.** A workout that just ended may count as the movement break. Fighting Shape cadence tightening is off by default.

## Menu bar and signing

Do not wrap the `MenuBarExtra` label in an `HStack` or any container — macOS 14+ renders that extra blank. Prefer a template `NSStatusItem` (PR #21). Do not `codesign --deep` an installed bundle that embeds the widget.

## Commands

```bash
scripts/status.sh
scripts/check-core-purity.sh
scripts/check-version-agree.sh
scripts/check-release-readiness.sh
swift test
```

Hosted CI only (`ubuntu-*`, `macos-*`, `windows-*`). Never `runs-on: self-hosted`. Do not register the iMac or MacBook as a runner.

## Version and release

Bump with `scripts/bump-version.sh`. Do not hand-edit one plist and leave `AppVersion` stale. Tag `v*` triggers `.github/workflows/release.yml`. Do not push a tag whose marketing version disagrees with `Resources/Info.plist`.

## Fleet inference

Grok → Codex → Kimi → Gemini, then native GitHub Copilot. Repository secrets and `COPILOT_PROVIDER_*`. Do not call GitHub-hosted models while a BYOK key is healthy. Do not export `ANTHROPIC_API_KEY` for Copilot BYOK. See `FLEET_INFERENCE.md`.

## Style

Small, reviewable PRs. Boring Swift over clever. Tests before features on scheduler, lease, merge, and fire gates. Do not put repo/dev state in `Claude Memory/Session Context.md` — that is a vault rule, not this repo’s.
