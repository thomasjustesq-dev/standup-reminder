# Stand Up Reminder (macOS) · v4

Menu bar wellness companion for **iMac / MacBook / Mac Mini / Mac Studio** (macOS 14+).

## What’s new in v4

| Feature | Notes |
| --- | --- |
| **iCloud sync** | Opt-in push/pull of settings + profiles |
| **Team quiet hours** | JSON feed for all-hands / focus blocks |
| **Voice chimes** | Spoken reminders (optional headphones-only) |
| **Apple Watch bridge** | Done / Snooze / Skip + haptics (watchOS target) |
| **Learned schedule** | Infers start/end from activity; apply when ready |
| **Webcam stillness** | On-device face boxes only — never uploaded |
| **Weather tips** | Open-Meteo outdoor-walk suggestions |
| **Sample-day tour** | 9→5 walkthrough on first launch |
| **Accessibility** | Labels, Reduce Motion respect |
| **Diagnostics** | Opt-in crash breadcrumbs + optional POST endpoint |
| **Sparkle appcast** | Template + Settings feed URL |
| **MAS / Cask** | Sandbox entitlements + Homebrew cask template |

Plus everything from v3: sit/stand, packs, adaptive interval, meeting catch-up, guided breaks, widget, profiles, export/import, Health, denylist, deep work.

## Install

```bash
cd standup-reminder
chmod +x scripts/*.sh
./scripts/install.sh
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
