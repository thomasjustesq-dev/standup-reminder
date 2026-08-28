# Session log

Append-only. `merge=union`.

---

## 2026-08-27 — Aero-Kinetic fidelity pass (implementation plan)

- Popover hero now renders the stretching figure (new `AeroStretchFigure`
  SwiftUI glyph matching `MenuBarMark` geometry) inside the Volt arc, in Volt
  color with glow, via `AeroCountdownGauge(showsFigure:)`.
- `AeroAcoustics` chimes are true stereo: 2-channel PCM, base tone panned
  left / harmonic right, 6ms Haas delay on the right channel.
- Design tokens normalized to spec: specular rim 0.14, 0.5pt borders, card
  shadow .black 0.35 r24 y12, slate card fill 70%.
- Countdown timers track -0.5pt across Mac/iOS/widget/Watch/Live Activity.
- Watch dial arc now fills from the remaining-time fraction (iPhone pushes
  `intervalMinutes` over WatchConnectivity); dial ticks via TimelineView.
- Watch "Done" haptics are multi-tier (.notification then .success); snooze
  gets a .directionUp + .click pair.
- One shared token source: `StandUpReminderCore/AeroPalette.swift` (pure
  values, core-purity safe) consumed by Mac/iOS `AeroColor`, widget
  `AeroWidgetColor`, and the Watch view; project.yml adds the file to the
  Watch app and iOS/watchOS widget targets.
- Verified: `swift build` (macOS) clean, `check-core-purity.sh` OK,
  `swiftc -parse` clean on iOS/watchOS/widget files. iOS/watchOS xcodebuild
  not run — no Xcode on this machine (CLT only); `swift test` blocked by
  missing XCTest for the same reason.

---

## 2026-08-15 — Menu bar display icon was blank

- `MenuBarExtra` label used an `HStack` around the SF Symbol / countdown
  `Text`. That view type is not a valid status-item label on macOS 14+, so
  the extra rendered empty (Finder app icon was fine).
- Status item is now a template `Image` of the stretching-figure app mark
  (`MenuBarMark`). No HStack, no SF Symbol in the extra.

---

## 2026-08-04 — Process package land

- Installed scaled multi-agent coordination (claim-first, ASSIGNMENT, guard).
- Product code unchanged.
- Open questions: install `REPO_PAT` if auto-merge/reconcile desired.

## 2026-08-06 — Full review fixes (P0–P3)

- Fast-forwarded local main; identity unified to `com.thomasjust.standupreminder`.
- App Group on Mac app + widgets; iCloud container renamed.
- `RuntimeMerge` clears snooze/skip; `effectiveIntervalMinutes` on runtime doc for iOS.
- `FireGateEvaluator` + `DiagnosticsURL` HTTPS/public-host validation.
- Settings Sync tab progressive disclosure; packaging versions 4.2.1.
- Tests: merge, gates, diagnostics URL, corrupt config preserve, upcoming interval.

## 2026-08-06 — Improvement pass (paths, pause, UX, packaging)

- Injectable `Paths` temp support dir for tests; corrupt-config test isolated.
- Runtime pause sync; adaptive newest-wins + 5-min hysteresis; auto meeting-heavy pack opt-in.
- Guided break open modes; quieter feature defaults; Settings density + weekly review.
- Webcam burst sampling; widget minute timeline; iOS quiet-rule honesty copy.
- `scripts/bump-version.sh`, `check-core-purity.sh`, QUICKSTART multi-device checklist.
- Solo-author note on ASSIGNMENT; release checklist in DISTRIBUTION.

## 2026-08-06 — Sync health, doctor, intents, stand credit

- SyncHealth + menu/settings surface; force pull; legacy iCloud container migration.
- `sync-doctor` / `block-stats` CLI; quiet-rule block reason counters.
- Calendar title denylist; guided break focus steal guard; notif denied menu badge.
- Schedule profile rules; stand-hour soft credit; App Intents (log/snooze/pause/resume).
- `check-version-agree.sh` in CI; Mac/iPhone role labels.

