# Local Homebrew formula.
#
#   cd standup-reminder
#   brew install --build-from-source ./Formula/standup-reminder.rb
#
# If brew rejects the file URL, use ./scripts/install.sh instead.

class StandupReminder < Formula
  desc "Menu bar break reminders for macOS workdays (stand, stretch, lunch)"
  homepage "https://cursor.com"
  version "4.2.1"
  url "file://#{File.expand_path("..", __dir__)}"
  sha256 :no_check

  depends_on :macos => :sonoma
  depends_on xcode: ["15.0", :build]

  def install
    system "swift", "build", "-c", "release", "--product", "StandUpReminder"
    bin_path = Utils.safe_popen_read("swift", "build", "-c", "release", "--show-bin-path").strip
    binary = "#{bin_path}/StandUpReminder"

    app = prefix/"StandUpReminder.app"
    (app/"Contents/MacOS").mkpath
    (app/"Contents/Resources").mkpath
    cp binary, app/"Contents/MacOS/StandUpReminder"
    cp "Resources/Info.plist", app/"Contents/Info.plist"
    chmod 0755, app/"Contents/MacOS/StandUpReminder"

    bin.install_symlink app/"Contents/MacOS/StandUpReminder" => "standup-reminder"
  end

  def caveats
    <<~EOS
      Launch once so the menu bar icon appears:
        open #{opt_prefix}/StandUpReminder.app

      CLI:
        standup-reminder status
        standup-reminder pause|resume|snooze|test|test-lunch
    EOS
  end

  test do
    assert_match "Stand Up Reminder CLI", shell_output("#{bin}/standup-reminder help")
  end
end
