# Stand Up Reminder (macOS)

Menu bar app that reminds you to move during the workday, eat lunch at noon, and take light wellness breaks — built for **iMac, MacBook, Mac Mini, and Mac Studio** (macOS 14+).

## Features

| Area | What you get |
| --- | --- |
| Menu bar | Enable/disable, pause/resume, snooze 10m, skip today, test alerts |
| Schedule | Every 30 minutes, 9–5, per-day hours |
| Lunch | Noon lunch reminder (configurable window) |
| Rotating prompts | Stand/move, stretch, water, 20-20-20 eyes, posture |
| Quiet rules | Skip when locked, display asleep, Focus/DND, or in a calendar meeting |
| Presence | Skip when idle; optional warm-up after you return |
| Notifications | Actions: **Done**, **Snooze 10m**, **Skip today** |
| Stats | Weekly + all-time shown/done/snoozed/skipped (local only) |
| Onboarding | First-run permissions guide |
| CLI | `status`, `pause`, `resume`, `snooze`, `test`, … |
| Install | `scripts/install.sh` → `~/Applications`, optional Homebrew formula |

## Install (recommended)

On your Mac, with Xcode or the Swift toolchain installed:

```bash
cd standup-reminder
chmod +x scripts/*.sh
./scripts/install.sh
```

That builds `StandUpReminder.app`, copies it to `~/Applications`, opens it, and symlinks the CLI to `~/.local/bin/standup-reminder`.

If macOS blocks the app: **right-click → Open**, or allow it under **System Settings → Privacy & Security**.

### Homebrew (from this folder)

```bash
./scripts/build-app.sh
# then either use scripts/install.sh, or:
brew install --build-from-source ./Formula/standup-reminder.rb
```

> The formula builds from the local checkout. Prefer `scripts/install.sh` if Homebrew complains about the URL.

## CLI

```bash
standup-reminder status
standup-reminder pause
standup-reminder resume
standup-reminder snooze 15
standup-reminder skip-today
standup-reminder test
standup-reminder test-lunch
standup-reminder help
```

Add `~/.local/bin` to your `PATH` if the command is not found.

## Settings

Open **Settings…** from the menu bar icon (`figure.stand`).

Config is stored at:

`~/Library/Application Support/StandUpReminder/config.json`

Runtime pause/snooze state:

`~/Library/Application Support/StandUpReminder/runtime.json`

Logs:

`~/Library/Logs/standup-reminder.log`

## Uninstall

```bash
./scripts/uninstall.sh
```

## Legacy shell / LaunchAgent version

The original bash + `launchd` installer lives in [`legacy/`](legacy/) if you want a no-compile option. The Swift app replaces it and `install.sh` removes the old LaunchAgent when present.

## Develop

```bash
swift build
swift run StandUpReminder
./scripts/build-app.sh
```

Requires **macOS 14+** and **Swift 5.9+** / Xcode 15+.
