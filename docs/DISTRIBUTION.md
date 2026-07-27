# Distribution guide

## Tag-triggered releases (GitHub Actions)

`.github/workflows/release.yml` turns a tag push into a full release:

    # 1. bump every version in one shot
    ./scripts/bump-version.sh 4.2.1 7
    # 2. tag — the workflow fails if the tag and Info.plist disagree
    git tag v4.2.1 && git push origin v4.2.1

`bump-version.sh` updates `project.yml` (every target), `Resources/Info.plist`,
and the two Homebrew files, then runs `scripts/check-versions.sh` to confirm
they all agree. CI runs that same check on every PR, and the release workflow
runs it again before it builds anything.

The five `Resources/*-Info.plist` files are written by `xcodegen generate` from
the `info:` blocks in `project.yml`. They are gitignored, so editing them by
hand does nothing. `Resources/Info.plist` is the exception: it stays hand-
maintained because `scripts/build-app.sh`, the Homebrew formula, and the
release workflow's tag check all read it off disk before xcodegen runs.

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

1. Create App ID + iCloud container `iCloud.com.user.StandUpReminder`
2. Use `Resources/StandUpReminder.mas.entitlements` (sandbox on)
3. Archive with Apple Distribution certificate
4. Disable Sparkle for MAS builds (App Store provides updates)
5. Camera / Health / Calendar usage strings are already in `Info.plist`

## Setapp

Package the notarized app per Setapp’s publisher guidelines; reuse the Developer ID build. Keep Sparkle disabled if Setapp handles updates.

## Watch companion

The Watch app is a companion to the **iPhone** app (an Apple Watch pairs only with an iPhone; there is no Mac↔Watch channel). `xcodegen generate` produces the watchOS app + complication targets, and building the `StandUpReminderiOS` scheme embeds them. The Mac participates through iCloud sync.
