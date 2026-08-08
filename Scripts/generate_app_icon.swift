import AppKit
import Foundation

let size = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Unable to allocate app icon bitmap.\n", stderr)
    exit(1)
}

let context = NSGraphicsContext(bitmapImageRep: bitmap)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let canvas = NSRect(x: 0, y: 0, width: size, height: size)
let gradient = NSGradient(
    starting: NSColor(red: 0.12, green: 0.17, blue: 0.38, alpha: 1),
    ending: NSColor(red: 0.24, green: 0.42, blue: 0.74, alpha: 1)
)
gradient?.draw(in: canvas, angle: 52)

func roundedCard(_ rect: NSRect, radius: CGFloat, color: NSColor, alpha: CGFloat = 1) {
    color.withAlphaComponent(alpha).setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

roundedCard(NSRect(x: 220, y: 210, width: 570, height: 600), radius: 68, color: .white, alpha: 0.22)
roundedCard(NSRect(x: 175, y: 255, width: 570, height: 600), radius: 68, color: .white, alpha: 0.42)
roundedCard(NSRect(x: 130, y: 300, width: 570, height: 600), radius: 68, color: .white)

NSColor(red: 0.19, green: 0.32, blue: 0.62, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 220, y: 680, width: 390, height: 44), xRadius: 22, yRadius: 22).fill()
NSColor(red: 0.66, green: 0.72, blue: 0.84, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 220, y: 585, width: 330, height: 28), xRadius: 14, yRadius: 14).fill()
NSBezierPath(roundedRect: NSRect(x: 220, y: 520, width: 395, height: 28), xRadius: 14, yRadius: 14).fill()
NSBezierPath(roundedRect: NSRect(x: 220, y: 455, width: 275, height: 28), xRadius: 14, yRadius: 14).fill()

let checkCircle = NSBezierPath(ovalIn: NSRect(x: 475, y: 155, width: 330, height: 330))
NSColor(red: 0.30, green: 0.79, blue: 0.65, alpha: 1).setFill()
checkCircle.fill()

let check = NSBezierPath()
check.move(to: NSPoint(x: 555, y: 315))
check.line(to: NSPoint(x: 620, y: 245))
check.line(to: NSPoint(x: 735, y: 375))
check.lineWidth = 34
check.lineCapStyle = .round
check.lineJoinStyle = .round
NSColor.white.setStroke()
check.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode app icon PNG.\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: "ScreenStash/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
do {
    try pngData.write(to: outputURL, options: .atomic)
} catch {
    fputs("Unable to write app icon: \(error.localizedDescription)\n", stderr)
    exit(1)
}
