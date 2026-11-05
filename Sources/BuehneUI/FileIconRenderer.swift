import AppKit
import BuehneCore
import CoreGraphics
import CoreText
import Foundation

/// Document icon: the video frame fills a rounded page, a format pill sits top-left,
/// the page corner curls top-right, and a dark branded strip closes the bottom.
public enum FileIconRenderer {
    public static let canvas = 1024
    public static let curlFraction = 0.24
    public static let stripFraction = 0.30
    public static let marginFraction = 0.06

    public static func representations(frame: CGImage, extension ext: String) -> [CGImage] {
        guard let full = render(frame: frame, extension: ext, side: canvas) else { return [] }
        return FileIconPolicy.sizes.compactMap { side in
            side == canvas ? full : scaled(full, to: side)
        }
    }

    public static func iconRect(side: CGFloat) -> CGRect {
        let inset = side * marginFraction
        return CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
    }

    /// Cubic S from a higher left edge down to the right. CG y grows upward.
    public static func wavePoint(t: CGFloat, side: CGFloat) -> CGPoint {
        let icon = iconRect(side: side)
        let yLeft = icon.minY + icon.height * 0.40
        let yRight = icon.minY + icon.height * 0.27
        let p0 = CGPoint(x: icon.minX, y: yLeft)
        let p1 = CGPoint(x: icon.minX + icon.width * 0.36, y: yLeft - icon.height * 0.01)
        let p2 = CGPoint(x: icon.minX + icon.width * 0.64, y: yRight + icon.height * 0.012)
        let p3 = CGPoint(x: icon.maxX, y: yRight)
        return cubic(t, p0, p1, p2, p3)
    }

    public static func waveHighlightWidth(side: CGFloat) -> CGFloat {
        side * 5 / 1024
    }

