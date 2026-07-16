# Homebrew Cask template.
# Publish a notarized .dmg/.zip, then:
#   brew install --cask ./Casks/standup-reminder.rb
#
# Or tap a repo that vendors this cask and points at your release assets.

cask "standup-reminder" do
  version "4.0.0"
  sha256 :no_check

  url "https://example.com/releases/StandUpReminder-#{version}.zip"
  name "Stand Up Reminder"
  desc "Menu bar break reminders with lunch, quiet rules, and guided stretches"
  homepage "https://example.com/standup-reminder"

  depends_on macos: ">= :sonoma"

  app "StandUpReminder.app"
  binary "#{appdir}/StandUpReminder.app/Contents/MacOS/StandUpReminder", target: "standup-reminder"

  zap trash: [
    "~/Library/Application Support/StandUpReminder",
    "~/Library/Logs/standup-reminder.log",
    "~/Library/Preferences/com.user.StandUpReminder.plist",
  ]
end
