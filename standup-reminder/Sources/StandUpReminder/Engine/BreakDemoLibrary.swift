import Foundation

struct BreakDemo: Identifiable, Equatable {
    var id: String
    var systemImage: String
    var caption: String
    /// Optional bundled resource name (gif/png) without extension.
    var assetName: String?
}

enum BreakDemoLibrary {
    static func demo(forPromptId id: String) -> BreakDemo {
        switch id {
        case "stand", "desk-stand", "walk":
            return BreakDemo(id: id, systemImage: "figure.walk", caption: "Walk it out", assetName: "demo-walk")
        case "stretch", "hands":
            return BreakDemo(id: id, systemImage: "figure.strengthtraining.traditional", caption: "Easy mobility", assetName: "demo-stretch")
        case "eyes":
            return BreakDemo(id: id, systemImage: "eye", caption: "Soft focus 20-20-20", assetName: "demo-eyes")
        case "water", "hydrate":
            return BreakDemo(id: id, systemImage: "drop.fill", caption: "Hydrate", assetName: "demo-water")
        case "posture", "desk-sit":
            return BreakDemo(id: id, systemImage: "figure.stand", caption: "Stack your posture", assetName: "demo-posture")
        case "breathe":
            return BreakDemo(id: id, systemImage: "wind", caption: "Breathe slowly", assetName: "demo-breathe")
        case "lunch":
            return BreakDemo(id: id, systemImage: "fork.knife", caption: "Lunch break", assetName: "demo-lunch")
        case "wind-down":
            return BreakDemo(id: id, systemImage: "sunset.fill", caption: "Wrap the day", assetName: "demo-winddown")
        default:
            return BreakDemo(id: id, systemImage: "figure.cooldown", caption: "Move a little", assetName: nil)
        }
    }
}
