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
        .executableTarget(
            name: "StandUpReminder",
            path: "Sources",
            exclude: ["StandUpReminderWidget", "StandUpReminderWatch", "StandUpReminderiOS"],
            sources: ["StandUpReminder", "StandUpReminderCore"]
        ),
        .testTarget(
            name: "StandUpReminderTests",
            dependencies: ["StandUpReminder"],
            path: "Tests/StandUpReminderTests"
        )
    ]
)
