import AVFoundation
import BuehneCore
import Cmpv
import CoreGraphics
import Foundation

public enum VideoFrameGrabError: Error, Equatable {
    case noFrame(String)
}

/// One picture from a video, about 10% in. Native containers use AVAssetImageGenerator.
/// MKV, AVI, and anything AVFoundation cannot open use a libmpv frame.
public enum VideoFrameGrab {
    public static func cgImage(for url: URL) throws -> CGImage {
        let ext = url.pathExtension.lowercased()
        if EngineRouter.avFoundationExtensions.contains(ext), let image = avImage(url) {
            return image
        }
        if let image = avImage(url) { return image }
        return try mpvImage(url)
    }

    private static func avImage(_ url: URL) -> CGImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1280, height: 720)
        let seconds = asset.duration.seconds
        let at = CMTime(seconds: FileIconPolicy.frameSeconds(duration: seconds.isFinite ? seconds : nil), preferredTimescale: 600)
        return try? generator.copyCGImage(at: at, actualTime: nil)
    }

    private static func mpvImage(_ url: URL) throws -> CGImage {
        var err = [CChar](repeating: 0, count: 512)
        guard let box = buehne_mpv_open_ex(url.path, "203", 1, &err, Int32(err.count)) else {
            throw VideoFrameGrabError.noFrame(String(cString: err))
        }
        defer { buehne_mpv_close(box) }
        var time = 0.0
        var duration = 0.0
        var paused: Int32 = 0
        var width: Int32 = 0
        var height: Int32 = 0
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            _ = buehne_mpv_poll(box, &time, &duration, &paused, &width, &height, &err, Int32(err.count))
            if duration > 0.05 && width > 2 { break }
            Thread.sleep(forTimeInterval: 0.05)
        }
        buehne_mpv_seek(box, FileIconPolicy.frameSeconds(duration: duration > 0 ? duration : nil))
        let sideW = 640
        let sideH = 360
        var pixels = [UInt16](repeating: 0, count: sideW * sideH * 4)
        var rendered: CGImage?
        let renderDeadline = Date().addingTimeInterval(4)
        while Date() < renderDeadline {
            _ = buehne_mpv_poll(box, &time, &duration, &paused, &width, &height, &err, Int32(err.count))
            let rc = pixels.withUnsafeMutableBytes { raw in
                buehne_mpv_render_linear(box, Int32(sideW), Int32(sideH), raw.baseAddress, &err, Int32(err.count))
            }
            if rc == 0, let image = imageFromHalf(pixels, width: sideW, height: sideH), !isMostlyBlack(image) {
                rendered = image
                break
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        guard let rendered else { throw VideoFrameGrabError.noFrame(String(cString: err)) }
        return rendered
    }

    private static func imageFromHalf(_ pixels: [UInt16], width: Int, height: Int) -> CGImage? {
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeBytes { raw in
            let halves = raw.bindMemory(to: Float16.self)
            for i in 0..<(width * height) {
                let r = min(1, max(0, Float(halves[i * 4])))
                let g = min(1, max(0, Float(halves[i * 4 + 1])))
                let b = min(1, max(0, Float(halves[i * 4 + 2])))
                rgba[i * 4] = UInt8(r * 255)
                rgba[i * 4 + 1] = UInt8(g * 255)
                rgba[i * 4 + 2] = UInt8(b * 255)
                rgba[i * 4 + 3] = 255
            }
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &rgba,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        return ctx.makeImage()
    }

    private static func isMostlyBlack(_ image: CGImage) -> Bool {
        guard let data = image.dataProvider?.data as Data? else { return true }
        let stride = max(image.bytesPerRow, 4)
        var sum = 0
        let samples = 16
        for i in 0..<samples {
            let y = (image.height * (i + 1)) / (samples + 1)
            let x = image.width / 2
            let offset = y * stride + x * 4
            if offset + 2 < data.count {
                sum += Int(data[offset]) + Int(data[offset + 1]) + Int(data[offset + 2])
            }
        }
        return sum < samples * 12
    }
}
