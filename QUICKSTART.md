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

### Sync doctor

```bash
standup-reminder sync-doctor
standup-reminder block-stats
standup-reminder icloud-pull --force   # only if you mean to overwrite local
```

### Multi-device checklist (~5 minutes)

Identity (must match Apple Developer App IDs):

| Surface | Value |
| --- | --- |
| Bundle ID | `com.thomasjust.standupreminder` |
| App Group | `group.com.thomasjust.standupreminder` |
| iCloud | `iCloud.com.thomasjust.standupreminder` |

1. In [Apple Developer](https://developer.apple.com/account/resources/identifiers/list) enable **App Groups** and **iCloud Documents** on the Mac + iOS App IDs (and the matching group/container strings above).
2. Build/sign Mac + iPhone apps with the same team.
3. On Mac and iPhone, enable iCloud sync. The first device pushes its settings automatically; the other reconciles at launch or foreground.
4. Confirm **Cloud Sync Health** reports a successful push/pull. Manual controls are diagnostics only.
5. On phone: tap **Done** after a break → Mac menu countdown should re-anchor within ~1 minute.
6. On Mac: **Snooze**, then **Resume** → phone should clear snooze on next sync cycle.
7. On Mac: **Pause** → phone should stop pre-scheduling (status Paused) after sync.

If automatic sync fails, check iCloud Drive is on for the Apple ID and that the container identifier matches exactly.

### Version bump

```bash
./scripts/bump-version.sh 4.2.4 10
```

### Core purity

```bash
./scripts/check-core-purity.sh
```

Full feature list: [README.md](README.md) · Shipping: [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md)
