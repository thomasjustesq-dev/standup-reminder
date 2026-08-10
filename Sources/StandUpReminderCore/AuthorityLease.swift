import Foundation

/// Cadence-authority liveness for multi-device followers (iPhone).
///
/// The Mac publishes presence + nextFireAt on `runtime.json` with `updatedAt`.
/// When that stamp is older than the TTL, the authority is treated as offline
/// and followers degrade to a full local schedule instead of honoring a stale
/// meeting/Focus gate forever.
enum AuthorityLease {
    /// Default: 15 minutes. Matches how often a healthy Mac pushes (every
    /// runtime mutation + periodic sync) with headroom for iCloud lag.
    static let defaultTTL: TimeInterval = 15 * 60

    enum Mode: String, Equatable {
        /// Honor authority presence and next-fire gate.
        case following
        /// Lease expired or never seen — schedule locally; show offline UI.
        case degraded
    }

    /// Whether the authority stamp is fresh enough to trust.
    static func isAlive(
        updatedAt: Date?,
        now: Date = Date(),
        ttl: TimeInterval = defaultTTL
    ) -> Bool {
        guard let updatedAt else { return false }
        return now.timeIntervalSince(updatedAt) <= ttl
    }

    /// Follower mode from lease liveness.
    static func mode(
        isFollower: Bool,
        authorityUpdatedAt: Date?,
        now: Date = Date(),
        ttl: TimeInterval = defaultTTL
    ) -> Mode {
        guard isFollower else { return .following }
        return isAlive(updatedAt: authorityUpdatedAt, now: now, ttl: ttl) ? .following : .degraded
    }

    /// True when the phone should filter/clamp the queue with Mac presence/gate.
    /// Non-followers never honor a remote authority lease.
    static func shouldHonorAuthority(
        isFollower: Bool,
        authorityUpdatedAt: Date?,
        now: Date = Date(),
        ttl: TimeInterval = defaultTTL
    ) -> Bool {
        guard isFollower else { return false }
        return isAlive(updatedAt: authorityUpdatedAt, now: now, ttl: ttl)
    }

    /// Age of the lease, or nil when never stamped.
    static func age(updatedAt: Date?, now: Date = Date()) -> TimeInterval? {
        guard let updatedAt else { return nil }
        return now.timeIntervalSince(updatedAt)
    }

    /// Status line for the phone (and any pure UI that cannot see AppKit).
    static func followerStatusText(
        configEnabled: Bool,
        isPaused: Bool,
        isSkipToday: Bool,
        isSnoozing: Bool,
        notificationsAuthorized: Bool,
        authorityPresence: PresenceState?,
        authorityName: String?,
        authorityUpdatedAt: Date?,
        upcomingEmpty: Bool,
        now: Date = Date(),
        ttl: TimeInterval = defaultTTL
    ) -> String {
        if !configEnabled { return "Disabled" }
        if isPaused { return "Paused" }
        if isSkipToday { return "Skipped today" }
        if isSnoozing { return "Snoozing" }
        if !notificationsAuthorized { return "Notifications denied" }

        let leaseMode = mode(
            isFollower: true,
            authorityUpdatedAt: authorityUpdatedAt,
            now: now,
            ttl: ttl
        )
        switch leaseMode {
        case .degraded:
            if authorityUpdatedAt == nil {
                return "No Mac authority · local schedule"
            }
            let who = authorityName.map { " (\($0))" } ?? ""
            return "Mac offline\(who) · local schedule"
        case .following:
            if let presence = authorityPresence, FollowerSchedulePolicy.blocksFullFire(presence) {
                let who = authorityName.map { " · \($0)" } ?? ""
                return "Mac\(who): \(presence.displayName)"
            }
            if upcomingEmpty { return "Outside work hours" }
            return "Armed (follower)"
        }
    }

    /// Short badge for UI when degraded.
    static func degradationBadge(
        authorityUpdatedAt: Date?,
        authorityName: String?,
        now: Date = Date(),
        ttl: TimeInterval = defaultTTL
    ) -> String? {
        guard !isAlive(updatedAt: authorityUpdatedAt, now: now, ttl: ttl) else { return nil }
        if authorityUpdatedAt == nil {
            return "Push from Mac once to share authority presence"
        }
        let mins = Int((age(updatedAt: authorityUpdatedAt, now: now) ?? 0) / 60)
        let who = authorityName ?? "Mac"
        return "\(who) last seen \(mins)m ago — using local schedule"
    }
}
