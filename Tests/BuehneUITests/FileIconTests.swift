import AppKit
import BuehneCore
import BuehneEngine
import BuehneUI
import CoreGraphics
import Foundation
import Testing

@Test func brandedIconStringsExistInSixLanguages() {
    #expect(L10n.text(.brandedFileIcons, language: "en") == "Branded file icons")
    #expect(L10n.text(.brandedFileIcons, language: "de") == "Markierte Dateisymbole")
    #expect(L10n.text(.brandedFileIcons, language: "fr") == "Icônes de fichier marquées")
    #expect(L10n.text(.brandedFileIcons, language: "it") == "Icone file con marchio")
    #expect(L10n.text(.brandedFileIcons, language: "ru") == "Фирменные значки файлов")
    #expect(L10n.text(.brandedFileIcons, language: "es") == "Iconos de archivo con marca")
    #expect(L10n.text(.removeBrandedIcons, language: "en") == "Remove all branded icons")
    #expect(L10n.text(.removeBrandedIcons, language: "ru") == "Удалить все фирменные значки")
}

@Test func waveIsOneFallingSWithAFivePointHighlight() {
    let side: CGFloat = 1024
    let width = FileIconRenderer.waveHighlightWidth(side: side)
    #expect(width >= 4 && width <= 6)
    var ys: [CGFloat] = []
    for step in 0...16 {
        ys.append(FileIconRenderer.wavePoint(t: CGFloat(step) / 16, side: side).y)
    }
    #expect(ys[0] > ys[16] + side * 0.04)
    for index in 0..<(ys.count - 1) {
        #expect(ys[index] > ys[index + 1])
    }
    #expect(FileIconRenderer.stripFraction == 0.30)
    #expect(FileIconRenderer.marginFraction > 0)
}

@Test func renderedIconHasCurlBadgeStripAndBrandOnSampleVideos() throws {
    let scratch = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("buehne-fileicon-scratch", isDirectory: true)
    #expect(!scratch.path.contains("Ström"))
    #expect(!scratch.path.contains("/Documents/"))
    try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    let mp4 = scratch.appendingPathComponent("sample.mp4")
    let mkv = scratch.appendingPathComponent("sample.mkv")
    let avi = scratch.appendingPathComponent("sample.avi")
    try makeVideo(mp4, codec: ["-c:v", "libx264", "-pix_fmt", "yuv420p"])
    try makeVideo(mkv, codec: ["-c:v", "libx264", "-c:a", "aac"])
    try makeVideo(avi, codec: ["-c:v", "mpeg4"])
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    for (url, name) in [(mp4, "mp4"), (mkv, "mkv"), (avi, "avi")] {
        let grabbed = try VideoFrameGrab.cgImage(for: url)
        let grabbedSample = pixel(grabbed, xFraction: 0.5, yFromTop: 0.4)
        if name == "mp4" {
            #expect(grabbedSample.r + grabbedSample.g + grabbedSample.b > 40, "mp4 grab should keep the gradient frame \(grabbedSample)")
        }
        let frame = gradientFrame(width: 640, height: 360)
        let reps = FileIconRenderer.representations(frame: frame, extension: name)
        #expect(reps.map(\.width) == FileIconPolicy.sizes)
        guard let image = reps.first else {
            Issue.record("no render for \(name)")
            continue
        }
        let leftPoster = pixel(image, xFraction: 0.30, yFromTop: 0.36)
        let rightPoster = pixel(image, xFraction: 0.70, yFromTop: 0.36)
        let strip = pixel(image, xFraction: 0.14, yFromTop: 0.84)
        let curl = pixel(image, xFraction: 0.84, yFromTop: 0.10)
        let badge = pixel(image, xFraction: 0.18, yFromTop: 0.14)
        #expect(abs(leftPoster.r - rightPoster.r) + abs(leftPoster.b - rightPoster.b) > 20, "poster should be a gradient, not a flat field \(name) \(leftPoster) \(rightPoster)")
        #expect(leftPoster.r + leftPoster.g + leftPoster.b > 40, "poster should fill the page \(name) \(leftPoster)")
        #expect(strip.r + strip.g + strip.b < 160, "bottom strip should be dark \(name) \(strip)")
        #expect(curl.r > 170 && curl.g > 170 && curl.b > 170, "page curl should be light \(name) \(curl)")
        #expect(hasDarkPixel(image, x0: 0.10, y0: 0.09, x1: 0.32, y1: 0.17), "format pill should be dark glass \(name)")
        #expect(hasLightPixel(image, x0: 0.10, y0: 0.08, x1: 0.34, y1: 0.18), "format label should be light \(name)")
        let waveY = 1 - FileIconRenderer.wavePoint(t: 0.5, side: CGFloat(image.width)).y / CGFloat(image.height)
        let wave = whitest(image, xFraction: 0.5, yFromTop: waveY, radius: 4)
        #expect(wave.r > 180 && abs(wave.r - wave.g) < 40, "wave highlight should be a thin white line \(name) \(wave)")
        let below = pixel(image, xFraction: 0.5, yFromTop: min(0.98, waveY + 14 / Double(image.height)))
        #expect(below.r < 120, "no thick red outline under the wave \(name) \(below)")
        #expect(hasRedPixel(image, x0: 0.05, y0: 0.82, x1: 0.40, y1: 0.98), "red glow on the lower-left rim \(name)")
        #expect(alpha(image, xFraction: 0.01, yFromTop: 0.01) == 0, "margin outside the page should be clear \(name)")
        let out = root.appendingPathComponent("reference/buehne-v6-fileicon-\(name).png")
        if let data = FileIconRenderer.pngData(image) {
            try data.write(to: out)
        }
    }
}

