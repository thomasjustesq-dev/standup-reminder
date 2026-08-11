# Next — ship 4.2.2

**Status as of 2026-08-10 evening:** Product code on `main` (#10, #11). Preflight
green. Local Development build **installed and running** (`~/Applications`, 4.2.2
build 8). **Notarized GitHub release still blocked** on Developer ID + CI p12.

## Live status (this machine)

| Check | Result |
| --- | --- |
| `./scripts/check-release-readiness.sh` | Code OK; local notary env vars unset |
| Installed app | `~/Applications/StandUpReminder.app` · running |
| Identity | `com.thomasjust.standupreminder` · group + iCloud new IDs |
| Dev profile iCloud | **Has** `iCloud.com.thomasjust.standupreminder` (+ legacy) |
| Dev profile App Groups | Profile listed legacy `group.com.user.*` + `BBTNHBK7VX.*`; binary **signed with** `group.com.thomasjust.standupreminder` — confirm group exists on portal |
| Developer ID Application | **Missing** on keychain. CSR+key already at `~/.standup-release/` (team `BBTNHBK7VX`) |
| GH secrets present | ASC key trio, `SPARKLE_ED_PRIVATE_KEY`, `REPO_PAT` |
| GH secrets **missing** | `APPLE_CERTIFICATES_P12`, `APPLE_CERTIFICATES_PASSWORD` |
| Tag `v4.2.2` | **Do not push** until p12 is in secrets (release.yml will fail at sign step) |

## You must do (cannot fully automate)

### 1. Finish Developer ID (blocks notarized ship)

CSR is ready: `~/.standup-release/developer-id.csr` (CN=Thomas Just, OU=BBTNHBK7VX).

1. developer.apple.com → Certificates → **Developer ID Application** → upload CSR
2. Download `.cer` → double-click into login keychain (pairs with existing `.key`)
3. Export identity as `.p12` (set a password)
4. Repo secrets:
   ```bash
   base64 -i DeveloperID.p12 | pbcopy   # → APPLE_CERTIFICATES_P12
   # APPLE_CERTIFICATES_PASSWORD = the p12 password
   ```
5. Optional local notary path instead of CI:
   ```bash
   export APPLE_ID=… APPLE_TEAM_ID=BBTNHBK7VX APPLE_APP_PASSWORD=…
   ./scripts/build-app.sh && ./scripts/notarize.sh
   ```

### 2. Portal confirm (quick)

For App ID `com.thomasjust.standupreminder` (Mac + iOS):

- [x] iCloud container `iCloud.com.thomasjust.standupreminder` (seen on live profile)
- [ ] App Group **`group.com.thomasjust.standupreminder`** exists and is checked on App IDs
      (widget + iPhone need the same group)

### 3. Ship (after 1–2)

```bash
cd "/Volumes/Crucial X8/GitHub/Projects/standup-reminder"
./scripts/check-release-readiness.sh
git tag v4.2.2 && git push origin v4.2.2   # Path A: Actions release.yml
# OR local: ./scripts/build-app.sh && ./scripts/notarize.sh
```

After the zip exists:

- [ ] Put real `sha256` in `Casks/standup-reminder.rb` (drop `:no_check`)
- [ ] Smoke: `brew install --cask ./Casks/standup-reminder.rb`
- [ ] iPhone: presence/schedule; Mac offline >15m → “Mac offline · local schedule”

## Already done

| Item | Notes |
| --- | --- |
| #10 / #11 product | Authority lease, daily UX, on main |
| Local 4.2.2 install | Development-signed, widget embedded |
| Legacy iCloud migrate | Live: “Migrated 4 file(s) from legacy iCloud container” |
| `build-app.sh` | `-allowProvisioningUpdates`; no longer ad-hoc clobber of Xcode signature |

Version: **4.2.2 (build 8)** · Full notes: `docs/DISTRIBUTION.md`
