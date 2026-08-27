#if os(iOS)
import SwiftUI

// MARK: - Aero-Kinetic iOS Theme & Telemetry Design Tokens

public enum AeroColor {
    private static func color(_ rgb: AeroPalette.RGB) -> Color {
        Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    public static let void = color(AeroPalette.void)
    public static let obsidian = color(AeroPalette.obsidian)
    public static let slate = color(AeroPalette.slate)
    public static let volt = color(AeroPalette.volt)
    public static let voltGlow = color(AeroPalette.volt).opacity(AeroPalette.voltGlowOpacity)
    public static let ionBlue = color(AeroPalette.ionBlue)
    public static let titaniumWhite = Color.white
    public static let vaporGray = Color.white.opacity(AeroPalette.vaporGrayOpacity)
    public static let hairline = Color.white.opacity(AeroPalette.hairlineOpacity)
    public static let specularRim = Color.white.opacity(AeroPalette.specularRimOpacity)
    public static let alertOrange = color(AeroPalette.alertOrange)
}

public struct AeroGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var strokeColor: Color
    var glowColor: Color?

    public init(cornerRadius: CGFloat = 20, strokeColor: Color = AeroColor.hairline, glowColor: Color? = nil) {
        self.cornerRadius = cornerRadius
        self.strokeColor = strokeColor
        self.glowColor = glowColor
    }

    public func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(AeroColor.slate.opacity(AeroPalette.slateCardOpacity))
                        .background(.ultraThinMaterial)
                    
                    if let glow = glowColor {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(glow.opacity(0.3), lineWidth: 1.5)
                            .blur(radius: 4)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                AeroColor.specularRim,
                                strokeColor,
                                strokeColor.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: AeroPalette.specularBorderWidth
                    )
            }
            .shadow(color: Color.black.opacity(AeroPalette.cardShadowOpacity), radius: AeroPalette.cardShadowRadius, x: 0, y: AeroPalette.cardShadowY)
    }
}

public extension View {
    func aeroGlassCard(cornerRadius: CGFloat = 20, strokeColor: Color = AeroColor.hairline, glowColor: Color? = nil) -> some View {
        modifier(AeroGlassCardModifier(cornerRadius: cornerRadius, strokeColor: strokeColor, glowColor: glowColor))
    }
    
    func aeroGlow(color: Color = AeroColor.volt, radius: CGFloat = 10) -> some View {
        self.shadow(color: color.opacity(0.45), radius: radius, x: 0, y: 0)
    }
}

public struct AeroCountdownGauge: View {
    public let progress: Double // 0.0 ... 1.0
    public let timeRemainingText: String
    public let subtitle: String
    public var accentColor: Color = AeroColor.volt
    public var size: CGFloat = 180

    public init(
        progress: Double,
        timeRemainingText: String,
        subtitle: String = "UNTIL BREAK",
        accentColor: Color = AeroColor.volt,
        size: CGFloat = 180
    ) {
        self.progress = max(0.0, min(1.0, progress))
        self.timeRemainingText = timeRemainingText
        self.subtitle = subtitle
        self.accentColor = accentColor
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Track
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(
                    Color.white.opacity(0.10),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(90))

            // Glowing Arc
            Circle()
                .trim(from: 0.15, to: 0.15 + (0.70 * progress))
                .stroke(
                    LinearGradient(
                        colors: [accentColor.opacity(0.7), accentColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .aeroGlow(color: accentColor, radius: 14)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)

            // Center Readout
            VStack(spacing: 4) {
                Text(timeRemainingText)
                    .font(.system(size: 38, weight: .bold, design: .default))
                    .monospacedDigit()
                    .tracking(AeroPalette.timerTracking)
                    .foregroundStyle(AeroColor.titaniumWhite)
                
                Text(subtitle.uppercased())
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(AeroColor.vaporGray)
            }
        }
        .frame(width: size, height: size)
    }
}
#endif
