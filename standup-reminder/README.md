# Stand Up Reminder (macOS) · v3

Menu bar wellness companion for **iMac / MacBook / Mac Mini / Mac Studio** (macOS 14+).

## Highlights

- **Break cadence** — every ~30 minutes (adaptive), Mon–Fri 9–5, per-day hours, time-zone aware  
- **Lunch + end-of-day wind-down**  
- **Sit/stand desk mode** — alternating phase cues  
- **Reminder packs** — Balanced, Developer, Meeting-heavy, Recovery  
- **Quiet rules** — lock, display sleep, Focus, meetings, PTO/OOO, deep work, app denylist  
- **Meeting catch-up** — one nudge when a call ends  
- **Guided break UI** — short timed stretch cards  
- **Menu bar countdown** — minutes until next break  
- **Profiles** — e.g. Office Mac vs Laptop  
- **Export / import** settings JSON  
- **Apple Health** optional mindful minutes on **Done**  
- **Widget** (optional via XcodeGen) + `widget.json` snapshot  
- **Update check** via GitHub Releases API URL  
- **Notarization script** for Developer ID distribution  
- **CLI** for status/pause/profile/pack/import/export/tests  

## Install

```bash
cd standup-reminder
chmod +x scripts/*.sh
./scripts/install.sh
```

Builds to `~/Applications/StandUpReminder.app` and symlinks `~/.local/bin/standup-reminder`.

### Widget (optional)

```bash
brew install xcodegen
./scripts/build-app.sh   # uses xcodegen when present
```

Then add the widget from Notification Center.

### Notarized distribution (optional)

```bash
export APPLE_ID=...
export APPLE_TEAM_ID=...
export APPLE_APP_PASSWORD=...
./scripts/build-app.sh
./scripts/notarize.sh
```

### Updates

In **Settings → General**, set **GitHub Releases API URL**, e.g.  
`https://api.github.com/repos/<you>/<repo>/releases/latest`

## CLI

```bash
standup-reminder status
standup-reminder pause|resume|snooze|skip-today
standup-reminder profile            # list
standup-reminder profile "Laptop"   # switch
standup-reminder pack developer
standup-reminder export settings.json
standup-reminder import settings.json
standup-reminder test|test-lunch|test-wind-down|test-guided
```

## Settings storage

| File | Purpose |
| --- | --- |
| `~/Library/Application Support/StandUpReminder/config.json` | Active settings |
| `~/Library/Application Support/StandUpReminder/profiles.json` | Named profiles |
| `~/Library/Application Support/StandUpReminder/runtime.json` | Pause/snooze/desk phase |
| `~/Library/Application Support/StandUpReminder/stats.json` | Local stats |
| `~/Library/Application Support/StandUpReminder/widget.json` | Widget snapshot |
| `~/Library/Logs/standup-reminder.log` | Log |

## Uninstall

```bash
./scripts/uninstall.sh
```

## Legacy

Shell + LaunchAgent installer remains under [`legacy/`](legacy/).

## Develop

```bash
swift build
swift run StandUpReminder
./scripts/build-app.sh
```
