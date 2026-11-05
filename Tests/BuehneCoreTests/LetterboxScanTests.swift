import Foundation
import Testing
import BuehneCore

@Test func letterboxScanUsesThePictureBounds() {
    let width = 20
    let height = 12
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    for y in 3..<9 {
        for x in 2..<18 {
            let i = (y * width + x) * 4
            pixels[i] = 200
            pixels[i + 1] = 200
            pixels[i + 2] = 200
            pixels[i + 3] = 255
        }
    }
    let bounds = pixels.withUnsafeBufferPointer { buf in
        LetterboxScan.bounds(width: width, height: height, bytesPerRow: width * 4, pixels: buf.baseAddress!)
    }
    #expect(bounds.x == 2)
    #expect(bounds.y == 3)
    #expect(bounds.width == 16)
    #expect(bounds.height == 6)
}

@Test func letterboxScanDropsAOnePixelFringe() {
    let width = 8
    let height = 12
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    for y in 1..<11 {
        for x in 0..<width {
            let i = (y * width + x) * 4
            let level: UInt8 = (y == 1 || y == 10) ? 30 : 200
            pixels[i] = level
            pixels[i + 1] = level
            pixels[i + 2] = level
            pixels[i + 3] = 255
        }
    }
    let bounds = pixels.withUnsafeBufferPointer { buf in
        LetterboxScan.bounds(width: width, height: height, bytesPerRow: width * 4, pixels: buf.baseAddress!)
    }
    #expect(bounds.y == 2)
    #expect(bounds.height == 8)
    #expect(bounds.width == width)
    #expect(bounds.height * 2 >= height)
}

@Test func letterboxScanKeepsRealBlackBars() {
    let width = 24
    let height = 16
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    for y in 3..<13 {
        for x in 0..<width {
            let i = (y * width + x) * 4
            pixels[i] = 210
            pixels[i + 1] = 180
            pixels[i + 2] = 40
            pixels[i + 3] = 255
        }
    }
    let decision = pixels.withUnsafeBufferPointer { buf in
        LetterboxScan.decide(width: width, height: height, bytesPerRow: width * 4, pixels: buf.baseAddress!)
    }
    #expect(decision.nearlyDark == false)
    #expect(decision.bounds.y == 3)
    #expect(decision.bounds.height == 10)
    #expect(decision.bounds.width == width)
}

@Test func letterboxScanIgnoresAnAlmostDarkFrame() {
    let width = 32
    let height = 16
    var pixels = [UInt8](repeating: 4, count: width * height * 4)
    let spot = (8 * width + 16) * 4
    pixels[spot] = 220
    pixels[spot + 1] = 220
    pixels[spot + 2] = 220
    pixels[spot + 3] = 255
    let decision = pixels.withUnsafeBufferPointer { buf in
        LetterboxScan.decide(width: width, height: height, bytesPerRow: width * 4, pixels: buf.baseAddress!)
    }
    #expect(decision.nearlyDark)
    #expect(decision.bounds.width == width)
    #expect(decision.bounds.height == height)
}

@Test func letterboxScanDoesNotCropDimPictureContent() {
    let width = 20
    let height = 12
    var pixels = [UInt8](repeating: 12, count: width * height * 4)
    for y in 2..<10 {
        for x in 2..<18 {
            let i = (y * width + x) * 4
            pixels[i] = 160
            pixels[i + 1] = 140
            pixels[i + 2] = 90
            pixels[i + 3] = 255
        }
    }
    let bounds = pixels.withUnsafeBufferPointer { buf in
        LetterboxScan.bounds(width: width, height: height, bytesPerRow: width * 4, pixels: buf.baseAddress!)
    }
    #expect(bounds.x == 0)
    #expect(bounds.y == 0)
    #expect(bounds.width == width)
    #expect(bounds.height == height)
}

@Test func letterboxScanRefusesASliver() {
    let width = 16
    let height = 16
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    for y in 6..<10 {
        for x in 0..<width {
            let i = (y * width + x) * 4
            pixels[i] = 200
            pixels[i + 1] = 200
            pixels[i + 2] = 200
            pixels[i + 3] = 255
        }
    }
    let bounds = pixels.withUnsafeBufferPointer { buf in
        LetterboxScan.bounds(width: width, height: height, bytesPerRow: width * 4, pixels: buf.baseAddress!)
    }
    #expect(bounds.width == width)
    #expect(bounds.height == height)
}

@Test func letterboxScanWaitsForSeveralFrames() {
    let crop = PictureBounds(x: 0, y: 2, width: 20, height: 8)
    let sliver = PictureBounds(x: 0, y: 5, width: 20, height: 2)
    #expect(LetterboxScan.agreed([crop, crop], width: 20, height: 12) == nil)
    #expect(LetterboxScan.agreed([crop, crop, crop], width: 20, height: 12)?.height == 8)
    #expect(LetterboxScan.agreed([sliver, sliver, sliver], width: 20, height: 12) == nil)
}
