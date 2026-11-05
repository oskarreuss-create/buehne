// Reproducible vector artwork. AppKit/CoreGraphics/CoreText only; no dependencies.
// Geometry is transcribed from supplied references 11/13. No embedded fonts.
import AppKit
import CoreText
import ImageIO
import SwiftUI

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let work = URL(fileURLWithPath: CommandLine.arguments[2])
let fm = FileManager.default
let red = NSColor(srgbRed: 227/255, green: 6/255, blue: 19/255, alpha: 1).cgColor
func color(_ value: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((value >> 16) & 255)/255, green: CGFloat((value >> 8) & 255)/255, blue: CGFloat(value & 255)/255, alpha: alpha)
}
func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath { CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil) }
func fill(_ c: CGContext, _ path: CGPath, _ ink: CGColor) { c.addPath(path); c.setFillColor(ink); c.fillPath() }
func gradient(_ c: CGContext, _ path: CGPath, _ colors: [CGColor], _ start: CGPoint, _ end: CGPoint) {
    c.saveGState(); c.addPath(path); c.clip()
    c.drawLinearGradient(CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors as CFArray, locations: nil)!, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]); c.restoreGState()
}
func stroke(_ c: CGContext, _ path: CGPath, _ ink: CGColor, _ width: CGFloat) {
    c.addPath(path); c.setStrokeColor(ink); c.setLineWidth(width); c.setLineJoin(.round); c.strokePath()
}
func image(_ url: URL) -> CGImage {
    let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(source, 0, nil)!
}
func drawImage(_ c: CGContext, _ image: CGImage, _ rect: CGRect) {
    c.saveGState(); c.translateBy(x: rect.minX, y: rect.maxY); c.scaleBy(x: 1, y: -1)
    c.interpolationQuality = .high; c.draw(image, in: CGRect(origin: .zero, size: rect.size)); c.restoreGState()
}
func raster(_ width: Int, _ height: Int, _ draw: (CGContext) -> Void) -> CGImage {
    let c = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.translateBy(x: 0, y: CGFloat(height)); c.scaleBy(x: 1, y: -1)
    c.setAllowsAntialiasing(true); c.setShouldAntialias(true); draw(c)
    return c.makeImage()!
}
func png(_ image: CGImage, _ url: URL) throws {
    try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: url)
}
func pdf(_ name: String, size: CGSize, draw: (CGContext) -> Void) {
    let url = root.appendingPathComponent("Sources/BuehneUI/Resources/\(name).pdf")
    var box = CGRect(origin: .zero, size: size)
    let c = CGContext(url as CFURL, mediaBox: &box, nil)!
    c.beginPDFPage(nil); c.translateBy(x: 0, y: size.height); c.scaleBy(x: 1, y: -1)
    draw(c); c.endPDFPage(); c.closePDF()
}

