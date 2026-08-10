# Next (after reboot) — ship 4.2.2

**Status as of 2026-08-10:** Product code for 4.2.2 is on `main` (#10, #11).  
**122 tests green.** Code is release-ready. **Only ship work left.**

## You must do (cannot automate)

### 1. Apple Developer portal
For App ID `com.thomasjust.standupreminder` (Mac + iOS):

- [ ] App Group: `group.com.thomasjust.standupreminder`
- [ ] iCloud container: `iCloud.com.thomasjust.standupreminder`

### 2. Secrets (pick one path)

**Local notarize:**
```bash
export APPLE_ID="…"
export APPLE_TEAM_ID="…"
export APPLE_APP_PASSWORD="…"   # appleid.apple.com app-specific password
```

**Or GitHub Actions** (repo secrets):  
`APPLE_CERTIFICATES_P12`, `APPLE_CERTIFICATES_PASSWORD`,  
`APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_PRIVATE_KEY`  
Optional: `SPARKLE_ED_PRIVATE_KEY`

### 3. Ship
```bash
cd "/Volumes/Crucial X8/GitHub/Projects/standup-reminder"
./scripts/check-release-readiness.sh
# Path A:
git tag v4.2.2 && git push origin v4.2.2
# Path B:
./scripts/build-app.sh && ./scripts/notarize.sh
```

### 4. After the zip exists
- [ ] Put real `sha256` in `Casks/standup-reminder.rb` (drop `:no_check`)
- [ ] Smoke: `brew install --cask ./Casks/standup-reminder.rb`
- [ ] Mac: enable iCloud sync → **Push once** (seed banner if empty)
- [ ] iPhone: confirm presence / schedule; leave Mac offline >15m → “Mac offline · local schedule”

## Already done (do not re-open)

| Item | PR |
| --- | --- |
| Authority lease 15m, PhoneModel split, diagnostics CLI | #10 |
| Suppression Held/top-block/lease, iOS notif Settings, guided userInitiated | #11 |
| ROADMAP/docs update | #12 |

Version: **4.2.2 (build 8)**  
Preflight: `./scripts/check-release-readiness.sh`  
Full notes: `docs/DISTRIBUTION.md`, `docs/ROADMAP.md`, `docs/OPEN_QUESTIONS.md`

## Say to the agent after reboot

> Open standup-reminder and ship 4.2.2 — portal/secrets are ready.

(or paste this file)