    public static func render(frame: CGImage, extension ext: String, side: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let s = CGFloat(side)
        let icon = iconRect(side: s)
        let radius = icon.width * 0.20
        let page = CGPath(roundedRect: icon, cornerWidth: radius, cornerHeight: radius, transform: nil)

        ctx.clear(CGRect(x: 0, y: 0, width: s, height: s))
        ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.045, color: CGColor(gray: 0, alpha: 0.38))
        ctx.addPath(page)
        ctx.setFillColor(CGColor(gray: 0.04, alpha: 1))
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        ctx.saveGState()
        ctx.addPath(page)
        ctx.clip()
        drawFrame(frame, in: icon, ctx: ctx)
        drawDarkening(in: icon, ctx: ctx)
        drawStrip(in: icon, side: s, ctx: ctx)
        drawCurl(in: icon, side: s, ctx: ctx)
        drawBadge(ext, in: icon, side: s, ctx: ctx)
        ctx.restoreGState()
        drawGlassRim(page: page, icon: icon, side: s, ctx: ctx)
        drawRedRimGlow(page: page, icon: icon, side: s, ctx: ctx)
        return ctx.makeImage()
    }

    public static func nsImage(frame: CGImage, extension ext: String) -> NSImage? {
        let reps = representations(frame: frame, extension: ext)
        guard let first = reps.first else { return nil }
        let image = NSImage(size: NSSize(width: first.width, height: first.height))
        for cg in reps {
            image.addRepresentation(NSBitmapImageRep(cgImage: cg))
        }
        return image
    }

    public static func pngData(_ image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    private static func drawFrame(_ frame: CGImage, in icon: CGRect, ctx: CGContext) {
        let fw = CGFloat(frame.width)
        let fh = CGFloat(frame.height)
        guard fw > 0, fh > 0 else { return }
        let scale = max(icon.width / fw, icon.height / fh)
        let w = fw * scale
        let h = fh * scale
        let dest = CGRect(x: icon.midX - w / 2, y: icon.midY - h / 2, width: w, height: h)
        ctx.interpolationQuality = .high
        ctx.draw(frame, in: dest)
    }

    private static func drawDarkening(in icon: CGRect, ctx: CGContext) {
        let colors = [
            CGColor(red: 0, green: 0, blue: 0, alpha: 0.05),
            CGColor(red: 0, green: 0, blue: 0, alpha: 0.32),
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: icon.midX, y: icon.maxY),
            end: CGPoint(x: icon.midX, y: icon.minY),
            options: []
        )
    }

    private static func drawCurl(in icon: CGRect, side: CGFloat, ctx: CGContext) {
        let curl = side * curlFraction
        let fold = CGPoint(x: icon.maxX - curl, y: icon.maxY)
        let tip = CGPoint(x: icon.maxX, y: icon.maxY - curl)
        let bow = CGPoint(x: icon.maxX - curl * 0.62, y: icon.maxY - curl * 0.62)
        let flap = CGMutablePath()
        flap.move(to: fold)
        flap.addLine(to: CGPoint(x: icon.maxX, y: icon.maxY))
        flap.addLine(to: tip)
        flap.addQuadCurve(to: fold, control: bow)
        flap.closeSubpath()

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: -side * 0.006, height: -side * 0.01), blur: side * 0.02, color: CGColor(gray: 0, alpha: 0.32))
        ctx.addPath(flap)
        ctx.clip()
        let colors = [
            CGColor(red: 1, green: 1, blue: 1, alpha: 1),
            CGColor(red: 0.78, green: 0.82, blue: 0.88, alpha: 1),
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: icon.maxX, y: icon.maxY), end: bow, options: [])
        }
        ctx.restoreGState()
        ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.55))
        ctx.setLineWidth(max(1, side * 0.004))
        ctx.move(to: fold)
        ctx.addQuadCurve(to: tip, control: bow)
        ctx.strokePath()
    }

    private static func drawStrip(in icon: CGRect, side: CGFloat, ctx: CGContext) {
        let start = wavePoint(t: 0, side: side)
        let end = wavePoint(t: 1, side: side)
        let c1 = CGPoint(x: icon.minX + icon.width * 0.36, y: start.y - icon.height * 0.01)
        let c2 = CGPoint(x: icon.minX + icon.width * 0.64, y: end.y + icon.height * 0.012)
        let fill = CGMutablePath()
        fill.move(to: CGPoint(x: icon.minX, y: icon.minY))
        fill.addLine(to: CGPoint(x: icon.maxX, y: icon.minY))
        fill.addLine(to: end)
        fill.addCurve(to: start, control1: c2, control2: c1)
        fill.closeSubpath()
        ctx.addPath(fill)
        ctx.setFillColor(CGColor(red: 0.03, green: 0.04, blue: 0.07, alpha: 0.96))
        ctx.fillPath()

        let wave = CGMutablePath()
        wave.move(to: start)
        wave.addCurve(to: end, control1: c1, control2: c2)
        ctx.addPath(wave)
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.96))
        ctx.setLineWidth(max(1, waveHighlightWidth(side: side)))
        ctx.setLineCap(.round)
        ctx.strokePath()
        drawBrand(in: icon, side: side, ctx: ctx)
    }

    private static func drawRedRimGlow(page: CGPath, icon: CGRect, side: CGFloat, ctx: CGContext) {
        ctx.saveGState()
        ctx.addPath(page)
        ctx.setLineWidth(side * 0.02)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        let space = CGColorSpaceCreateDeviceRGB()
        let clear = CGColor(red: 1, green: 0.08, blue: 0.1, alpha: 0)
        let red = CGColor(red: 1, green: 0.08, blue: 0.12, alpha: 0.9)
        if let glow = CGGradient(colorsSpace: space, colors: [red, clear] as CFArray, locations: [0, 1]) {
            let center = CGPoint(x: icon.minX + icon.width * 0.08, y: icon.minY + icon.height * 0.04)
            ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: side * 0.42, options: [])
        }
        ctx.restoreGState()
    }

    private static func drawGlassRim(page: CGPath, icon: CGRect, side: CGFloat, ctx: CGContext) {
        ctx.saveGState()
        ctx.addPath(page)
        ctx.setLineWidth(side * 0.016)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.78))
        ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        let space = CGColorSpaceCreateDeviceRGB()
        let clear = CGColor(red: 0.4, green: 0.7, blue: 1, alpha: 0)
        let blue = CGColor(red: 0.45, green: 0.75, blue: 1, alpha: 0.95)
        if let glow = CGGradient(colorsSpace: space, colors: [blue, clear] as CFArray, locations: [0, 1]) {
            let center = CGPoint(x: icon.minX + icon.width * 0.06, y: icon.maxY - icon.height * 0.04)
            ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: side * 0.4, options: [])
        }
        ctx.restoreGState()
    }

    private static func drawBadge(_ ext: String, in icon: CGRect, side: CGFloat, ctx: CGContext) {
        let label = String(ext.uppercased().prefix(4))
        let height = side * 0.096
        let width = side * 0.30
        let rect = CGRect(x: icon.minX + side * 0.04, y: icon.maxY - side * 0.04 - height, width: width, height: height)
        let pill = CGPath(roundedRect: rect, cornerWidth: height / 2, cornerHeight: height / 2, transform: nil)
        ctx.addPath(pill)
        ctx.setFillColor(CGColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 0.72))
        ctx.fillPath()
        ctx.addPath(pill)
        ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.42))
        ctx.setLineWidth(max(1, side * 0.003))
        ctx.strokePath()
        drawFilm(in: CGRect(x: rect.minX + height * 0.28, y: rect.minY + height * 0.22, width: height * 0.62, height: height * 0.56), ctx: ctx)
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, side * 0.048, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: label, attributes: attrs))
        ctx.textPosition = CGPoint(x: rect.minX + height * 1.05, y: rect.midY - side * 0.016)
        CTLineDraw(line, ctx)
    }

    private static func drawFilm(in rect: CGRect, ctx: CGContext) {
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(rect)
        ctx.setFillColor(CGColor(gray: 0.1, alpha: 1))
        let hole = rect.height * 0.16
        for i in 0..<3 {
            let x = rect.minX + rect.width * (0.16 + CGFloat(i) * 0.28)
            ctx.fill(CGRect(x: x, y: rect.maxY - hole * 1.2, width: hole, height: hole))
            ctx.fill(CGRect(x: x, y: rect.minY + hole * 0.25, width: hole, height: hole))
        }
    }

    private static func drawBrand(in icon: CGRect, side: CGFloat, ctx: CGContext) {
        let wordW = icon.width * 0.75
        let wordH = wordW * 332 / 1646
        let stripH = icon.height * stripFraction
        let originX = icon.midX - wordW / 2
        let originY = icon.minY + (stripH - wordH) / 2
        if let word = pdf("BuehneWordmark-dark", width: wordW, height: wordH) {
            ctx.draw(word, in: CGRect(x: originX, y: originY, width: wordW, height: wordH))
        }
    }

    private static func cubic(_ t: CGFloat, _ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) -> CGPoint {
        let u = 1 - t
        let a = u * u * u
        let b = 3 * u * u * t
        let c = 3 * u * t * t
        let d = t * t * t
        return CGPoint(
            x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
            y: a * p0.y + b * p1.y + c * p2.y + d * p3.y
        )
    }

    private static func pdf(_ name: String, width: CGFloat, height: CGFloat) -> CGImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "pdf"),
              let doc = CGPDFDocument(url as CFURL),
              let page = doc.page(at: 1) else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let w = max(2, Int(width))
        let h = max(2, Int(height))
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
        let box = page.getBoxRect(.mediaBox)
        ctx.scaleBy(x: CGFloat(w) / box.width, y: CGFloat(h) / box.height)
        ctx.drawPDFPage(page)
        return ctx.makeImage()
    }

    private static func scaled(_ image: CGImage, to side: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        return ctx.makeImage()
    }
}
