import Foundation

/// Canonical reverse-DNS identity for the whole app family.
///
/// Application Support stays at `StandUpReminder/` so local config/stats
/// survive a bundle-id change. iCloud Documents live under the container
/// below; after upgrading from `com.user.*` / `iCloud.com.user.*`, push once
/// from any device to re-seed the new container.
enum AppIdentity {
    static let reverseDNS = "com.thomasjust.standupreminder"
    static let macBundleId = reverseDNS
    static let macWidgetBundleId = reverseDNS + ".widget"
    static let iosBundleId = reverseDNS
    static let iosWidgetBundleId = reverseDNS + ".widget"
    static let watchBundleId = reverseDNS + ".watchkitapp"
    static let watchWidgetBundleId = reverseDNS + ".watchkitapp.widget"
    static let appGroupID = "group." + reverseDNS
    static let iCloudContainer = "iCloud." + reverseDNS
    static let backgroundRefreshTaskId = reverseDNS + ".refresh"
    static let distributedNotificationPrefix = reverseDNS

    static let externalStateChanged = Notification.Name(reverseDNS + ".externalStateChanged")
    static let remoteCommand = Notification.Name(reverseDNS + ".remoteCommand")
}

/// Single marketing / build version for Info.plist, project.yml, Formula, Cask.
enum AppVersion {
    static let marketing = "4.2.3"
    static let build = "9"
}
