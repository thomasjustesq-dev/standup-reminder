# Stand Up Reminder · v4.2.2

Movement-break companion: macOS menu bar app (macOS 14+), iPhone app, and
Apple Watch companion on one shared scheduler core.

The internal operator and agent handbook is [`docs/wiki/`](docs/wiki/README.md),
also published on the GitHub [Wiki](https://github.com/thomasjustesq-dev/standup-reminder/wiki).
It orients; it does not replace this README, `CLAUDE.md`, or `docs/DECISIONS.md`.

## Identity (single root)

| Surface | Value |
| --- | --- |
| Bundle ID (Mac / iOS) | `com.thomasjust.standupreminder` |
| App Group | `group.com.thomasjust.standupreminder` |
| iCloud container | `iCloud.com.thomasjust.standupreminder` |
| Marketing version | `4.2.2` (see `AppVersion` in `Sources/StandUpReminderCore/AppIdentity.swift`) |

Application Support remains `~/Library/Application Support/StandUpReminder/` so local
config survives a bundle-id change. After upgrading from the old `com.user.*` /
`iCloud.com.user.*` identifiers, **push once from any device** to re-seed the new
iCloud container. Enable the matching App ID capabilities in the Apple Developer
portal (App Groups + iCloud Documents) for automatic signing.

## What’s new in v4.2.2

- **Authority lease** — phone honors Mac presence/next-fire only while the
  runtime stamp is ≤15 minutes old; otherwise it runs a full local schedule and
  shows “Mac offline · local schedule” (no more permanent silence from a stale
  meeting gate).
- **Seed iCloud banner** — empty container after identity rename surfaces a
  one-time push prompt on Mac menu and iPhone home.
- **`diagnostics` CLI** — one pasteable dump: version, presence, lease, sync
  doctor, block stats, corrupt artifacts.
- **PhoneModel split** — Cloud / Scheduling / Persistence extensions for
  maintainability. CI already builds iOS + Watch via xcodegen.

## What’s new in v4.2

- **Settings can no longer be silently wiped** — a config or profiles file
  that fails to decode is preserved as `*.corrupt` and the app runs on
  in-memory defaults; every nested config struct decodes per-field, so a
  flag added in an update can't fail the whole document. Numeric fields
  clamp to sane ranges on load/import.
- **Notifications you can trust** — denied authorization is detected and
  surfaced (menu warning + System Settings shortcut) instead of chiming
  with no banner; Focus/DND suppresses sound and voice too; time-sensitive
  and focus-status entitlements are actually declared; clicking a banner
  opens the guided break (previously a no-op); stale banners are cleared.
- **Smarter quiet rules** — meeting catch-up and wind-down defer around a
  locked screen, sleeping display, off-hours, or empty desk instead of
  discarding or barging through; deep-work suppression is bounded at 2×
  your interval; returning from an away stretch credits the break; break
  and sit/stand reminders won't double-fire right after lunch/wind-down.
- **iOS reminders that don't silently stop** — background app refresh
  refills the pre-scheduled queue, overdue entries fire instead of mapping
  to past dates, delivered-notification stats reconcile correctly, and a
  sentinel notification makes queue exhaustion visible.
- **One schedule across devices** — with iCloud sync on, Done/Snooze/Skip
  on any device re-anchors every device (newest-wins runtime doc), stats
  merge across devices for the weekly line, and sync itself is stamped and
  refuses to clobber newer local state. iOS finally ships the entitlements
  this needed.
- **Glanceables** — Lock Screen widgets, a Watch complication, and a Live
  Activity countdown (Dynamic Island included), all with live timers.
- **Health-aware** — optional read-only HealthKit: a workout that just
  ended counts as your movement break. Optional Fighting Shape hook
  tightens cadence on low-recovery days (off by default).
- **Weather that knows where you are** — persisted CoreLocation fix or
  explicit `weatherLatitude`/`weatherLongitude` config, not a timezone
  city table that reported Chicago for all of US Central.
- CLI test commands run inside the running app; `icloud-push`/`icloud-pull`
  report real outcomes and exit nonzero on failure.

## What’s new in v4.1

- **Correct break cadence** — reminders fire N minutes after your last break
  (v4.0 fired on wall-clock minute boundaries, which produced uneven gaps and
  could remind you a minute after you finished a break).
- **CLI actually talks to the running app** — `enable`, `disable`, `profile`,
  `pack`, and `import` now take effect immediately instead of after relaunch.
- **iCloud pull fixed** — one JSON date format across every store, with
  migration for v4.0 files.
- **Honest audio** — one notification sound (your configured one), voice
  announcements off by default, and "headphones only" checks the real output
  device via CoreAudio.
- **Lighter footprint** — webcam stillness samples one frame every 3 s instead
  of every frame; state files are written only when something changed; the log
  rotates at 512 KB.
- **Local weather** — uses your approximate location when you allow it
  (falls back to a time-zone estimate).
- Unit tests + GitHub Actions CI, MIT license.
- **iOS + Apple Watch apps** — the same scheduler core now drives an iPhone
  app (pre-scheduled local notifications with Done / Snooze / Skip actions)
  and a paired Watch companion (status, countdown, haptic actions).

## Features (v4)

| Feature | Notes |
| --- | --- |
| **iCloud sync** | Opt-in push/pull of settings + profiles |
| **Team quiet hours** | JSON feed for all-hands / focus blocks; refreshes every 6 h |
| **Voice chimes** | Spoken reminders, off by default (optional headphones-only) |
| **Learned schedule** | Infers start/end from activity; apply when ready |
| **Webcam stillness** | On-device face boxes only — never uploaded |
| **Weather tips** | Open-Meteo outdoor-walk suggestions |
| **Sample-day tour** | 9→5 walkthrough on first launch |
| **Accessibility** | Labels, Reduce Motion respect |
| **Diagnostics** | Opt-in crash breadcrumbs + optional POST endpoint |

Plus everything from v3: sit/stand, packs, adaptive interval, meeting catch-up, guided breaks, profiles, export/import, Health, denylist, deep work.

When iCloud sync is enabled, settings and profiles push immediately after local changes and reconcile automatically at launch, on foreground, during background refresh on iPhone, and every minute while the Mac app is running. Manual Push/Pull controls remain available for diagnostics.

The app denylist is a quiet-app list, not a launch blocklist: reminder banners are suppressed while a listed application is frontmost. Entries are normalized and matched case-insensitively; the Mac settings UI can add the previously frontmost app without requiring a bundle identifier.

Apple Health is connected on iPhone. With Health enabled, recent workouts count as completed movement breaks and tapping Done writes the configured mindful-session duration. The Mac reports Health as unavailable on hardware where `HKHealthStore` is unavailable instead of showing a false success state.

## Platforms

One shared core (`Sources/StandUpReminderCore`: config, scheduler, stats,
profiles, iCloud sync, notifications) drives three apps:

| App | How it reminds | Build |
| --- | --- | --- |
| **macOS menu bar** | 15 s tick loop; meeting/focus/idle/deep-work suppression | `swift build` or Xcode project |
| **iOS** | Pre-schedules the next 24 reminders as local notifications (`Scheduler.upcoming`); rebuilds the queue on interaction, foreground, and background app refresh; Lock Screen widget + Live Activity | Xcode project |
| **watchOS** | Companion to the iPhone app: status, live countdown, Done / Snooze / Skip with haptics, complication; iOS notifications also mirror to the Watch automatically | Embedded in the iOS app |

Architecture note: an Apple Watch pairs only with an iPhone — there is no
Mac↔Watch channel — so the Watch talks to the iOS app via WatchConnectivity
and the Mac participates through iCloud settings sync.

```bash
xcodegen generate                                    # brew install xcodegen
xcodebuild -scheme StandUpReminderiOS \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Device installs and App Store distribution need your Apple Developer team set
as the signing team in Xcode; the iOS/Watch/widget targets declare iCloud,
App Group, HealthKit, and time-sensitive-notification entitlements, so the
matching capabilities must be enabled on the App ID (automatic signing
normally handles this — if signing fails, remove the offending key from the
entitlements file). iOS limitations vs. the Mac app: no meeting / focus /
idle / deep-work suppression (the app cannot observe those in the
background). Background app refresh tops the queue up opportunistically, but
iOS decides when it runs — the sentinel notification covers the gap.

### Roadmap / not wired up yet

- **Reviewed:** 2026-07-30
- [ ] **Sparkle appcast** — template only (`docs/appcast.xml`); the app uses the
  GitHub releases checker unless Sparkle is linked in a distribution build.
- [ ] **MAS / Homebrew** — entitlements and cask/formula files are templates.

## Install

See **[QUICKSTART.md](QUICKSTART.md)** for the shortest path.

```bash
chmod +x scripts/*.sh
./scripts/install.sh
```

Pause / resume anytime from the menu bar, or:

```bash
standup-reminder pause
standup-reminder resume
standup-reminder status
```

See [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md) for notarization, Sparkle, Mac App Store, Setapp, and Homebrew Cask.

## Settings → Sync & Privacy

Configure iCloud, team quiet feed (`docs/team-quiet-hours.example.json`), voice, Watch, learning, camera stillness, weather, Sparkle, and diagnostics.

## CLI extras

```bash
standup-reminder icloud-push
standup-reminder icloud-pull
standup-reminder weather
standup-reminder learn-apply
```

## Uninstall

```bash
./scripts/uninstall.sh
```

## Debug tooling

A set of read-only debug commands and an in-app debug panel are available in debug builds to help introspect the scheduler, config, and runtime state.

### CLI debug commands

These sub-commands print diagnostic output and exit — they do **not** modify any state.

```bash
standup-reminder debug-trace      # Rule evaluation trace: which rules are active and what fires next
standup-reminder debug-snapshot   # Upcoming schedule as a JSON array (next 10 reminders)
standup-reminder debug-check      # Determinism check: evaluates the schedule twice and compares
standup-reminder debug-config     # Active AppConfig serialised as JSON
```

### In-app debug panel

Launch the app with the `--debug` argument to surface the debug panel at startup and add a **Debug Panel…** menu item to the menu bar:

```bash
.build/debug/StandUpReminder --debug
```

The panel shows:
- **Active Rules** — which scheduling rules are currently enabled, the cadence anchor, and the next scheduled reminder
- **Runtime State** — paused/snoozing/skip-today flags, effective interval, active profile, and notification authorization status
- **Upcoming Schedule** — next 20 reminders as formatted JSON

> **Gate**: the panel and its menu item are compiled only in `#if DEBUG` builds and are additionally guarded by the `--debug` launch argument. They are unreachable in release builds.

## Development

```bash
swift build        # debug build
swift test         # unit tests (scheduler, engine logic, JSON migration)
```

CI runs both on every push and pull request.

## License

MIT — see [LICENSE](LICENSE).

## Agent coordination

Multi-agent work uses claim-first process docs: [`CLAUDE.md`](CLAUDE.md), [`docs/WORKBOARD.md`](docs/WORKBOARD.md), [`docs/ASSIGNMENT.md`](docs/ASSIGNMENT.md).
