cask "standup-reminder" do
  version "4.2.4"
  sha256 "6a45efa9ad79d0d88f0754291e18745048e3c23e90488c8877ff4f7009373bff"

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
