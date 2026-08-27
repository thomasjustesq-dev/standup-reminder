import SwiftUI

// MARK: - Aero-Kinetic Color Palette

public enum AeroColor {
    /// Deep OLED Obsidian Base Floor (#0A0B0E)
    public static let void = Color(red: 0.039, green: 0.043, blue: 0.055)
    
    /// Elevated Obsidian Layer (#121318)
    public static let obsidian = Color(red: 0.071, green: 0.075, blue: 0.094)
    
    /// Frosted Translucent Slate Plate (#161922)
    public static let slate = Color(red: 0.086, green: 0.098, blue: 0.133)
    
    /// Kinetic Volt Lime - Primary Action & Telemetry Accent (#D2FF3A)
    public static let volt = Color(red: 0.824, green: 1.000, blue: 0.227)
    
    /// Volt Optical Glow
    public static let voltGlow = Color(red: 0.824, green: 1.000, blue: 0.227).opacity(0.35)
    
    /// Ion Blue - Alignment & Secondary Telemetry Accent (#0A84FF)
    public static let ionBlue = Color(red: 0.039, green: 0.518, blue: 1.000)
    
    /// Titanium Pure White (#FFFFFF)
    public static let titaniumWhite = Color.white
    
    /// Vapor Gray - Micro Metadata Text
    public static let vaporGray = Color.white.opacity(0.55)
    
    /// Micro Hairline Divider
    public static let hairline = Color.white.opacity(0.12)
    
    /// Specular Rim Refraction Highlight
    public static let specularRim = Color.white.opacity(0.20)
    
    /// Alert Orange - Warnings and Overdue Reminders (#FF9F0A)
    public static let alertOrange = Color(red: 1.000, green: 0.624, blue: 0.039)
}

// MARK: - Aero-Kinetic View Modifiers

public struct AeroGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var strokeColor: Color
    var glowColor: Color?

    public init(cornerRadius: CGFloat = 16, strokeColor: Color = AeroColor.hairline, glowColor: Color? = nil) {
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
            .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
    }
}

public extension View {
    func aeroGlassCard(cornerRadius: CGFloat = 16, strokeColor: Color = AeroColor.hairline, glowColor: Color? = nil) -> some View {
        modifier(AeroGlassCardModifier(cornerRadius: cornerRadius, strokeColor: strokeColor, glowColor: glowColor))
    }
    
    func aeroGlow(color: Color = AeroColor.volt, radius: CGFloat = 8) -> some View {
        self.shadow(color: color.opacity(0.45), radius: radius, x: 0, y: 0)
    }
}

// MARK: - Reusable Aero-Kinetic UI Components

/// Circular / Semicircular Glowing Countdown Arc
public struct AeroCountdownGauge: View {
    public let progress: Double // 0.0 ... 1.0
    public let timeRemainingText: String
    public let subtitle: String
    public var accentColor: Color = AeroColor.volt
    public var deskPhase: String? = nil
    public var size: CGFloat = 130

    public init(
        progress: Double,
        timeRemainingText: String,
        subtitle: String = "UNTIL BREAK",
        accentColor: Color = AeroColor.volt,
        deskPhase: String? = nil,
        size: CGFloat = 130
    ) {
        self.progress = max(0.0, min(1.0, progress))
        self.timeRemainingText = timeRemainingText
        self.subtitle = subtitle
        self.accentColor = accentColor
        self.deskPhase = deskPhase
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Background Track
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(
                    Color.white.opacity(0.10),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(90))

            // Active Glowing Progress Arc
            Circle()
                .trim(from: 0.15, to: 0.15 + (0.70 * progress))
                .stroke(
                    LinearGradient(
                        colors: [accentColor.opacity(0.7), accentColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .aeroGlow(color: accentColor, radius: 10)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)

            // Centered Telemetry Readout
            VStack(spacing: 2) {
                if let phase = deskPhase {
                    HStack(spacing: 3) {
                        Image(systemName: phase.lowercased().contains("stand") ? "figure.stand" : "figure.seated.side")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AeroColor.volt)
                        Text(phase.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(AeroColor.volt)
                    }
                    .padding(.bottom, 1)
                }

                Text(timeRemainingText)
                    .font(.system(size: 24, weight: .bold, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(AeroColor.titaniumWhite)
                
                Text(subtitle.uppercased())
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(AeroColor.vaporGray)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Precision Status Badge
public struct AeroTelemetryBadge: View {
    public let text: String
    public var statusColor: Color = AeroColor.volt
    public var isPulseActive: Bool = true

    public init(text: String, statusColor: Color = AeroColor.volt, isPulseActive: Bool = true) {
        self.text = text
        self.statusColor = statusColor
        self.isPulseActive = isPulseActive
    }

    public var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .aeroGlow(color: statusColor, radius: isPulseActive ? 4 : 0)
            
            Text(text.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(AeroColor.titaniumWhite)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background {
            Capsule()
                .fill(AeroColor.obsidian.opacity(0.8))
                .overlay {
                    Capsule()
                        .strokeBorder(AeroColor.hairline, lineWidth: 0.5)
                }
        }
    }
}

/// VisionOS Geometric Posture & Stillness Radar
public struct AeroPostureRadar: View {
    public var facePresent: Bool
    public var isStillTooLong: Bool
    public var alignmentScore: Int = 92 // Percentage (0-100)

    public init(facePresent: Bool, isStillTooLong: Bool, alignmentScore: Int = 92) {
        self.facePresent = facePresent
        self.isStillTooLong = isStillTooLong
        self.alignmentScore = alignmentScore
    }

    private var statusColor: Color {
        if !facePresent { return AeroColor.vaporGray }
        return isStillTooLong ? AeroColor.alertOrange : AeroColor.volt
    }

    private var statusText: String {
        if !facePresent { return "OFF DESK" }
        return isStillTooLong ? "STILL TOO LONG" : "NOMINAL"
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Radar Icon Glyph
            ZStack {
                Circle()
                    .stroke(statusColor.opacity(0.3), lineWidth: 1)
                    .frame(width: 32, height: 32)
                
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 24, height: 24)
                
                Image(systemName: facePresent ? (isStillTooLong ? "figure.stand.line.dotted.figure.stand" : "figure.walk") : "person.slash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .aeroGlow(color: statusColor, radius: 4)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("POSTURE RADAR")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(AeroColor.vaporGray)
                    
                    Text("· \(statusText)")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(statusColor)
                }
                
                Text(facePresent ? (isStillTooLong ? "Extended stillness detected — stretch advised" : "Micro-movements & posture active (\(alignmentScore)%)") : "No presence detected at camera")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AeroColor.titaniumWhite)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(10)
        .aeroGlassCard(cornerRadius: 12, strokeColor: statusColor.opacity(0.3))
    }
}

/// Refined Frosted Glass Pill Button
public struct AeroGlassButton: View {
    public let title: String
    public var systemImage: String? = nil
    public var isProminent: Bool = false
    public var tintColor: Color = AeroColor.volt
    public let action: () -> Void

    public init(
        title: String,
        systemImage: String? = nil,
        isProminent: Bool = false,
        tintColor: Color = AeroColor.volt,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isProminent = isProminent
        self.tintColor = tintColor
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 11, weight: isProminent ? .bold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6.5)
            .padding(.horizontal, 10)
            .foregroundStyle(isProminent ? AeroColor.void : AeroColor.titaniumWhite)
            .background {
                if isProminent {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tintColor)
                        .aeroGlow(color: tintColor, radius: 6)
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AeroColor.slate.opacity(0.6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(AeroColor.specularRim, lineWidth: 0.5)
                        }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
