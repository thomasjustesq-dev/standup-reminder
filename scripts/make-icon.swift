// Renders the app icon: a stretching figure on a teal→indigo gradient.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let px = 1024

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
rep.size = NSSize(width: px, height: px)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Background gradient (y-up: start = top)
let colors = [
    NSColor(calibratedRed: 0.13, green: 0.72, blue: 0.60, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.10, green: 0.32, blue: 0.62, alpha: 1).cgColor
]
let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: colors as CFArray, locations: [0, 1]
)!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 512, y: 1024), end: CGPoint(x: 512, y: 0), options: []
)

// Figure: head + torso + raised arms + legs, thick round strokes
ctx.setFillColor(NSColor.white.cgColor)
ctx.fillEllipse(in: CGRect(x: 512 - 88, y: 668, width: 176, height: 176)) // head

ctx.setStrokeColor(NSColor.white.cgColor)
ctx.setLineCap(.round)

func stroke(_ a: CGPoint, _ b: CGPoint, width: CGFloat) {
    ctx.setLineWidth(width)
    ctx.move(to: a)
    ctx.addLine(to: b)
    ctx.strokePath()
}

stroke(CGPoint(x: 512, y: 640), CGPoint(x: 512, y: 390), width: 112) // torso
stroke(CGPoint(x: 512, y: 590), CGPoint(x: 330, y: 800), width: 78)  // left arm up
stroke(CGPoint(x: 512, y: 590), CGPoint(x: 694, y: 800), width: 78)  // right arm up
stroke(CGPoint(x: 512, y: 400), CGPoint(x: 404, y: 150), width: 84)  // left leg
stroke(CGPoint(x: 512, y: 400), CGPoint(x: 620, y: 150), width: 84)  // right leg

NSGraphicsContext.restoreGraphicsState()

let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