/// Helvetica Bold-style reference outlines, transcribed in the reference's own
/// ink bounds. Font-independent at runtime; circular umlauts are separate paths.
func letter(_ c: CGContext, _ character: Character, _ rect: CGRect, _ ink: CGColor) {
    c.saveGState(); c.translateBy(x: rect.minX, y: rect.minY)
    let p = CGMutablePath()
    func polygon(_ points: [(CGFloat,CGFloat)]) {
        p.move(to: CGPoint(x: points[0].0,y: points[0].1))
        for (x,y) in points.dropFirst() { p.addLine(to: CGPoint(x: x,y: y)) }
        p.closeSubpath()
    }
    switch character {
    case "B":
        c.scaleBy(x: rect.width/191,y: rect.height/232)
        p.move(to: .zero); p.addLine(to: CGPoint(x: 115,y: 0))
        p.addCurve(to: CGPoint(x: 179,y: 65), control1: CGPoint(x: 166,y: 0), control2: CGPoint(x: 180,y: 32))
        p.addCurve(to: CGPoint(x: 150,y: 109), control1: CGPoint(x: 177,y: 88), control2: CGPoint(x: 164,y: 102))
        p.addCurve(to: CGPoint(x: 191,y: 166), control1: CGPoint(x: 177,y: 117), control2: CGPoint(x: 191,y: 133))
        p.addCurve(to: CGPoint(x: 114,y: 232), control1: CGPoint(x: 191,y: 212), control2: CGPoint(x: 158,y: 232))
        p.addLine(to: CGPoint(x: 0,y: 232)); p.closeSubpath()
        for (top,bottom,right) in [(CGFloat(43),CGFloat(90),CGFloat(104)),(132,187,108)] {
            p.move(to: CGPoint(x: 50,y: top)); p.addLine(to: CGPoint(x: right,y: top))
            let bulge: CGFloat = top == 43 ? 33 : 43
            p.addCurve(to: CGPoint(x: right,y: bottom), control1: CGPoint(x: right + bulge,y: top), control2: CGPoint(x: right + bulge,y: bottom))
            p.addLine(to: CGPoint(x: 50,y: bottom)); p.closeSubpath()
        }
    case "U":
        c.scaleBy(x: rect.width/202,y: rect.height/237)
        p.move(to: CGPoint(x: 0,y: 0)); p.addLine(to: CGPoint(x: 49,y: 0)); p.addLine(to: CGPoint(x: 49,y: 139))
        p.addCurve(to: CGPoint(x: 101,y: 188), control1: CGPoint(x: 49,y: 178), control2: CGPoint(x: 68,y: 188))
        p.addCurve(to: CGPoint(x: 153,y: 139), control1: CGPoint(x: 134,y: 188), control2: CGPoint(x: 153,y: 178))
        p.addLine(to: CGPoint(x: 153,y: 0)); p.addLine(to: CGPoint(x: 202,y: 0)); p.addLine(to: CGPoint(x: 202,y: 143))
        p.addCurve(to: CGPoint(x: 101,y: 237), control1: CGPoint(x: 202,y: 208), control2: CGPoint(x: 164,y: 237))
        p.addCurve(to: CGPoint(x: 0,y: 143), control1: CGPoint(x: 37,y: 237), control2: CGPoint(x: 0,y: 208))
        p.closeSubpath()
    case "H":
        c.scaleBy(x: rect.width/208,y: rect.height/232)
        polygon([(0,0),(50,0),(50,91),(158,91),(158,0),(208,0),(208,232),(158,232),(158,138),(50,138),(50,232),(0,232)])
    case "N":
        c.scaleBy(x: rect.width/211,y: rect.height/232)
        polygon([(0,0),(48,0),(162,149),(162,0),(211,0),(211,232),(163,232),(49,81),(49,232),(0,232)])
    case "E":
        c.scaleBy(x: rect.width/181,y: rect.height/232)
        polygon([(0,0),(181,0),(181,43),(49,43),(49,91),(165,91),(165,137),(49,137),(49,185),(181,185),(181,232),(0,232)])
    default: preconditionFailure("Unexpected wordmark letter")
    }
    c.addPath(p); c.setFillColor(ink); c.drawPath(using: character == "B" ? .eoFill : .fill)
    c.restoreGState()
}
func label(_ c: CGContext, _ text: String, x: CGFloat, y: CGFloat, size: CGFloat = 18, ink: CGColor = color(0x202020)) {
    let font = CTFontCreateWithName("Helvetica" as CFString, size, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): ink
    ]))
    c.saveGState(); c.translateBy(x: x, y: y + size); c.scaleBy(x: 1, y: -1)
    c.textMatrix = .identity; c.textPosition = .zero; CTLineDraw(line, c); c.restoreGState()
}

