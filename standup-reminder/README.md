# Stand Up Reminder (macOS)

A lightweight reminder that nudges you to stand up and move every **30 minutes** during work hours (**9am–5pm**, weekdays by default), plus a **lunch reminder at noon**.

Works on **iMac, MacBook, Mac Mini, and Mac Studio** (any Mac running a recent macOS).

It uses:

- **Notification Center** alerts (via `osascript`)
- A **LaunchAgent** so it runs in the background while you are logged in — no app window, no menu bar clutter

## Quick install

1. Copy the `standup-reminder` folder to your Mac.
2. Open **Terminal**.
3. Run:

```bash
cd /path/to/standup-reminder
chmod +x install.sh uninstall.sh bin/standup-reminder.sh
./install.sh
```

4. Send a test notification:

```bash
~/Library/Application\ Support/StandUpReminder/bin/standup-reminder.sh --test
~/Library/Application\ Support/StandUpReminder/bin/standup-reminder.sh --test-lunch
```

5. If macOS asks for notification permission, allow it  
   (**System Settings → Notifications** — look for **Script Editor** or the Terminal/`osascript` entry).

Reminders continue automatically after reboot as long as you are logged in.

## Default schedule

| Setting | Default |
| --- | --- |
| Hours | 9:00am – 4:30pm (every 30 minutes) |
| Lunch | 12:00pm (replaces the stand-up ping at noon) |
| Days | Monday – Friday |
| When locked | Skips if the Mac screen is locked |

“9–5” means reminders fire while the clock hour is 9 through 16 (last ping at **4:30pm**). Change this in `config.env` if you want a different window.

## Customize

Edit `config.env` in this folder (or the installed copy at  
`~/Library/Application Support/StandUpReminder/config.env`):

```bash
START_HOUR=9
END_HOUR=17
INTERVAL_MINUTES=30
WEEKDAYS_ONLY=1
SKIP_WHEN_LOCKED=1
NOTIFICATION_TITLE="Stand Up Reminder"
NOTIFICATION_BODY="Time to stand up and move around for a minute or two."
SOUND_NAME="Glass"
LUNCH_ENABLED=1
LUNCH_HOUR=12
LUNCH_MINUTE=0
LUNCH_TITLE="Lunch Reminder"
LUNCH_BODY="It's noon — time to take a break and eat lunch."
```

After changing **hours**, **interval**, or **weekdays**, re-run `./install.sh` so the LaunchAgent schedule is regenerated.

Message/title/sound/lunch text changes apply on the next reminder without reinstalling if you edit the **installed** `config.env`.

## Uninstall

```bash
cd /path/to/standup-reminder
./uninstall.sh
```

## Logs

- `~/Library/Logs/standup-reminder.log` — when reminders fired or were skipped
- `~/Library/Logs/standup-reminder.launchd.*.log` — LaunchAgent stdout/stderr

## How it works

`install.sh` copies the script into Application Support and creates  
`~/Library/LaunchAgents/com.user.standupreminder.plist` with `StartCalendarInterval` entries for each reminder time. At each interval, `bin/standup-reminder.sh` double-checks the schedule (and lock state), then shows a Notification Center alert.

## Notes

- Requires being **logged in** to a user session (normal for desk Macs).
- Does not need admin rights.
- Safe to keep running overnight: outside the configured window it simply does nothing.
