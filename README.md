# Stand Up Reminder (macOS) · v4.1

Menu bar wellness companion for **iMac / MacBook / Mac Mini / Mac Studio** (macOS 14+).

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

### Roadmap / not wired up yet

These ship as templates or partial targets and are **not functional** in the
SwiftPM build of the Mac app:

- **Apple Watch bridge** — WatchConnectivity does not exist on macOS; the
  watchOS/iOS companion targets in `project.yml` are required and untested.
- **WidgetKit widget** — the widget target builds only via the Xcode project;
  the Mac app writes the shared snapshot either way.
- **Sparkle appcast** — template only (`docs/appcast.xml`); the app uses the
  GitHub releases checker unless Sparkle is linked in a distribution build.
- **MAS / Homebrew** — entitlements and cask/formula files are templates.

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

## Development

```bash
swift build        # debug build
swift test         # unit tests (scheduler, engine logic, JSON migration)
```

CI runs both on every push and pull request.

## License

MIT — see [LICENSE](LICENSE).
