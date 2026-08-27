# Current status

Snapshot of `origin/main` at `9f8d5c4` (2026-08-19). Living status also lives in `README.md`, `NEXT.md`, and `docs/ROADMAP.md`. This page is orientation. Where `NEXT.md` and GitHub disagree, GitHub Releases and the cask file win.

## Operating posture

| Item | State |
| --- | --- |
| Marketing version | **4.2.2** (build **8**) in `AppVersion` |
| GitHub release | **`v4.2.2`** published 2026-08-11 |
| Homebrew cask | Real `sha256` + release zip URL (`Casks/standup-reminder.rb`; #18 / #19) |
| Menu bar extra on `main` | **Blank on macOS 14+.** `MenuBarExtra` label is an `HStack`. Fix is open PR [#21](https://github.com/thomasjustesq-dev/standup-reminder/pull/21) (`fix/menubar-icon-blank`), CI green, not merged |
| Canonical checkout | Has sat on `fix/menubar-icon-blank`, not `main` |
| Identity | Locked: `com.thomasjust.standupreminder` · group · iCloud |
| Authority lease | 15 minutes (`AuthorityLease.defaultTTL`) |
| Claim-first | **Dormant.** ASSIGNMENT empty. Solo branches/PRs |
| Hosted CI | GitHub-hosted `macos-*` only. Never `runs-on: self-hosted` |
| Fleet inference | Grok → Codex → Kimi → Gemini, then Copilot (`FLEET_INFERENCE.md`, #22, `9f8d5c4`) |

## What shipped on this SHA

Authority lease, PhoneModel split, diagnostics CLI, seed-iCloud banner (#10). Suppression glance, iOS notification trust, guided-break activate policy (#11). Identity unification to `com.thomasjust.standupreminder` (2026-08-06). Cask sha for the 4.2.2 zip. Fleet BYOK degrade and grok-4.6 preflight default.

iCloud container `iCloud.com.thomasjust.standupreminder` is on the Mac Development profile (legacy container retained for migration). A live install has already migrated files from `iCloud.com.user.StandUpReminder`.

## What `NEXT.md` still says (stale on this SHA)

`NEXT.md` is dated 2026-08-10 evening and still claims the notarized GitHub release is blocked on Developer ID + `APPLE_CERTIFICATES_P12`. The tag and release exist. The cask `sha256` is filled. Do not re-run “do not push `v4.2.2`.” Do not treat the `GitHub/Projects/standup-reminder` path in that file as real.

`docs/ROADMAP.md` still lists “First notarized GitHub release + Cask sha” as **Next**. That row is done on this SHA; the live product gap is the blank menu bar extra (#21) plus whatever ship follow-up Thomas still wants (portal App Group confirm, live 15-minute lease degrade on hardware, Sparkle-linked distribution builds).

## Open product / portal items

| Item | Notes |
| --- | --- |
| Aero-Kinetic Theme | VisionOS spatial glass, acoustic 528 Hz synthesis, dynamic menu bar arc, watch dial, global hotkeys (`feature/aero-kinetic-theme`) |
| Merge #21 | Stretching-figure `NSStatusItem`; no `HStack` around the extra |
| App Group on portal | Binary is signed with `group.com.thomasjust.standupreminder`; confirm the group exists and is attached to Mac + iOS + widget App IDs |
| Live multi-device confirm | One iCloud push re-seeds peers; Mac offline >15m → phone “Mac offline · local schedule” |
| Sparkle appcast | Template only (`docs/appcast.xml`) unless Sparkle is linked in a distribution build |
| CloudKit / pedometer / Focus Filters | Explicitly later (`docs/DECISIONS.md` 2026-08-06) |
| Settings / AppConfig split | Opportunistic hygiene, not the current job |

## What is not the current job

Do not invent bundle IDs. Do not revive claim-first or fill ASSIGNMENT. Do not merge the leftover `standup-reminder-fix` tree into this repo. Do not `codesign --deep` the installed app. Do not make the phone permanently defer to a stale Mac. Do not build Mac↔Watch. Do not add AppKit to `StandUpReminderCore`. Do not push `main`.
