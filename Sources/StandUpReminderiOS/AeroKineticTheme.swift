#if os(iOS)
import SwiftUI

// MARK: - Aero-Kinetic iOS Theme & Telemetry Design Tokens

public enum AeroColor {
    public static let void = Color(red: 0.039, green: 0.043, blue: 0.055)
    public static let obsidian = Color(red: 0.071, green: 0.075, blue: 0.094)
    public static let slate = Color(red: 0.086, green: 0.098, blue: 0.133)
    public static let volt = Color(red: 0.824, green: 1.000, blue: 0.227)
    public static let voltGlow = Color(red: 0.824, green: 1.000, blue: 0.227).opacity(0.35)
    public static let ionBlue = Color(red: 0.039, green: 0.518, blue: 1.000)
    public static let titaniumWhite = Color.white
    public static let vaporGray = Color.white.opacity(0.55)
    public static let hairline = Color.white.opacity(0.12)
    public static let specularRim = Color.white.opacity(0.20)
    public static let alertOrange = Color(red: 1.000, green: 0.624, blue: 0.039)
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
                        .fill(AeroColor.slate.opacity(0.75))
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
                        lineWidth: 0.75
                    )
            }
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
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
