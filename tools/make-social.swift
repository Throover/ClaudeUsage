// Draws the 1280x640 image shown when the repository or the website is shared.
// Usage: make-social <docs folder>
import AppKit

let docs = CommandLine.arguments[1]
let w = 1280, h = 640
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let canvas = NSRect(x: 0, y: 0, width: w, height: h)
NSGradient(starting: NSColor(calibratedRed: 0.16, green: 0.18, blue: 0.24, alpha: 1),
           ending: NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.09, alpha: 1))!.draw(in: canvas, angle: -90)

func text(_ string: String, _ font: NSFont, _ color: NSColor, y: CGFloat) {
    NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
        .draw(at: NSPoint(x: 72, y: y))
}
let green = NSColor(calibratedRed: 0.35, green: 0.95, blue: 0.55, alpha: 1)
let soft = NSColor.white.withAlphaComponent(0.72)
text(">_", .monospacedSystemFont(ofSize: 54, weight: .bold), green, y: 490)
text("ClaudeUsage", .systemFont(ofSize: 72, weight: .bold), .white, y: 390)
text("Claude Code usage monitor", .systemFont(ofSize: 34, weight: .medium), .white, y: 322)
text("for your Mac menu bar", .systemFont(ofSize: 34, weight: .medium), .white, y: 278)
text("No password prompts", .systemFont(ofSize: 25), soft, y: 186)
text("No tokens used", .systemFont(ofSize: 25), soft, y: 148)
text("Free and open source", .systemFont(ofSize: 25), soft, y: 110)

if let menu = NSImage(contentsOfFile: docs + "/menu.png") {
    let width: CGFloat = 500
    let height = width * menu.size.height / menu.size.width
    let box = NSRect(x: 708, y: (CGFloat(h) - height) / 2, width: width, height: height)
    let clip = NSBezierPath(roundedRect: box, xRadius: 14, yRadius: 14)
    NSColor(calibratedWhite: 0.87, alpha: 1).setFill()
    clip.fill()
    menu.draw(in: box)
}
NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: docs + "/social-preview.png"))