func mark(_ c: CGContext, in rect: CGRect, inverse: Bool) {
    c.saveGState(); c.translateBy(x: rect.minX, y: rect.minY); c.scaleBy(x: rect.width/950, y: rect.height/694)
    let cap = CGMutablePath()
    cap.move(to: CGPoint(x: 0,y: 275))
    cap.addCurve(to: CGPoint(x: 241,y: 0), control1: CGPoint(x: -3,y: 108), control2: CGPoint(x: 83,y: 0))
    cap.addCurve(to: CGPoint(x: 559,y: 35), control1: CGPoint(x: 333,y: 0), control2: CGPoint(x: 444,y: 18))
    cap.addCurve(to: CGPoint(x: 0,y: 275), control1: CGPoint(x: 306,y: 34), control2: CGPoint(x: 90,y: 80))
    cap.closeSubpath(); fill(c, cap, color(inverse ? 0xFFFFFF : 0x080808))
    let body = CGMutablePath()
    body.move(to: CGPoint(x: 6,y: 440))
    body.addCurve(to: CGPoint(x: 426,y: 78), control1: CGPoint(x: 6,y: 179), control2: CGPoint(x: 203,y: 93))
    body.addCurve(to: CGPoint(x: 764,y: 63), control1: CGPoint(x: 563,y: 69), control2: CGPoint(x: 695,y: 62))
    body.addCurve(to: CGPoint(x: 947,y: 250), control1: CGPoint(x: 881,y: 63), control2: CGPoint(x: 947,y: 144))
    body.addLine(to: CGPoint(x: 950,y: 361))
    body.addCurve(to: CGPoint(x: 626,y: 504), control1: CGPoint(x: 810,y: 381), control2: CGPoint(x: 721,y: 430))
    body.addCurve(to: CGPoint(x: 164,y: 676), control1: CGPoint(x: 521,y: 590), control2: CGPoint(x: 441,y: 638))
    body.addCurve(to: CGPoint(x: 7,y: 542), control1: CGPoint(x: 66,y: 692), control2: CGPoint(x: 9,y: 624))
    body.closeSubpath(); fill(c, body, color(0x080808))
    if inverse { stroke(c, body, color(0xFFFFFF, 0.94), 7) }
    let sweep = CGMutablePath(); sweep.move(to: CGPoint(x: 243,y: 694))
    sweep.addCurve(to: CGPoint(x: 636,y: 544), control1: CGPoint(x: 442,y: 663), control2: CGPoint(x: 523,y: 635))
    sweep.addCurve(to: CGPoint(x: 950,y: 395), control1: CGPoint(x: 737,y: 462), control2: CGPoint(x: 816,y: 412))
    sweep.addLine(to: CGPoint(x: 950,y: 519))
    sweep.addCurve(to: CGPoint(x: 785,y: 694), control1: CGPoint(x: 950,y: 617), control2: CGPoint(x: 878,y: 694))
    sweep.closeSubpath(); fill(c, sweep, red)
    let play = CGMutablePath(); play.move(to: CGPoint(x: 363,y: 230))
    play.addCurve(to: CGPoint(x: 409,y: 204), control1: CGPoint(x: 364,y: 205), control2: CGPoint(x: 385,y: 189))
    play.addLine(to: CGPoint(x: 610,y: 328))
    play.addCurve(to: CGPoint(x: 611,y: 389), control1: CGPoint(x: 636,y: 344), control2: CGPoint(x: 635,y: 372))
    play.addLine(to: CGPoint(x: 411,y: 507))
    play.addCurve(to: CGPoint(x: 364,y: 478), control1: CGPoint(x: 389,y: 518), control2: CGPoint(x: 364,y: 505))
    play.closeSubpath(); fill(c, play, color(0xFFFFFF))
    c.setFillColor(color(0xFFFFFF)); c.fill(CGRect(x: 790,y: 487,width: 41,height: 133)); c.fill(CGRect(x: 746,y: 532,width: 128,height: 42))
    c.restoreGState()
}
func wordmark(_ c: CGContext, in rect: CGRect, inverse: Bool) {
    c.saveGState(); c.translateBy(x: rect.minX, y: rect.minY); c.scaleBy(x: rect.width/1646, y: rect.height/332)
    mark(c, in: CGRect(x: 0,y: 41,width: 414,height: 291), inverse: inverse)
    let ink = color(inverse ? 0xFFFFFF : 0x080808)
    let letters: [(Character, CGRect)] = [
        ("B", CGRect(x: 510,y: 77,width: 191,height: 232)), ("U", CGRect(x: 721,y: 77,width: 202,height: 237)),
        ("H", CGRect(x: 960,y: 77,width: 208,height: 232)), ("N", CGRect(x: 1210,y: 77,width: 211,height: 232)),
        ("E", CGRect(x: 1464,y: 77,width: 181,height: 232))]
    for (character, box) in letters { letter(c, character, box, ink) }
    fill(c, CGPath(ellipseIn: CGRect(x: 757,y: 0,width: 52,height: 52), transform: nil), ink)
    fill(c, CGPath(ellipseIn: CGRect(x: 830,y: 0,width: 52,height: 52), transform: nil), ink)
    c.restoreGState()
}
func appIcon(_ c: CGContext) {
    let tile = rounded(CGRect(x: 64,y: 64,width: 896,height: 896), 202)
    c.saveGState(); c.setShadow(offset: CGSize(width: 0,height: -12), blur: 18, color: color(0,0.3)); fill(c, tile, color(0x151B23)); c.restoreGState()
    gradient(c, tile, [color(0x38424D),color(0x171D25),color(0x0B0F15)], CGPoint(x: 230,y: 65), CGPoint(x: 720,y: 960))
    stroke(c, rounded(CGRect(x: 67,y: 67,width: 890,height: 890), 199), color(0xD9E8F9,0.52), 5)
    stroke(c, rounded(CGRect(x: 74,y: 74,width: 876,height: 876), 193), color(0xFFFFFF,0.11), 2)
    mark(c, in: CGRect(x: 164,y: 256,width: 696,height: 508.5), inverse: true)
}
func documentIcon(_ c: CGContext) {
    let card = CGMutablePath(); card.move(to: CGPoint(x: 190,y: 52)); card.addLine(to: CGPoint(x: 731,y: 52))
    card.addCurve(to: CGPoint(x: 934,y: 259), control1: CGPoint(x: 786,y: 59), control2: CGPoint(x: 926,y: 198))
    card.addLine(to: CGPoint(x: 934,y: 866)); card.addQuadCurve(to: CGPoint(x: 824,y: 974), control: CGPoint(x: 934,y: 974))
    card.addLine(to: CGPoint(x: 198,y: 974)); card.addQuadCurve(to: CGPoint(x: 90,y: 864), control: CGPoint(x: 90,y: 974))
    card.addLine(to: CGPoint(x: 90,y: 174)); card.addQuadCurve(to: CGPoint(x: 190,y: 52), control: CGPoint(x: 90,y: 52)); card.closeSubpath()
    c.saveGState(); c.setShadow(offset: CGSize(width: 0,height: -11), blur: 17, color: color(0,0.35)); fill(c, card, color(0x091727)); c.restoreGState()
    gradient(c, card, [color(0x0A1B2B),color(0x243B53),color(0x090F19)], CGPoint(x: 300,y: 80), CGPoint(x: 600,y: 974))
    c.saveGState(); c.addPath(card); c.clip()
    // Supplied reference 12's scene-only crop; no title, extension or fake metadata.
    let scene = image(root.appendingPathComponent("reference/12_buehne_file_icon.webp")).cropping(to: CGRect(x: 110,y: 370,width: 1030,height: 430))!
    let sceneRect = CGRect(x: 90,y: 285,width: 844,height: 352.35)
    c.beginTransparencyLayer(auxiliaryInfo: nil)
    drawImage(c, scene, sceneRect)
    c.saveGState(); c.setBlendMode(.destinationIn)
    gradient(c, CGPath(rect: sceneRect,transform: nil), [color(0,0),color(0,1)],
        CGPoint(x: 500,y: 285), CGPoint(x: 500,y: 380))
    c.restoreGState(); c.endTransparencyLayer()
    let band = CGMutablePath(); band.move(to: CGPoint(x: 85,y: 638))
    band.addCurve(to: CGPoint(x: 934,y: 530), control1: CGPoint(x: 307,y: 530), control2: CGPoint(x: 520,y: 715))
    band.addLine(to: CGPoint(x: 960,y: 1000)); band.addLine(to: CGPoint(x: 70,y: 1000)); band.closeSubpath()
    gradient(c, band, [color(0x1D2633),color(0x080D14)], CGPoint(x: 500,y: 620), CGPoint(x: 500,y: 980))
    let seam = CGMutablePath(); seam.move(to: CGPoint(x: 85,y: 638)); seam.addCurve(to: CGPoint(x: 934,y: 530), control1: CGPoint(x: 307,y: 530), control2: CGPoint(x: 520,y: 715))
    stroke(c, seam, color(0xFFFFFF,0.95), 6)
    wordmark(c, in: CGRect(x: 155,y: 738,width: 714,height: 144), inverse: true)
    c.restoreGState()
    stroke(c, card, color(0xEAF3FF,0.9), 4)
    let badge = rounded(CGRect(x: 132,y: 113,width: 300,height: 88), 26)
    gradient(c, badge, [color(0x4A5B6F),color(0x172638)], CGPoint(x: 200,y: 114), CGPoint(x: 200,y: 202))
    stroke(c, badge, color(0xD8E9FF,0.55), 1.5)
    let film = CGRect(x: 155,y: 134,width: 43,height: 46)
    stroke(c, rounded(film, 3), color(0xFFFFFF), 4)
    c.setFillColor(color(0xFFFFFF))
    for y in stride(from: 139, through: 173, by: 10) { c.fill(CGRect(x: 158,y: y,width: 5,height: 4)); c.fill(CGRect(x: 190,y: y,width: 5,height: 4)) }
    label(c, "VIDEO", x: 215,y: 128,size: 48,ink: color(0xFFFFFF))
    let fold = CGMutablePath(); fold.move(to: CGPoint(x: 731,y: 52))
    fold.addCurve(to: CGPoint(x: 791,y: 239), control1: CGPoint(x: 781,y: 87), control2: CGPoint(x: 704,y: 220))
    fold.addCurve(to: CGPoint(x: 934,y: 259), control1: CGPoint(x: 850,y: 246), control2: CGPoint(x: 889,y: 218))
    fold.addCurve(to: CGPoint(x: 731,y: 52), control1: CGPoint(x: 915,y: 212), control2: CGPoint(x: 790,y: 72)); fold.closeSubpath()
    gradient(c, fold, [color(0xFFFFFF),color(0xCBD5E9),color(0x65708B),color(0xF9FCFF)], CGPoint(x: 747,y: 83), CGPoint(x: 910,y: 251))
    stroke(c, fold, color(0xFFFFFF,0.75), 2)
}