@Test func setIconDoesNotChangeFileBytesAndRemoveClearsIt() throws {
    let scratch = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("buehne-fileicon-apply", isDirectory: true)
    #expect(!scratch.path.contains("Ström"))
    try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    let mp4 = scratch.appendingPathComponent("apply.mp4")
    try makeVideo(mp4, codec: ["-c:v", "libx264", "-pix_fmt", "yuv420p"])
    let before = try Data(contentsOf: mp4)
    let cacheURL = scratch.appendingPathComponent("cache.json")
    let cache = FileIconCache(url: cacheURL)
    let defaults = UserDefaults(suiteName: "ch.oskarreus.buehne.fileicon.test")!
    defaults.removePersistentDomain(forName: "ch.oskarreus.buehne.fileicon.test")
    let first = FileIconApply.decorate(url: mp4, defaults: defaults, cache: cache, respectSetting: true)
    #expect(first == .decorated)
    let after = try Data(contentsOf: mp4)
    #expect(after == before)
    #expect(resourceForkSize(mp4) > 0)
    let second = FileIconApply.decorate(url: mp4, defaults: defaults, cache: cache, respectSetting: true)
    #expect(second == .skipped("cached"))
    #expect(FileIconApply.remove(url: mp4, cache: cache))
    #expect(cache.token(for: mp4.path) == nil)
    let removed = try Data(contentsOf: mp4)
    #expect(removed == before)
}

private func makeVideo(_ url: URL, codec: [String]) throws {
    if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    let ffmpeg = "/opt/homebrew/bin/ffmpeg"
    let process = Process()
    process.executableURL = URL(fileURLWithPath: ffmpeg)
    process.arguments = ["-y", "-f", "lavfi", "-i", "color=c=black:s=320x180:d=1,geq=r='40+180*X/W+16*sin(Y/7)':g='24+50*Y/H+12*sin(X/5)':b='18+130*(H-Y)/H+14*sin(X/4)'", "-f", "lavfi", "-i", "anullsrc=r=48000:cl=mono", "-shortest"] + codec + ["-t", "1", url.path]
    let pipe = Pipe()
    process.standardError = pipe
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 {
        let message = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "ffmpeg failed"
        throw NSError(domain: "ffmpeg", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: message])
    }
}

