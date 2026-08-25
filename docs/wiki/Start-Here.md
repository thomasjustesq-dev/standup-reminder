# Start here

Fifteen minutes, then stop and do the assigned task. Do not wander `Sources/` first.

## 1. Confirm the machine

The Crucial X8 must be mounted at `/Volumes/Crucial X8`. If it is not, stop. Canonical checkout is `/Volumes/Crucial X8/GitHub/standup-reminder`. That checkout has sat on `fix/menubar-icon-blank` (open PR #21) rather than `main`. Analyse and implement from a worktree on `origin/main` unless the briefing says otherwise. There is no `/Volumes/Crucial X8/GitHub/Projects/` layer — `NEXT.md` still quotes that stale path.

Protocol: vault note `Projects/Claude Code/_Coordination.md`, then `Projects/Claude Code/standup-reminder.md`, then this repo's `CLAUDE.md`.

Register on `Projects/Claude Code/_Live.md` before writing. Surface is `checkout :: glob` and must include the worktree path if you are not on the canonical tree.

Claim-first scripts exist (`scripts/claim-open.sh`, `docs/claims/`). They are **dormant**. Do not open a claim, fill an ASSIGNMENT slot, or expand process CI unless Thomas is running concurrent agents again. Live claims index is empty. Solo work: feature branch, PR, never push `main`.

## 2. Read these, in this order

1. This page and [Current status](Current-Status.md).
2. [Operating rules](Operating-Rules.md) (`CLAUDE.md`).
3. [Traps](Traps.md).
4. The file that matches the task: [Architecture](Architecture.md) for product code, [Contributing](Contributing.md) for process, `docs/DISTRIBUTION.md` for ship.

Do not treat `NEXT.md` as live ship state without checking GitHub Releases. Do not treat the canonical checkout as `main`.

## 3. Hard facts that change what you build

- **Identity is locked.** Bundle ID, App Group, and iCloud container are `com.thomasjust.standupreminder` and the matching `group.` / `iCloud.` strings. Do not invent new ones. Application Support stays `StandUpReminder/`.
- **Authority lease is 15 minutes.** Phone honors Mac presence/`nextFireAt` only while `runtime.json` `updatedAt` is fresh. After that it schedules locally and shows “Mac offline · local schedule.” Do not “fix” a stale Mac by making the phone defer forever.
- **Core stays platform-pure.** `Sources/StandUpReminderCore` must not import AppKit, UIKit, WatchKit, AVFoundation, EventKit, or ServiceManagement. `scripts/check-core-purity.sh` is the gate.
- **`MenuBarExtra` + `HStack` is blank on macOS 14+.** That is the `main` menu bar extra at this SHA. Do not put a container around the extra’s label. The stretching-figure mark is PR #21, not this tree.
- **Do not `codesign --deep` an installed bundle.** It re-signs the widget with app entitlements; launch fails POSIX 162.
- **No Mac↔Watch channel.** Watch talks to iPhone via WatchConnectivity. Mac participates through iCloud settings/runtime sync.
- **iOS cannot observe meetings, Focus, idle, or deep work in the background.** Quiet rules live on the Mac. The phone is a follower with a pre-scheduled notification queue.

## 4. How to run checks

Swift 5.9+, macOS 14. Xcode (or CLT) for the app; `xcodegen` for iOS/Watch schemes.

```bash
scripts/status.sh
scripts/check-core-purity.sh
scripts/check-version-agree.sh
scripts/check-release-readiness.sh
swift test
```

CI also builds iOS + Watch via xcodegen. Device installs need the Apple Developer team and the matching App ID capabilities (App Groups, iCloud Documents, HealthKit, time-sensitive notifications).

Install (Development-signed, until you mean a notarized asset):

```bash
chmod +x scripts/*.sh
./scripts/install.sh
```

App lands at `~/Applications/StandUpReminder.app`. Config: `~/Library/Application Support/StandUpReminder/`. Log: `~/Library/Logs/standup-reminder.log`.

## 5. Then do the work

Solo: pick from `docs/ROADMAP.md`, open a feature branch, implement, PR. Do not push `main`. Append `docs/SESSION_LOG.md` / `docs/OPEN_QUESTIONS.md` / `docs/DECISIONS.md` as needed (`merge=union` on those three).

If something is ambiguous, append to `docs/OPEN_QUESTIONS.md` and implement the most conservative reading.

Fleet inference: Grok → Codex → Kimi → Gemini, then native GitHub Copilot. See `FLEET_INFERENCE.md`. Do not export `ANTHROPIC_API_KEY` into Copilot BYOK.
