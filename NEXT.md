# Next — after v4.2.2

**Status as of 2026-08-26:** Product on `main` `14aad14`. GitHub release
**v4.2.2** exists (2026-08-11). Cask `sha256` is real (#18/#19). Menu bar
stretching-figure icon is on `main` (#21). Wiki handbook is in git (#23).
Canonical checkout: `/Volumes/Crucial X8/GitHub/standup-reminder` (not
`GitHub/Projects/`). Do not treat the 2026-08-10 “do not push tag v4.2.2”
checklist as live.

## Live status

| Check | Result |
| --- | --- |
| Tag / GitHub release `v4.2.2` | **Shipped** 2026-08-11 |
| Cask `Casks/standup-reminder.rb` | version `4.2.2` with sha256; url is the GitHub zip |
| Menu bar icon | #21 on `main` (not the blank `MenuBarExtra`+`HStack` extra) |
| Identity | `com.thomasjust.standupreminder` · group + iCloud new IDs |
| Wiki in git | #23. GitHub Wiki remote still needs a logged-in first page |

## Remaining operator work

1. Wiki tab **Create the first page**, then `scripts/publish_wiki.sh`.
2. iPhone smoke: presence/schedule; Mac offline >15m → “Mac offline · local schedule.”
3. Do not invent bundle IDs. Do not `codesign --deep` the installed bundle.
4. Do not run `xcodebuild` or the iOS simulator on the iMac.

The 2026-08-10 Developer ID / p12 / portal App Group checklist was the ship
blocker for the *first* notarized zip. That zip is published. Do not re-run
it as if 4.2.2 were still blocked. Future releases still need a valid
Developer ID in CI secrets.

## Already done

| Item | Notes |
| --- | --- |
| #10 / #11 product | Authority lease, daily UX, on main |
| #15 local signing / version | Ship prep |
| #18 / #19 cask sha | Notarized 4.2.2 zip |
| #21 menu bar icon | Stretching-figure mark |
| #23 wiki handbook | In git; Wiki tab not created |
| #26 Aero-Kinetic Suite | VisionOS glass, dynamic progress arc, spatial chimes, Watch dial, global hotkeys |
| Identity rename | `com.thomasjust.standupreminder` |

Version: **4.2.2** · Full notes: `docs/DISTRIBUTION.md`