## 2026-08-06 — Substantial upgrade: presence, authority, simulation, today UI

- `PresenceState` + resolver; fire gates presence-first; menu shows one state.
- Cadence authority/follower (automatic Mac=authority); runtime lease fields.
- `DaySimulation` pure day replay + tests; `AdaptiveCoach` explainable suggestions.
- Break evidence kinds (banner/away/stand/self); Today timeline window.
- iOS explicit follower role; shorter notification queue.

## 2026-08-06 — iOS respects authority nextFireAt / presence

- `FollowerSchedulePolicy`: drop break/sit-stand before Mac gate; suppress near
  breaks while authority presence is blocking (meeting/away/Focus/…).
- PhoneModel always pulls authority fields; status + UI show Mac presence/gate.
- BG/foreground reschedule rebuilds queue under policy.

## 2026-08-10 — Authority lease, PhoneModel split, process dormancy, 4.2.2

- `AuthorityLease` 15m TTL: followers honor Mac presence/gate only while runtime stamp is fresh; else local schedule + offline UI.
- `FollowerSchedulePolicy.applyAuthorityFilters` + `honorAuthority` flag; seed banner on empty iCloud (`SyncHealth.cloudContainerEmpty`).
- PhoneModel split: Cloud / Scheduling / Persistence extensions.
- CLI `diagnostics` full support dump; menu seed push actions.
- Process package marked dormant for solo; OPEN_QUESTIONS closed/deferred as appropriate.
- Version **4.2.2** (build 8). CI already builds iOS via xcodegen. Release still blocked on Apple portal + secrets.

## 2026-08-10 — Daily UX pass (phases 2–4)

- Suppression glance: Held line, top block, lease age on Mac menu + status/diagnostics.
- BlockStats persists last hold reason/at.
- iOS: notification Settings deep link, empty-queue classifier, lease line, BG refresh sync+reschedule.
- Guided break: userInitiated always activates; auto respects denylist/fullscreen (window still shown).
- Pure helpers: SuppressionStatus, EmptyQueueReason, GuidedBreakOpenPolicy + tests.

## 2026-08-10 — #10 + #11 on main

- Merged #10 (authority lease, PhoneModel split, diagnostics, App Shortcut CI fix).
- Merged #11 (suppression glance, iOS notif trust, guided userInitiated).
- main at 4.2.2 (8); 122 tests green; release blocked only on portal/secrets.

## 2026-08-10 — ship preflight + local install

- `check-release-readiness.sh` green for code; local `APPLE_*` notary env unset.
- GH secrets audit: ASC + Sparkle present; **missing** `APPLE_CERTIFICATES_P12` / password.
- Keychain: only Apple Development; Developer ID CSR+key in `~/.standup-release/`, no cert.
- Fixed `build-app.sh`: `-allowProvisioningUpdates`, team Automatic, stop ad-hoc re-sign wipe.
- Aligned `iOSWidget` / `WatchWidget` Info.plist to 4.2.2 (8); bump/check scripts cover them.
- Built + installed Development-signed 4.2.2 to `~/Applications`; diagnostics live, iCloud
  migrated 4 files from legacy container. Notarized tag ship still blocked on Developer ID.

## 2026-08-27 — automatic sync, Quiet Apps, real HealthKit

- Settings and profiles now push immediately and reconcile automatically on Mac tick, iPhone launch/foreground, and iPhone background refresh using a tested newest-wins policy.
- Replaced the raw denylist editor with a normalized, case-insensitive Quiet Apps list, readable names, removal controls, and Add Current App.
- Added explicit HealthKit authorization state. iPhone reads recent workouts and writes mindful sessions on Done; unsupported Macs report unavailable instead of implying access.
- Added the iOS Health update usage description and a release gate for signed HealthKit, iCloud, App Group, and widget capabilities.
