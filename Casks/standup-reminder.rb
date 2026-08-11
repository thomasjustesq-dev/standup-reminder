# Homebrew Cask template.
# Publish a notarized .dmg/.zip, then point `url` + `sha256` at the release asset.
# Until then this file is a packaging stub — not installable from example.com.

cask "standup-reminder" do
  version "4.2.2"
  sha256 "5e1d9d7b30a21e268e6cdae96ff8230001903a7a1449021b183653b89bec7848"

  # Replace with the GitHub release asset after notarization:
  #   https://github.com/thomasjustesq-dev/standup-reminder/releases/download/v#{version}/StandUpReminder-#{version}.zip
  url "https://github.com/thomasjustesq-dev/standup-reminder/releases/download/v#{version}/StandUpReminder-#{version}.zip"
  name "Stand Up Reminder"
  desc "Menu bar break reminders with lunch, quiet rules, and guided stretches"
  homepage "https://github.com/thomasjustesq-dev/standup-reminder"

  depends_on macos: ">= :sonoma"

  app "StandUpReminder.app"
  binary "#{appdir}/StandUpReminder.app/Contents/MacOS/StandUpReminder", target: "standup-reminder"

  zap trash: [
    "~/Library/Application Support/StandUpReminder",
    "~/Library/Logs/standup-reminder.log",
    "~/Library/Preferences/com.thomasjust.standupreminder.plist",
  ]
end
