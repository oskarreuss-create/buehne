import AppKit
// Usage: swift make_dmg_background.swift out.png  — light installer background (Finder labels are black) with an arrow between the two icons.
let out = CommandLine.arguments[1]
let w: CGFloat = 660, h: CGFloat = 420, scale: CGFloat = 2
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w * scale), pixelsHigh: Int(h * scale), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: w, height: h)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGradient(colors: [NSColor(white: 0.97, alpha: 1), NSColor(white: 0.88, alpha: 1)])!.draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: -90)
func text(_ s: String, size: CGFloat, weight: NSFont.Weight, y: CGFloat, alpha: CGFloat) {
    let p = NSMutableParagraphStyle(); p.alignment = .center
    let a: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: NSColor(white: 0.1, alpha: alpha), .paragraphStyle: p]
    NSAttributedString(string: s, attributes: a).draw(in: NSRect(x: 20, y: y, width: w - 40, height: size + 8))
}
text("Drag BÜHNE to Applications", size: 24, weight: .light, y: h - 70, alpha: 0.9)
text("Перетащите BÜHNE в «Программы» · Ziehen Sie BÜHNE in „Programme“", size: 13, weight: .regular, y: h - 100, alpha: 0.55)
// Arrow between the icons (icon centres at x=165 and x=495, y from top = 220 → 200 from bottom).
let cy = h - 220 + 6
let path = NSBezierPath()
path.lineWidth = 7; path.lineCapStyle = .round; path.lineJoinStyle = .round
path.move(to: NSPoint(x: 270, y: cy)); path.line(to: NSPoint(x: 390, y: cy))
path.move(to: NSPoint(x: 360, y: cy + 26)); path.line(to: NSPoint(x: 392, y: cy)); path.line(to: NSPoint(x: 360, y: cy - 26))
NSColor(white: 0.1, alpha: 0.55).setStroke(); path.stroke()
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
