import AppKit
import CoreGraphics
@testable import BuehneUI
import SwiftUI
import Testing

@Test func customGlyphsStayInsideOpticalGrid() {
    let grid = CGRect(x: 0, y: 0, width: 24, height: 24)
    for glyph in BuehneGlyph.allCases {
        let path = glyph.path(in: grid)
        #expect(!path.isEmpty, "\(glyph.rawValue) is empty")
        #expect(grid.insetBy(dx: -0.01, dy: -0.01).contains(path.boundingRect), "\(glyph.rawValue) escapes its optical grid: \(path.boundingRect)")
        let doubled = glyph.path(in: CGRect(x: 4, y: 7, width: 48, height: 48))
        #expect(abs(doubled.boundingRect.width - path.boundingRect.width * 2) < 0.01)
    }
}

@MainActor
@Test func customGlyphsHaveSolidTemplateInkAtBothScales() {
    for glyph in BuehneGlyph.allCases {
        for size in [CGFloat(16), 22, 36] {
            for scale in [CGFloat(1), 2] {
                for isLight in [true, false] {
                    let renderer = ImageRenderer(content: BuehneIcon(glyph, size: size)
                        .foregroundStyle(isLight ? Color.black : Color.white))
                    renderer.scale = scale
                    guard let image = renderer.cgImage else { Issue.record("No render: \(glyph)"); continue }
                    let pixels = rgba(image)
                    var maximumAlpha = 0
                    for i in stride(from: 0, to: pixels.count, by: 4) {
                        let alpha = Int(pixels[i + 3])
                        maximumAlpha = max(maximumAlpha, alpha)
                        if alpha > 128 {
                            let expected = isLight ? 0 : alpha // premultiplied white
                            #expect(abs(Int(pixels[i]) - expected) <= 1)
                            #expect(abs(Int(pixels[i+1]) - expected) <= 1)
                            #expect(abs(Int(pixels[i+2]) - expected) <= 1)
                        }
                    }
                    #expect(maximumAlpha > 200, "Faded/blank glyph \(glyph), \(size)pt @\(scale)x: \(maximumAlpha)")
                }
            }
        }
    }
}

@MainActor
@Test func wordmarkAndMarkPDFsLoadAndRenderInBothThemes() throws {
    for theme in [ColorScheme.light, .dark] {
        let renderer = ImageRenderer(content: BuehneWordmark(width: 280).environment(\.colorScheme, theme))
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        #expect(image.width == 560)
        let pixels = rgba(image)
        var ink = 0; var red = 0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            if pixels[i+3] > 230 { ink += 1 }
            if pixels[i] > 150 && pixels[i+1] < 50 && pixels[i+2] < 70 && pixels[i+3] > 230 { red += 1 }
        }
        #expect(ink > 2000, "Wordmark resource missing/blank in \(theme)")
        #expect(red > 100, "Swiss-red ribbon missing in \(theme)")
        let mark = ImageRenderer(content: BuehneBrandMark().environment(\.colorScheme, theme))
        #expect(mark.cgImage != nil)
    }
}

@MainActor private func rgba(_ image: CGImage) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    bytes.withUnsafeMutableBytes { storage in
        let context = CGContext(data: storage.baseAddress, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return bytes
}
