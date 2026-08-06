# Distribution guide

## Version source of truth

Marketing version and build number live in:

- `Sources/StandUpReminderCore/AppIdentity.swift` → `AppVersion.marketing` / `AppVersion.build`
- `Resources/Info.plist` (`CFBundleShortVersionString` / `CFBundleVersion`)
- `project.yml` iOS/Watch/widget version fields
- `Formula/standup-reminder.rb` and `Casks/standup-reminder.rb`

Bump all of the above together before tagging. CI release workflow fails if the
git tag disagrees with `Resources/Info.plist`.

## Sparkle

Distribution builds can ship Sparkle with a signed `docs/appcast.xml` (see
release workflow + `SPARKLE_ED_PRIVATE_KEY`). Day-to-day / SPM builds use the
GitHub Releases checker unless a feed URL is set and Sparkle is linked. Empty
appcast feed URL is normal for non-distribution builds.

## Tag-triggered releases (GitHub Actions)

`.github/workflows/release.yml` turns a tag push into a full release:

    # 1. bump CFBundleShortVersionString in Resources/Info.plist (and the
    #    iOS/Watch versions in project.yml) — the workflow fails if the tag
    #    and Info.plist disagree
    git tag v4.2.1 && git push origin v4.2.1

The pipeline builds the Release app (Developer ID signing with provisioning
profiles via an App Store Connect API key), notarizes and staples it, packs a
Sparkle `.zip` and a `.dmg`, regenerates `docs/appcast.xml` (signed with the
Sparkle Ed key, committed back to `main`), and creates the GitHub release with
both artifacts.

Required repository secrets:

| Secret | What |
| --- | --- |
| `APPLE_CERTIFICATES_P12` | base64 `.p12` of the Developer ID Application cert + private key |
| `APPLE_CERTIFICATES_PASSWORD` | password for that `.p12` |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect API issuer ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | base64 `.p8` of the API key |
| `SPARKLE_ED_PRIVATE_KEY` | *(optional)* Sparkle EdDSA private key — without it the appcast step is skipped |

Notes: the appcast commit pushes straight to `main` as `github-actions[bot]`;
if `main` is protected, allow that actor (or GitHub Actions) to push. Re-tagging
the same version replaces its appcast item instead of duplicating it.

## Direct / Developer ID (manual)

1. `./scripts/build-app.sh`
2. `./scripts/notarize.sh` with `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD`
3. Zip or DMG the stapled `.app`
4. Host `docs/appcast.xml` + zip for Sparkle; set **Sparkle appcast URL** in Settings
5. `python3 scripts/update-appcast.py --help` inserts/signs an appcast item by hand

## Homebrew Cask

1. Publish the notarized zip
2. Update `Casks/standup-reminder.rb` `url` + `sha256`
3. `brew install --cask ./Casks/standup-reminder.rb`

## Mac App Store

1. Create App ID + iCloud container `iCloud.com.thomasjust.standupreminder` and App Group `group.com.thomasjust.standupreminder`
2. Use `Resources/StandUpReminder.mas.entitlements` (sandbox on)
3. Archive with Apple Distribution certificate
4. Disable Sparkle for MAS builds (App Store provides updates)
5. Camera / Health / Calendar usage strings are already in `Info.plist`

## Setapp

Package the notarized app per Setapp’s publisher guidelines; reuse the Developer ID build. Keep Sparkle disabled if Setapp handles updates.

## Watch companion

The Watch app is a companion to the **iPhone** app (an Apple Watch pairs only with an iPhone; there is no Mac↔Watch channel). `xcodegen generate` produces the watchOS app + complication targets, and building the `StandUpReminderiOS` scheme embeds them. The Mac participates through iCloud sync.
