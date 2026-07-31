# Homebrew Cask pointing at the GitHub release assets that
# .github/workflows/release.yml publishes for each v* tag:
#
#   brew install --cask ./Casks/standup-reminder.rb
#
# Installs will 404 until that tag has actually been released. sha256 stays
# :no_check because the checksum is only knowable after the release is built.

cask "standup-reminder" do
  version "4.2.1"
  sha256 :no_check

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
    "~/Library/Preferences/com.user.StandUpReminder.plist",
  ]
end
