import Foundation

enum CloudSettingsSyncAction: Equatable {
    case applyRemote
    case pushLocal
    case unchanged
}

/// Resolves config/profile conflicts without creating a pull-save-push loop.
/// Equal payloads are already synchronized even when local file mtimes differ.
enum CloudSettingsSyncPolicy {
    static func decide(
        localConfig: AppConfig,
        localProfiles: ProfileDocument,
        localModifiedAt: Date?,
        remoteConfig: AppConfig,
        remoteProfiles: ProfileDocument?,
        remoteUpdatedAt: Date,
        isFreshInstall: Bool
    ) -> CloudSettingsSyncAction {
        if localConfig == remoteConfig, let remoteProfiles, localProfiles == remoteProfiles {
            return .unchanged
        }
        if isFreshInstall { return .applyRemote }
        if remoteProfiles == nil, localConfig == remoteConfig { return .pushLocal }
        guard let localModifiedAt else { return .applyRemote }
        return remoteUpdatedAt > localModifiedAt ? .applyRemote : .pushLocal
    }
}