let entries = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]
for (name, draw) in [("AppIcon", appIcon), ("VideoDocument", documentIcon)] {
    let folder = work.appendingPathComponent("\(name).iconset")
    try fm.createDirectory(at: folder, withIntermediateDirectories: true)
    for (points, scale) in entries {
        let size = points * scale
        let output = raster(size,size) { c in c.scaleBy(x: CGFloat(size)/1024,y: CGFloat(size)/1024); draw(c) }
        let filename = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try png(output, folder.appendingPathComponent(filename))
    }
}
for inverse in [false,true] {
    pdf("BuehneMark-\(inverse ? "dark" : "light")", size: CGSize(width: 950,height: 694)) {
        mark($0, in: CGRect(x: 0,y: 0,width: 950,height: 694), inverse: inverse)
    }
    pdf("BuehneWordmark-\(inverse ? "dark" : "light")", size: CGSize(width: 1646,height: 332)) {
        wordmark($0, in: CGRect(x: 0,y: 0,width: 1646,height: 332), inverse: inverse)
    }
}

// Side-by-side visual receipts. All labels are proof annotations, not player UI.
let reference11 = image(root.appendingPathComponent("reference/11_buehne_play_mark.webp"))
let reference12 = image(root.appendingPathComponent("reference/12_buehne_file_icon.webp"))
let reference13 = image(root.appendingPathComponent("reference/13_buehne_wordmark.webp"))
for (name, reference, draw) in [("app",reference11,appIcon),("file",reference12,documentIcon)] {
    let sheet = raster(1440,850) { c in
        c.setFillColor(color(0xFAFAFF)); c.fill(CGRect(x: 0,y: 0,width: 1440,height: 850))
        label(c,"REFERENCE \(name == "app" ? "11 — play mark" : "12 — document")",x: 36,y: 24,size: 24)
        label(c,"AFTER — \(name == "app" ? "AppIcon.icns" : "VideoDocument.icns")",x: 760,y: 24,size: 24)
        if name == "app" { drawImage(c, reference, CGRect(x: 28,y: 140,width: 650,height: 433.3)) }
        else { drawImage(c, reference, CGRect(x: 40,y: 80,width: 650,height: 650)) }
        c.saveGState(); c.translateBy(x: 730,y: 58); c.scaleBy(x: 0.65,y: 0.65); draw(c); c.restoreGState()
        label(c,"BEFORE: no registered app/document artwork",x: 36,y: 762,size: 18)
        label(c,"16 / 32 / 64 / 128 / 256 / 512 / 1024 px, rendered directly from source",x: 36,y: 798,size: 18)
        for (index,size) in [16,32,64,128,256,512,1024].enumerated() {
            let thumb = raster(size,size) { ctx in ctx.scaleBy(x: CGFloat(size)/1024,y: CGFloat(size)/1024); draw(ctx) }
            drawImage(c, thumb, CGRect(x: 725 + CGFloat(index)*95,y: 726,width: CGFloat(min(size,80)),height: CGFloat(min(size,80))))
        }
    }
    try png(sheet,root.appendingPathComponent("reference/buehne-icons-\(name).png"))
}
let wordSheet = raster(1600,860) { c in
    c.setFillColor(color(0xFAFAFF)); c.fill(CGRect(x: 0,y: 0,width: 1600,height: 860))
    label(c,"REFERENCE 13",x: 40,y: 20,size: 24)
    drawImage(c,reference13,CGRect(x: 0,y: 50,width: 1600,height: 533.6))
    label(c,"AFTER — vector outlines, Helvetica Bold + circular umlauts",x: 40,y: 490,size: 24)
    wordmark(c,in: CGRect(x: 150,y: 550,width: 1300,height: 262.2),inverse: false)
}
try png(wordSheet,root.appendingPathComponent("reference/buehne-icons-wordmark.png"))

