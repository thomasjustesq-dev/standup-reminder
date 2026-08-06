// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StandUpReminder",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "StandUpReminder", targets: ["StandUpReminder"])
    ],
    targets: [
        // Core sources live under Sources/StandUpReminderCore and must stay
        // free of AppKit (scripts/check-core-purity.sh). Compiled into the
        // app module so members stay internal across the menu bar target.
        .executableTarget(
            name: "StandUpReminder",
            path: "Sources",
            exclude: ["StandUpReminderWidget", "StandUpReminderWatch", "StandUpReminderiOS"],
            sources: ["StandUpReminder", "StandUpReminderCore", "DebugHarness"]
        ),
        .testTarget(
            name: "StandUpReminderTests",
            dependencies: ["StandUpReminder"],
            path: "Tests/StandUpReminderTests"
        )
    ]
)
