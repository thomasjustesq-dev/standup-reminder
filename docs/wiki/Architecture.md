# Architecture

Stand Up Reminder is a Swift 5.9 / SwiftUI family on SPM (`Package.swift`) plus an Xcode project generated from `project.yml` (`xcodegen`) for iOS, watchOS, and widgets. One shared core computes schedule, config, stats, profiles, and iCloud envelopes. Three apps remind.

## Repository map

```text
Sources/StandUpReminderCore/   Platform-pure scheduler, config, sync, identity
Sources/StandUpReminder/       macOS menu bar app (AppKit + SwiftUI)
Sources/StandUpReminderiOS/    iPhone app + Health credit + Watch bridge
Sources/StandUpReminderWatch/  watchOS companion
Sources/StandUpReminderWidget/ Widgets / Live Activity / complication
Sources/DebugHarness/          Debug CLI + panel (DEBUG + `--debug`)
Tests/StandUpReminderTests/    Scheduler, lease, merge, gates, v4.2
Resources/                     Info.plist, entitlements, assets
scripts/                       Install, notarize, version, purity, claims
docs/                          Roadmap, decisions, distribution, process
docs/wiki/                     This handbook (also published to GitHub Wiki)
Casks/  Formula/               Homebrew packaging
legacy/                        Pre-Swift shell reminder; do not extend
```

## Three apps, one core

| App | How it reminds | Build |
| --- | --- | --- |
| **macOS menu bar** | 15 s tick loop; meeting / Focus / idle / deep-work / display-sleep suppression | `swift build` or Xcode |
| **iOS** | Pre-schedules the next reminders as local notifications (`Scheduler.upcoming`); rebuilds on interaction, foreground, and background app refresh; Lock Screen widget + Live Activity | xcodegen + `xcodebuild` |
| **watchOS** | Companion to the iPhone: status, countdown, Done / Snooze / Skip haptics, complication | Embedded in the iOS app |

An Apple Watch pairs only with an iPhone. There is no Mac↔Watch channel. WatchConnectivity is iPhone↔Watch. The Mac joins through iCloud documents (settings, profiles, runtime).

`Package.swift` compiles `StandUpReminder` + `StandUpReminderCore` + `DebugHarness` into the Mac executable and **excludes** iOS / Watch / widget sources. Core members stay `internal` across the Mac target. `scripts/check-core-purity.sh` fails if core imports AppKit / UIKit / WatchKit / AVFoundation / EventKit / ServiceManagement.

## Identity and paths

`AppIdentity` is the single reverse-DNS root: `com.thomasjust.standupreminder`. Widgets append `.widget`; Watch appends `.watchkitapp`. App Group is `group.` + root. iCloud container is `iCloud.` + root.

`Paths.appSupport` is `~/Library/Application Support/StandUpReminder/` on Mac (sandbox Library on iOS). Tests inject `Paths.useTemporarySupportDirectory`. Config that fails to decode is preserved as `*.corrupt`; the app runs on in-memory defaults. Nested config decodes per-field. Logs rotate at 512 KB under `~/Library/Logs/standup-reminder.log`.

## Cadence: authority, follower, lease

Quiet rules resolve to one `PresenceState`. Full-gated reminders fire only from `atDesk`. `CadenceRole.automatic` is Mac = authority, iOS = follower.

The Mac publishes presence and `nextFireAt` on `runtime.json` with `updatedAt`. `AuthorityLease` (15 minutes) decides whether a follower may honor that document. Dead lease → full local schedule + “Mac offline · local schedule.” `FollowerSchedulePolicy` drops break / sit-stand slots before the authority gate and while blocking presence is in the near window; lunch and wind-down are wall-clock social events and stay. Callers must pass `honorAuthority: false` when the lease is dead.

Runtime merge is newest-wins, not a CRDT. Snooze and skip-today clear when a newer remote doc has no active value. Pause travels on the runtime doc. Adaptive interval is newest-doc-wins with ≥5 minute hysteresis on local recompute.

## Mac tick vs iOS queue

On Mac, `AppState` evaluates `Scheduler.next` on a 15 s timer and fires when `Date()` reaches `Next.date`. Break cadence is anchored to the last reminder or acknowledgement — not wall-clock minute boundaries (that was the v4.0 bug).

On iOS, the app cannot sit in a tick loop. It materializes `Scheduler.upcoming` into local notifications, with a sentinel when the queue is exhausted. Background app refresh refills opportunistically; iOS decides when that runs. Overdue entries fire instead of mapping onto past dates.

`FireGateEvaluator` is the pure presence/gate function. Mac `AppState` feeds it live monitors (calendar, Focus, idle, display sleep, denylist, deep work). iOS does not run those monitors in the background.

## Sync

Opt-in iCloud Drive Documents (`CloudSync`), not CloudKit. Envelopes carry `updatedAt` + `deviceName` + payload. Pull refuses to clobber newer local state. Empty new container after the identity rename surfaces a one-time seed banner (`SyncHealth.cloudContainerEmpty`). Legacy container `iCloud.com.user.StandUpReminder` is migrated when the new folder is empty.

Team quiet hours are a JSON feed (`docs/team-quiet-hours.example.json`), refreshed every 6 h. Diagnostics POST only when a validated HTTPS public-host endpoint is set; empty endpoint is AppLog only.

## Version

One marketing / build pair: `AppVersion` in `Sources/StandUpReminderCore/AppIdentity.swift`, `Resources/Info.plist`, `project.yml`, Formula, and Cask. Bump with `scripts/bump-version.sh`. `scripts/check-version-agree.sh` is CI. A git tag that disagrees with Info.plist fails the release workflow.

## What is out of this architecture

CloudKit schema, Mac pedometer, Focus Filters entitlements — deferred. Sparkle is optional in distribution builds; SPM/debug uses the GitHub Releases checker. `legacy/` is the old shell + launchd reminder. Notebooks and Python do not exist here.
