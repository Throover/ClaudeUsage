// Draws the 1024 px app icon: two usage rings on a dark tile.
// Usage: make-icon <output.png>
import AppKit

let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS icon grid: an 824 px tile centered in the 1024 px canvas.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 186, yRadius: 186)
NSGradient(starting: NSColor(calibratedRed: 0.20, green: 0.21, blue: 0.25, alpha: 1),
           ending: NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.13, alpha: 1))!
    .draw(in: tilePath, angle: -90)

func ring(radius: CGFloat, fraction: CGFloat, color: NSColor) {
    let center = NSPoint(x: size / 2, y: size / 2)
    let track = NSBezierPath()
    track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
    track.lineWidth = 72
    NSColor.white.withAlphaComponent(0.12).setStroke()
    track.stroke()

    let arc = NSBezierPath()
    arc.appendArc(withCenter: center, radius: radius, startAngle: 90,
                  endAngle: 90 - 360 * fraction, clockwise: true)
    arc.lineWidth = 72
    arc.lineCapStyle = .round
    color.setStroke()
    arc.stroke()
}

ring(radius: 280, fraction: 0.68, color: NSColor(calibratedRed: 1.00, green: 0.78, blue: 0.16, alpha: 1))
ring(radius: 172, fraction: 0.32, color: NSColor(calibratedRed: 0.25, green: 0.84, blue: 0.42, alpha: 1))

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
