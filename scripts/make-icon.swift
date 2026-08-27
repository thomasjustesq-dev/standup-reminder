// Renders the Aero-Kinetic app icon: VisionOS Obsidian glass squircle,
// glowing Volt telemetry ring, Ion Blue tickmarks, and titanium white stretching figure.
// Usage: swift scripts/make-icon.swift

import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]

func renderIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.clear(CGRect(x: 0, y: 0, width: s, height: s))

    // Scale to canonical 1024x1024 coordinate system
    let scale = s / 1024.0
    ctx.scaleBy(x: scale, y: scale)

    // 1. Deep OLED Obsidian Base Squircle (#0A0B0E -> #141720)
    let baseRect = CGRect(x: 32, y: 32, width: 960, height: 960)
    let cornerRadius: CGFloat = 224
    let path = CGPath(roundedRect: baseRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    let baseColors = [
        NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.12, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.04, green: 0.04, blue: 0.06, alpha: 1.0).cgColor
    ]
    let baseGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: baseColors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(baseGrad, start: CGPoint(x: 512, y: 992), end: CGPoint(x: 512, y: 32), options: [])

    // 2. Translucent Glass Plate with Specular Rim
    let innerRect = CGRect(x: 72, y: 72, width: 880, height: 880)
    let innerPath = CGPath(roundedRect: innerRect, cornerWidth: 184, cornerHeight: 184, transform: nil)
    
    ctx.saveGState()
    ctx.addPath(innerPath)
    ctx.setFillColor(NSColor(calibratedRed: 0.09, green: 0.11, blue: 0.15, alpha: 0.6).cgColor)
    ctx.fillPath()
    
    // Specular Rim Gradient
    ctx.addPath(innerPath)
    ctx.setLineWidth(3.0)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.25).cgColor)
    ctx.strokePath()
    ctx.restoreGState()

    // 3. Telemetry Ticks (Ion Blue #0A84FF)
    let center = CGPoint(x: 512, y: 512)
    let tickRadius: CGFloat = 340
    let numTicks = 48
    ctx.setLineCap(.round)

    for i in 0..<numTicks {
        let angle = (CGFloat(i) / CGFloat(numTicks)) * CGFloat.pi * 2
        let isMajor = (i % 6 == 0)
        let tickLen: CGFloat = isMajor ? 28 : 14
        let innerR = tickRadius - tickLen
        
        let p1 = CGPoint(x: center.x + cos(angle) * innerR, y: center.y + sin(angle) * innerR)
        let p2 = CGPoint(x: center.x + cos(angle) * tickRadius, y: center.y + sin(angle) * tickRadius)
        
        ctx.setLineWidth(isMajor ? 6.0 : 3.0)
        let alpha: CGFloat = isMajor ? 0.85 : 0.40
        ctx.setStrokeColor(NSColor(calibratedRed: 0.04, green: 0.52, blue: 1.0, alpha: alpha).cgColor)
        ctx.move(to: p1)
        ctx.addLine(to: p2)
        ctx.strokePath()
    }

    // 4. Kinetic Volt Glowing Progress Arc (270° sweep)
    let voltColor = NSColor(calibratedRed: 0.824, green: 1.000, blue: 0.227, alpha: 1.0)
    let arcRadius: CGFloat = 375

    // Outer Glow Track
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 32, color: voltColor.cgColor)
    ctx.setStrokeColor(voltColor.cgColor)
    ctx.setLineWidth(24)
    ctx.setLineCap(.round)
    ctx.addArc(center: center, radius: arcRadius, startAngle: CGFloat.pi * 0.75, endAngle: CGFloat.pi * 2.25, clockwise: false)
    ctx.strokePath()
    ctx.restoreGState()

    // Inner Track Core
    ctx.setStrokeColor(voltColor.cgColor)
    ctx.setLineWidth(20)
    ctx.setLineCap(.round)
    ctx.addArc(center: center, radius: arcRadius, startAngle: CGFloat.pi * 0.75, endAngle: CGFloat.pi * 2.25, clockwise: false)
    ctx.strokePath()

    // 5. Hero Stretching Figure in Titanium White
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 8), blur: 16, color: NSColor.black.withAlphaComponent(0.6).cgColor)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillEllipse(in: CGRect(x: 512 - 76, y: 648, width: 152, height: 152)) // Head

    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineCap(.round)

    func stroke(_ a: CGPoint, _ b: CGPoint, width: CGFloat) {
        ctx.setLineWidth(width)
        ctx.move(to: a)
        ctx.addLine(to: b)
        ctx.strokePath()
    }

    stroke(CGPoint(x: 512, y: 620), CGPoint(x: 512, y: 400), width: 96) // Torso
    stroke(CGPoint(x: 512, y: 575), CGPoint(x: 350, y: 760), width: 68) // Left arm raised
    stroke(CGPoint(x: 512, y: 575), CGPoint(x: 674, y: 760), width: 68) // Right arm raised
    stroke(CGPoint(x: 512, y: 410), CGPoint(x: 418, y: 190), width: 74) // Left leg
    stroke(CGPoint(x: 512, y: 410), CGPoint(x: 606, y: 190), width: 74) // Right leg
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()

    let img = NSImage(size: NSSize(width: s, height: s))
    img.addRepresentation(rep)
    return img
}

// Generate all sizes for macOS AppIcon.appiconset
let macSetURL = URL(fileURLWithPath: "Resources/Assets.xcassets/AppIcon.appiconset")
for size in sizes {
    let img = renderIcon(size: size)
    if let rep = img.representations.first as? NSBitmapImageRep,
       let data = rep.representation(using: .png, properties: [:]) {
        let dest = macSetURL.appendingPathComponent("icon-\(size).png")
        try! data.write(to: dest)
        print("Generated: \(dest.path)")
    }
}

// Generate for iOS and Watch
let iosSetURL = URL(fileURLWithPath: "Sources/StandUpReminderiOS/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
let watchSetURL = URL(fileURLWithPath: "Sources/StandUpReminderWatch/Assets.xcassets/AppIcon.appiconset/icon-1024.png")

let hero1024 = renderIcon(size: 1024)
if let rep = hero1024.representations.first as? NSBitmapImageRep,
   let data = rep.representation(using: .png, properties: [:]) {
    try? data.write(to: iosSetURL)
    try? data.write(to: watchSetURL)
    print("Updated iOS & Watch 1024 icons.")
}