private func pixel(_ image: CGImage, xFraction: Double, yFromTop: Double) -> (r: Int, g: Int, b: Int) {
    let width = image.width
    let height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    bytes.withUnsafeMutableBytes { raw in
        guard let ctx = CGContext(
            data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    let x = min(width - 1, max(0, Int(Double(width) * xFraction)))
    let y = min(height - 1, max(0, Int(Double(height) * yFromTop)))
    let i = (y * width + x) * 4
    return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
}

private func whitest(_ image: CGImage, xFraction: Double, yFromTop: Double, radius: Int) -> (r: Int, g: Int, b: Int) {
    var best = pixel(image, xFraction: xFraction, yFromTop: yFromTop)
    var bestSum = best.r + best.g + best.b
    for delta in -radius...radius {
        let sample = pixel(image, xFraction: xFraction, yFromTop: yFromTop + Double(delta) / Double(image.height))
        let sum = sample.r + sample.g + sample.b
        if sum > bestSum {
            best = sample
            bestSum = sum
        }
    }
    return best
}

private func hasDarkPixel(_ image: CGImage, x0: Double, y0: Double, x1: Double, y1: Double) -> Bool {
    let xStart = Int(Double(image.width) * x0)
    let xEnd = Int(Double(image.width) * x1)
    let yStart = Int(Double(image.height) * y0)
    let yEnd = Int(Double(image.height) * y1)
    for y in stride(from: yStart, to: yEnd, by: 4) {
        for x in stride(from: xStart, to: xEnd, by: 4) {
            let sample = pixel(image, xFraction: Double(x) / Double(image.width), yFromTop: Double(y) / Double(image.height))
            if sample.r + sample.g + sample.b < 160 { return true }
        }
    }
    return false
}

private func hasRedPixel(_ image: CGImage, x0: Double, y0: Double, x1: Double, y1: Double) -> Bool {
    let xStart = Int(Double(image.width) * x0)
    let xEnd = Int(Double(image.width) * x1)
    let yStart = Int(Double(image.height) * y0)
    let yEnd = Int(Double(image.height) * y1)
    for y in stride(from: yStart, to: yEnd, by: 6) {
        for x in stride(from: xStart, to: xEnd, by: 6) {
            let sample = pixel(image, xFraction: Double(x) / Double(image.width), yFromTop: Double(y) / Double(image.height))
            if sample.r > 80 && sample.r > sample.b + 25 { return true }
        }
    }
    return false
}

private func gradientFrame(width: Int, height: Int) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    guard let data = ctx.data else { return ctx.makeImage()! }
    let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let xf = Double(x) / Double(width)
            let yf = Double(height - 1 - y) / Double(height)
            let n = sin(Double(x) / 5) * 14 + sin(Double(y) / 7) * 10
            let i = (y * width + x) * 4
            pixels[i] = UInt8(max(0, min(255, 40 + 180 * xf + n)))
            pixels[i + 1] = UInt8(max(0, min(255, 24 + 50 * yf + n * 0.4)))
            pixels[i + 2] = UInt8(max(0, min(255, 18 + 130 * (1 - yf) + n * 0.3)))
            pixels[i + 3] = 255
        }
    }
    return ctx.makeImage()!
}

private func alpha(_ image: CGImage, xFraction: Double, yFromTop: Double) -> Int {
    let width = image.width
    let height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    bytes.withUnsafeMutableBytes { raw in
        guard let ctx = CGContext(
            data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    let x = min(width - 1, max(0, Int(Double(width) * xFraction)))
    let y = min(height - 1, max(0, Int(Double(height) * yFromTop)))
    return Int(bytes[(y * width + x) * 4 + 3])
}

private func hasLightPixel(_ image: CGImage, x0: Double, y0: Double, x1: Double, y1: Double) -> Bool {
    let xStart = Int(Double(image.width) * x0)
    let xEnd = Int(Double(image.width) * x1)
    let yStart = Int(Double(image.height) * y0)
    let yEnd = Int(Double(image.height) * y1)
    for y in stride(from: yStart, to: yEnd, by: 4) {
        for x in stride(from: xStart, to: xEnd, by: 4) {
            let sample = pixel(image, xFraction: Double(x) / Double(image.width), yFromTop: Double(y) / Double(image.height))
            if sample.r > 200 && sample.g > 200 { return true }
        }
    }
    return false
}

private func resourceForkSize(_ url: URL) -> Int {
    url.withUnsafeFileSystemRepresentation { fs -> Int in
        guard let fs else { return -1 }
        return getxattr(fs, "com.apple.ResourceFork", nil, 0, 0, 0)
    }
}