let oldNames: [BuehneGlyph:String] = [.volume:"speaker.wave.2.fill",.muted:"speaker.slash.fill",.backward:"backward.fill",.forward:"forward.fill",.play:"play.fill",.pause:"pause.fill",.floating:"arrow.down.right.and.arrow.up.left",.exitFloating:"arrow.up.left.and.arrow.down.right",.pictureInPicture:"pip.enter",.settings:"gearshape",.layout:"paintbrush.pointed.fill",.video:"photo",.audio:"waveform",.subtitles:"captions.bubble",.liquidGlass:"rectangle.on.rectangle"]
let ref18 = image(root.appendingPathComponent("reference/18_control_bar.webp"))
let ref14 = image(root.appendingPathComponent("reference/14_layout_panel_dark.webp"))
let ref17 = image(root.appendingPathComponent("reference/17_video_panel.webp"))
let ref16 = image(root.appendingPathComponent("reference/16_subtitles_panel.webp"))
let crops: [BuehneGlyph:(CGImage,CGRect)] = [
    .volume:(ref18,CGRect(x:178,y:246,width:44,height:38)), .backward:(ref18,CGRect(x:481,y:244,width:56,height:42)),
    .play:(ref18,CGRect(x:577,y:239,width:53,height:52)), .forward:(ref18,CGRect(x:671,y:244,width:57,height:42)),
    .pictureInPicture:(ref18,CGRect(x:900,y:245,width:40,height:39)), .settings:(ref18,CGRect(x:996,y:244,width:39,height:42)),
    .layout:(ref14,CGRect(x:1650,y:86,width:40,height:38)), .video:(ref14,CGRect(x:1780,y:86,width:38,height:38)),
    .audio:(ref14,CGRect(x:1828,y:86,width:38,height:38)), .subtitles:(ref14,CGRect(x:1873,y:86,width:42,height:38)),
    .theme:(ref14,CGRect(x:1371,y:174,width:34,height:34)), .liquidGlass:(ref14,CGRect(x:1368,y:226,width:40,height:34)),
    .messages:(ref14,CGRect(x:1380,y:272,width:32,height:28)), .menu:(ref14,CGRect(x:1380,y:307,width:32,height:28)),
    .sidebar:(ref14,CGRect(x:1380,y:342,width:32,height:28)), .fillWindow:(ref14,CGRect(x:1368,y:524,width:36,height:34)),
    .lockAspect:(ref14,CGRect(x:1368,y:571,width:36,height:34)), .aspect:(ref17,CGRect(x:1368,y:359,width:34,height:34)),
    .crop:(ref17,CGRect(x:1368,y:455,width:34,height:34)), .rotation:(ref17,CGRect(x:1368,y:544,width:36,height:34)),
    .speed:(ref17,CGRect(x:1368,y:688,width:36,height:34)),
    .primarySubtitles:(ref16,CGRect(x:1353,y:150,width:30,height:32)),
    .secondarySubtitles:(ref16,CGRect(x:1353,y:382,width:30,height:32))]
