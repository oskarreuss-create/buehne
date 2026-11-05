import AppKit
// Usage: swift make_glass_icon.swift out-dir
// Draws the BÜHNE mark (same geometry as App/Icon/main.swift) with NO tile behind it, for the desktop shortcut:
// the black body becomes frosted glass, the play triangle and the cross stay white, the flag stays red.
// Writes out-dir/BUEHNE-icon-glass.png (1024) and out-dir/BUEHNE-icon-glass.iconset (all sizes).
let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
func col(_ v: UInt32, _ a: CGFloat = 1) -> CGColor { CGColor(srgbRed: CGFloat((v >> 16) & 255)/255, green: CGFloat((v >> 8) & 255)/255, blue: CGFloat(v & 255)/255, alpha: a) }
func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
let cap = CGMutablePath()
cap.move(to: P(0,275)); cap.addCurve(to: P(241,0), control1: P(-3,108), control2: P(83,0))
cap.addCurve(to: P(559,35), control1: P(333,0), control2: P(444,18)); cap.addCurve(to: P(0,275), control1: P(306,34), control2: P(90,80)); cap.closeSubpath()
let body = CGMutablePath()
body.move(to: P(6,440)); body.addCurve(to: P(426,78), control1: P(6,179), control2: P(203,93))
body.addCurve(to: P(764,63), control1: P(563,69), control2: P(695,62)); body.addCurve(to: P(947,250), control1: P(881,63), control2: P(947,144))
body.addLine(to: P(950,361)); body.addCurve(to: P(626,504), control1: P(810,381), control2: P(721,430))
body.addCurve(to: P(164,676), control1: P(521,590), control2: P(441,638)); body.addCurve(to: P(7,542), control1: P(66,692), control2: P(9,624)); body.closeSubpath()
let sweep = CGMutablePath(); sweep.move(to: P(243,694))
sweep.addCurve(to: P(636,544), control1: P(442,663), control2: P(523,635)); sweep.addCurve(to: P(950,395), control1: P(737,462), control2: P(816,412))
sweep.addLine(to: P(950,519)); sweep.addCurve(to: P(785,694), control1: P(950,617), control2: P(878,694)); sweep.closeSubpath()
let play = CGMutablePath(); play.move(to: P(363,230))
play.addCurve(to: P(409,204), control1: P(364,205), control2: P(385,189)); play.addLine(to: P(610,328))
play.addCurve(to: P(611,389), control1: P(636,344), control2: P(635,372)); play.addLine(to: P(411,507))
play.addCurve(to: P(364,478), control1: P(389,518), control2: P(364,505)); play.closeSubpath()
func render(_ px: Int) -> CGImage {
    let c = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // y down, mark (950x694) centred with ~10% margin
    let s = CGFloat(px) * 0.80 / 950
    c.translateBy(x: CGFloat(px) * 0.10, y: CGFloat(px) - (CGFloat(px) - 694 * s) / 2); c.scaleBy(x: s, y: -s)
    func clipFill(_ path: CGPath, _ colors: [CGColor], from: CGPoint, to: CGPoint) {
        c.saveGState(); c.addPath(path); c.clip()
        c.drawLinearGradient(CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors as CFArray, locations: nil)!, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]); c.restoreGState()
    }
    // soft shadow under the glass body
    c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: -22 * s * 1.0), blur: 40 * s, color: col(0x000000, 0.35))
    c.addPath(body); c.setFillColor(col(0xFFFFFF, 0.10)); c.fillPath(); c.restoreGState()
    // frosted glass body: brighter at the top, clearer at the bottom
    clipFill(body, [col(0xFFFFFF, 0.50), col(0xB4C0E0, 0.34), col(0x7C8CB8, 0.46)], from: P(0, 60), to: P(0, 690))
    // inner glow near the edge and a rim
    c.saveGState(); c.addPath(body); c.clip(); c.addPath(body); c.setStrokeColor(col(0xFFFFFF, 0.55)); c.setLineWidth(26); c.setLineJoin(.round); c.strokePath(); c.restoreGState()
    c.addPath(body); c.setStrokeColor(col(0xFFFFFF, 0.97)); c.setLineWidth(7); c.setLineJoin(.round); c.strokePath()
    // top-left highlight
    c.saveGState(); c.addPath(body); c.clip(); c.addEllipse(in: CGRect(x: -120, y: -200, width: 760, height: 420)); c.setFillColor(col(0xFFFFFF, 0.18)); c.fillPath(); c.restoreGState()
    // white glass cap
    clipFill(cap, [col(0xFFFFFF, 0.98), col(0xDDE5F8, 0.92)], from: P(0, 0), to: P(0, 275))
    // red flag
    c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: -6 * s), blur: 12 * s, color: col(0x600008, 0.35))
    clipFill(sweep, [col(0xF2222E), col(0xD3000F)], from: P(243, 540), to: P(950, 694)); c.restoreGState()
    // white play triangle with a little depth
    c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: -10 * s), blur: 22 * s, color: col(0x1a2540, 0.40))
    c.addPath(play); c.setFillColor(col(0xFFFFFF)); c.fillPath(); c.restoreGState()
    // white Swiss cross
    c.setFillColor(col(0xFFFFFF)); c.fill(CGRect(x: 790, y: 487, width: 41, height: 133)); c.fill(CGRect(x: 746, y: 532, width: 128, height: 42))
    return c.makeImage()!
}
func write(_ img: CGImage, _ name: String, in dir: URL) { try! NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent(name)) }
let iconset = outDir.appendingPathComponent("BUEHNE-icon-glass.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
write(render(1024), "BUEHNE-icon-glass.png", in: outDir)
for (n, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    write(render(px), "icon_\(n).png", in: iconset)
}
