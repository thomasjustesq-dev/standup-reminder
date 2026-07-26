# Distribution guide

## Direct / Developer ID

1. `./scripts/build-app.sh`
2. `./scripts/notarize.sh` with `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD`
3. Zip or DMG the stapled `.app`
4. Host `docs/appcast.xml` + zip for Sparkle; set **Sparkle appcast URL** in Settings

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