let glyphSheet = raster(1280,1440) { c in
    c.setFillColor(color(0xFAFAFF)); c.fill(CGRect(x: 0,y: 0,width: 1280,height: 1440))
    label(c,"GLYPH",x: 30,y: 20); label(c,"BEFORE (SF)",x: 280,y: 20)
    label(c,"AFTER / LIGHT",x: 480,y: 20); label(c,"AFTER / DARK",x: 700,y: 20); label(c,"REFERENCE 14–18",x: 950,y: 20)
    for (index,glyph) in BuehneGlyph.allCases.enumerated() {
        let y = CGFloat(62 + index * 49)
        label(c,glyph.rawValue,x: 30,y: y+9,size: 18)
        if let name = oldNames[glyph], let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 26,weight: .medium)) {
            var r = CGRect(x: 0,y: 0,width: 48,height: 38)
            if let cg = symbol.cgImage(forProposedRect: &r, context: nil, hints: nil) {
                let scale = min(44 / CGFloat(cg.width), 34 / CGFloat(cg.height))
                let width = CGFloat(cg.width) * scale
                let height = CGFloat(cg.height) * scale
                drawImage(c,cg,CGRect(x: 300 + (44 - width)/2,y: y+3 + (34 - height)/2,width: width,height: height))
            }
        } else { label(c,"—",x: 305,y: y+8) }
        for (x,inverse) in [(CGFloat(500),false),(CGFloat(730),true)] {
            c.setFillColor(color(inverse ? 0x202020 : 0xFAFAFF)); c.fill(CGRect(x: x-15,y: y,width: 90,height: 44))
            let path = glyph.path(in: CGRect(x: x+8,y: y+5,width: 34,height: 34)).cgPath
            c.addPath(path); c.setFillColor(color(inverse ? 0xFFFFFF : 0x000000)); c.drawPath(using: glyph.usesEvenOdd ? .eoFill : .fill)
        }
        if let (source,rect) = crops[glyph], let crop = source.cropping(to: rect) {
            let scale = min(60/rect.width,40/rect.height)
            drawImage(c,crop,CGRect(x: 1000,y: y,width: rect.width*scale,height: rect.height*scale))
        } else { label(c,"not visible / redacted",x: 940,y: y+12,size: 14) }
    }
}
try png(glyphSheet,root.appendingPathComponent("reference/buehne-icons-glyphs.png"))
print("ICON_RENDER_OK iconsets=2 pngs=20 vectorPDFs=4 comparisonPNGs=4 glyphs=\(BuehneGlyph.allCases.count)")
