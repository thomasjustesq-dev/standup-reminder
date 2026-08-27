import Foundation

/// Single source of truth for Aero-Kinetic design tokens across macOS, iOS,
/// watchOS, and WidgetKit targets.
///
/// Pure value types only — no SwiftUI (core purity). Each platform's
/// `AeroColor` maps these to `Color` so the RGB/opacity/metrics values can
/// never drift between targets.
enum AeroPalette {
    struct RGB {
        let red: Double
        let green: Double
        let blue: Double

        init(_ red: Double, _ green: Double, _ blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }
    }

    /// Deep OLED Obsidian Base Floor (#0A0B0E)
    static let void = RGB(0.039, 0.043, 0.055)
    /// Elevated Obsidian Layer (#121318)
    static let obsidian = RGB(0.071, 0.075, 0.094)
    /// Frosted Translucent Slate Plate (#161922)
    static let slate = RGB(0.086, 0.098, 0.133)
    /// Kinetic Volt Lime — Primary Action & Telemetry Accent (#D2FF3A)
    static let volt = RGB(0.824, 1.000, 0.227)
    /// Ion Blue — Alignment & Secondary Telemetry Accent (#0A84FF)
    static let ionBlue = RGB(0.039, 0.518, 1.000)
    /// Alert Orange — Warnings and Overdue Reminders (#FF9F0A)
    static let alertOrange = RGB(1.000, 0.624, 0.039)

    /// Volt Optical Glow
    static let voltGlowOpacity = 0.35
    /// Vapor Gray — Micro Metadata Text
    static let vaporGrayOpacity = 0.55
    /// Micro Hairline Divider
    static let hairlineOpacity = 0.12
    /// Specular Rim Refraction Highlight
    static let specularRimOpacity = 0.14
    /// Frosted Slate plate opacity on glass cards
    static let slateCardOpacity = 0.70

    /// Hairline / specular border width
    static let specularBorderWidth: CGFloat = 0.5
    /// Card shadow: .black 0.35, radius 24, y 12
    static let cardShadowOpacity = 0.35
    static let cardShadowRadius: CGFloat = 24
    static let cardShadowY: CGFloat = 12

    /// SF Pro countdown timers track tight
    static let timerTracking: CGFloat = -0.5
    /// SF Mono telemetry readouts track wide (uppercase)
    static let telemetryTracking: CGFloat = 0.8
}
