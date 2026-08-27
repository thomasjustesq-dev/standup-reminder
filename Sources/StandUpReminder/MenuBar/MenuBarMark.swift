import AppKit

/// Template status-item mark: the stretching figure from the app icon with optional kinetic progress ring.
enum MenuBarMark {
    static func image(denied: Bool = false, progress: Double? = nil) -> NSImage {
        let points: CGFloat = 22
        let image = NSImage(size: NSSize(width: points, height: points))
        image.addRepresentation(draw(points: points, scale: 1, denied: denied, progress: progress))
        image.addRepresentation(draw(points: points, scale: 2, denied: denied, progress: progress))
        image.isTemplate = true
        image.accessibilityDescription = denied
            ? "Stand Up Reminder — notifications denied"
            : "Stand Up Reminder"
        return image
    }

    private static func draw(points: CGFloat, scale: CGFloat, denied: Bool, progress: Double?) -> NSBitmapImageRep {
        let px = Int((points * scale).rounded())
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        rep.size = NSSize(width: points, height: points)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.clear(CGRect(x: 0, y: 0, width: points, height: points))
        
        // Design space is the 1024 app-icon canvas (y-up), matching make-icon.swift.
        let s = points / 1024
        ctx.scaleBy(x: s, y: s)

        // Draw optional kinetic progress arc around the figure
        if let progress = progress, progress > 0.0 {
            let clamped = max(0.01, min(1.0, progress))
            let center = CGPoint(x: 512, y: 512)
            let radius: CGFloat = 460
            
            // Outer subtle track
            ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.2).cgColor)
            ctx.setLineWidth(44)
            ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: false)
            ctx.strokePath()

            // Active progress arc
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(56)
            ctx.setLineCap(.round)
            let startAngle = CGFloat.pi / 2
            let endAngle = startAngle - (CGFloat.pi * 2 * CGFloat(clamped))
            ctx.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            ctx.strokePath()
        }

        ctx.setFillColor(NSColor.black.cgColor)
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineCap(.round)
        ctx.fillEllipse(in: CGRect(x: 512 - 88, y: 668, width: 176, height: 176))
        stroke(ctx, from: CGPoint(x: 512, y: 640), to: CGPoint(x: 512, y: 390), width: 112)
        stroke(ctx, from: CGPoint(x: 512, y: 590), to: CGPoint(x: 330, y: 800), width: 78)
        stroke(ctx, from: CGPoint(x: 512, y: 590), to: CGPoint(x: 694, y: 800), width: 78)
        stroke(ctx, from: CGPoint(x: 512, y: 400), to: CGPoint(x: 404, y: 150), width: 84)
        stroke(ctx, from: CGPoint(x: 512, y: 400), to: CGPoint(x: 620, y: 150), width: 84)

        if denied {
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(90)
            ctx.move(to: CGPoint(x: 180, y: 180))
            ctx.addLine(to: CGPoint(x: 844, y: 844))
            ctx.strokePath()
        }

        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private static func stroke(_ ctx: CGContext, from a: CGPoint, to b: CGPoint, width: CGFloat) {
        ctx.setLineWidth(width)
        ctx.move(to: a)
        ctx.addLine(to: b)
        ctx.strokePath()
    }
}
