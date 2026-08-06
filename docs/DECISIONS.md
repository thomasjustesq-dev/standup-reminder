# Decisions

Append-only. `merge=union`.

---

## 2026-08-04 — Adopt scaled multi-agent coordination

**Decision:** Install PENUMBRA/OVERLAND-scaled claim-first package
(ASSIGNMENT, claims, write surfaces, union logs, path classifier, guard).

**Rationale:** Fleet-wide consistency across repositories; prevent collision
classes once multi-agent work is real.

**Scope:** process/docs/scripts only for this land. Product behavior unchanged.

---

## 2026-08-06 — Canonical identity + multi-device runtime correctness

**Decision:** Single reverse-DNS root `com.thomasjust.standupreminder` for
bundle IDs, App Group, and iCloud container across Mac / iOS / Watch / widgets.
Runtime merge clears snooze and skip-today when a newer remote doc has no
active value; Mac adaptive interval is pushed in the runtime doc for iOS.

**Rationale:** Split `com.user` vs `com.thomasjust` broke App Groups and
confused provisioning; snooze resume on one device could not clear peers;
iOS ignored adaptive cadence.

**Migration:** Local Application Support path unchanged. Re-push iCloud after
install. Create App Group + iCloud container on the App ID if missing.

---

## 2026-08-06 — Pause sync + adaptive newest-wins + quiet defaults

**Decision:** `isPaused` travels on the runtime doc; effective interval is
newest-doc-wins with ≥5 minute hysteresis on local recompute. New-install
feature flags keep weather/watch/learn/voice off until opted in.

**Rationale:** Pause was local-only; multi-Mac adaptive thrash; first-run
settings overload.

---

## 2026-08-06 — Mac primary suppressor; diagnostics local-only by default

**Decision:** Product copy and architecture treat Mac as the quiet-rule primary;
iOS schedules notifications. Diagnostics POST only when a validated HTTPS
endpoint is set — empty endpoint means AppLog only.

**Rationale:** Platform limits on phone; half-wired telemetry is a privacy footgun.
