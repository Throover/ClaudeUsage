// Draws the 1024 px app icon, in TerminalPinch's family: same tile and same green prompt,
// with a usage gauge where TerminalPinch has its pinch arrows.
// Usage: make-icon <output.png>
import AppKit

let px = 1024
let s = CGFloat(px)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let inset = s * 0.1
let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
let tile = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
NSGradient(starting: NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.24, alpha: 1),
           ending: NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.09, alpha: 1))!.draw(in: tile, angle: -90)

let prompt = NSAttributedString(string: ">_", attributes: [
    .font: NSFont.monospacedSystemFont(ofSize: rect.width * 0.26, weight: .bold),
    .foregroundColor: NSColor(calibratedRed: 0.35, green: 0.95, blue: 0.55, alpha: 1)])
prompt.draw(at: NSPoint(x: rect.minX + rect.width * 0.12, y: rect.maxY - rect.width * 0.42))

let config = NSImage.SymbolConfiguration(pointSize: rect.width * 0.34, weight: .semibold)
if let symbol = NSImage(systemSymbolName: "gauge.with.dots.needle.67percent", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let tinted = NSImage(size: symbol.size, flipped: false) { r in
        symbol.draw(in: r); NSColor.white.set(); r.fill(using: .sourceAtop); return true
    }
    let size = tinted.size
    tinted.draw(in: NSRect(x: rect.maxX - size.width - rect.width * 0.12, y: rect.minY + rect.width * 0.12,
                           width: size.width, height: size.height))
}

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
