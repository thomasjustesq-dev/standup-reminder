# Traps

Durable traps from the repo briefing, `docs/SESSION_LOG.md`, and this SHA. If you learn a new one, write it here and on `Projects/Claude Code/standup-reminder.md`.

## `MenuBarExtra` + `HStack` is blank

On macOS 14+, a `MenuBarExtra` label that wraps the SF Symbol / countdown `Text` in an `HStack` (or any container) renders an empty extra. Finder app icon stays fine, which makes the bug look like a template-image / asset problem. It is not. Do not regress the stretching-figure `NSStatusItem` merged in PR #21.

## `codesign --deep` kills the widget

`--deep` re-signs the embedded widget with the **app** entitlements. Launch fails POSIX 162. `scripts/build-app.sh` and `scripts/notarize.sh` on this SHA still pass `--deep` for ad-hoc / Developer ID signing of a *build product* — do not run that against `~/Applications/StandUpReminder.app` as a repair, and do not add `--deep` to a “just get it launching” loop.

## Do not invent bundle IDs

Identity is `com.thomasjust.standupreminder` everywhere. Split `com.user` vs `com.thomasjust` already broke App Groups and provisioning once. After any rename, enable sync so automatic seeding populates the new iCloud container. Application Support stays `~/Library/Application Support/StandUpReminder/` so local config survives the DNS change.

## Stale Mac must not silence the phone

JSON-over-iCloud is not a live lease. Without the 15-minute TTL, a Mac that died in a meeting keeps the phone quiet forever. Do not “fix” offline behavior by making the follower honor a stale `runtime.json`. Degraded mode is “Mac offline · local schedule,” a full local queue.

## No Mac↔Watch

WatchConnectivity is iPhone↔Watch. Wiring a Mac Watch bridge will not pair. Mac state reaches the Watch only as iCloud → iPhone → Watch.

## iOS quiet-rule honesty

The phone cannot observe meetings, Focus, idle, display sleep, or deep work in the background. Copy and architecture already say Mac is the suppressor. Do not add iOS EventKit / Focus polling that pretends otherwise.

## Leftover tree `standup-reminder-fix`

A distinct leftover checkout is mentioned in the 2026-08-01 consolidation notes (HEAD `96f0697` vs this repo `6accc5c` at the time). Do not merge them blindly.

## Claim-first looks live and is not

`docs/WORKBOARD.md` and `scripts/claim-open.sh` describe claim-on-main-first. ASSIGNMENT is empty; live claims are none; `CLAUDE.md` says dormant. Opening a claim to “do it right” is stealing a process Thomas parked. Solo: normal branch + PR.

## Core imports will fail CI

A convenience `import AppKit` in `StandUpReminderCore` fails `scripts/check-core-purity.sh`. Put the type in the Mac target (`Sources/StandUpReminder/`) or keep the API Foundation-only.

## Version skew

Marketing version lives in `AppVersion`, Info.plist, `project.yml`, Formula, and Cask. Hand-editing one of them makes `check-version-agree.sh` and the tag-triggered release workflow fail. Use `scripts/bump-version.sh`.

## Corrupt config overwrite

A config or profiles file that fails to decode is renamed `*.corrupt` and the app runs on defaults. A “helpful” save of those defaults wipes the user’s file. Nested structs decode per-field so one new flag cannot fail the whole document — keep it that way.

## Diagnostics POST is a privacy footgun

Empty endpoint means AppLog only. Do not default-on a telemetry URL. `DiagnosticsURL` already requires HTTPS and a public host.

## Webcam frames never leave the Mac

Stillness samples one frame every 3 s, face boxes on-device. Any upload path is a product bug.

## Fleet order drifted in old notes

Current order is Grok → Codex → Kimi → Gemini, then Copilot. Older CLAUDE copies said Grok → Gemini → Kimi → OpenAI → Anthropic. Do not restore Anthropic BYOK; that console key is credit-dead.

## Do not bundle a two-line fix into a process overhaul

`docs/PROCESS_LESSONS.md` (from PENUMBRA): a small verified fix that rides with a contested 26-file change dies when the overhaul is rejected. Wiki, purity, and menubar fixes stay on their own PRs.
