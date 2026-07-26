# Quick start (Mac)

1. Clone this repository to your Mac.
2. Install Xcode (or Command Line Tools + Swift 5.9+).
3. In Terminal:

```bash
cd /path/to/standup-reminder
chmod +x scripts/*.sh
./scripts/install.sh
```

4. Allow **Notifications** when prompted.
5. Open the menu bar icon → **Welcome / permissions…** (Calendar, Focus, optional Health / iCloud / voice).
6. Optional: **Sample day tour…** to see how 9–5 behaves.

### Everyday controls

| Action | Menu bar | CLI |
| --- | --- | --- |
| Pause | Pause | `standup-reminder pause` |
| Resume | Resume | `standup-reminder resume` |
| Snooze 10m | Snooze 10 minutes | `standup-reminder snooze 10` |
| Status | (top of menu) | `standup-reminder status` |
| Settings | Settings… | — |

### Useful paths

- App: `~/Applications/StandUpReminder.app`
- Config: `~/Library/Application Support/StandUpReminder/`
- Log: `~/Library/Logs/standup-reminder.log`

Full feature list: [README.md](README.md) · Shipping: [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md)
