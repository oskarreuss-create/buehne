import BuehneCore
import Cmpv
import Foundation
import IOSurface

public struct RenderedFrame: @unchecked Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let bgra: Data

    public init(width: Int, height: Int, bgra: Data) {
        self.width = width
        self.height = height
        self.bgra = bgra
    }
}

@MainActor
public final class LibmpvEngine: PlaybackEngine {
    public let kind: EngineKind = .libmpv
    public let surface = EDRSurface()
    public var displayPeakNits = 1000.0
    public private(set) var hdrReport = ""
    public var presentedFrames: Int { surface.presentedFrames }
    public private(set) var frame: RenderedFrame?
    private var box: OpaquePointer?
    private var loadedTracks = MediaTracks.empty
    private var failure: String?
    private var paused = true
    private var time: Double = 0
    private var duration: Double = 0
    private var volume = 1.0
    private var rate = 1.0
    private var coded = VideoSize(width: 0, height: 0)
    private var picture: PictureBounds?
    private var seekTarget: (value: Double, at: Date)?
    private var volumeCheck = 0
    private var rateFlush: Task<Void, Never>?
    private var votes: [PictureBounds] = []
    private var pictureSpace = VideoSize(width: 0, height: 0)
    private var scanAttempts = 0
    private var aspectName = "fit"
    private var cropName = "none"
    private var rotationDegrees = 0
    private var detectBars = true
    public init() {}

    public func setDetectBars(_ enabled: Bool) {
        if enabled == detectBars { return }
        detectBars = enabled
        picture = nil
        votes.removeAll()
        pictureSpace = VideoSize(width: 0, height: 0)
        scanAttempts = 0
        // The crop lives in the presented picture, so switching off brings the black bars back.
        surface.cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    private func applyDetectedCrop(box: OpaquePointer, codedW: Int, codedH: Int) {
        guard let picture, pictureSpace.width > 1, pictureSpace.height > 1 else { return }
        let rect = CGRect(
            x: Double(picture.x) / pictureSpace.width,
            y: Double(picture.y) / pictureSpace.height,
            width: Double(picture.width) / pictureSpace.width,
            height: Double(picture.height) / pictureSpace.height
        )
        guard rect.width < 0.999 || rect.height < 0.999 else { return }
        surface.cropRect = rect
    }

    public func open(_ url: URL) async throws {
        close()
        var err = [CChar](repeating: 0, count: 512)
        let peak = String(Int(max(203, displayPeakNits.rounded())))
        let opened = err.withUnsafeMutableBufferPointer { buf in
            peak.withCString { peakC in
                buehne_mpv_open(url.path, peakC, buf.baseAddress, Int32(buf.count))
            }
        }
        guard let opened else {
            let message = String(cString: err)
            failure = message.isEmpty ? "libmpv failed to open \(url.lastPathComponent)" : message
            throw PlaybackError.openFailed(failure ?? "libmpv failed")
        }
        box = opened
        failure = nil
        buehne_mpv_set_volume(opened, volume)
        buehne_mpv_set_rate(opened, rate)
        buehne_mpv_play(opened)
        paused = false
    }

    public func play() {
        guard let box else { return }
        buehne_mpv_play(box)
        paused = false
    }

    public func pause() {
        guard let box else { return }
        buehne_mpv_pause(box)
        paused = true
    }

    public func seek(to time: TimeInterval) {
        guard let box else { return }
        buehne_mpv_seek(box, time)
        self.time = time
        seekTarget = (time, Date())
    }

    public func setVolume(_ volume: Double) {
        self.volume = volume
        if let box { buehne_mpv_set_volume(box, volume) }
    }

    public func appliedVolume() -> Double {
        guard let box else { return volume }
        let read = buehne_mpv_get_volume(box)
        return read < 0 ? volume : read
    }

    public func setRate(_ rate: Double) {
        let changed = abs(self.rate - rate) > 0.001
        self.rate = rate
        guard let box else { return }
        buehne_mpv_set_rate(box, rate)
        // The output queue still holds about a second of sound at the old speed. Flush it once the slider settles.
        guard changed else { return }
        rateFlush?.cancel()
        rateFlush = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled, let self, let box = self.box else { return }
            // A seek to the current spot empties the output queue without reloading the device.
            buehne_mpv_seek(box, self.time)
        }
    }

    public func appliedRate() -> Double {
        guard let box else { return rate }
        let read = buehne_mpv_get_rate(box)
        return read < 0 ? rate : read
    }

    public func render() {
        guard let box else { return }
        var t = 0.0
        var d = 0.0
        var pausedFlag: Int32 = 1
        var width: Int32 = 0
        var height: Int32 = 0
        var err = [CChar](repeating: 0, count: 256)
        _ = buehne_mpv_poll(box, &t, &d, &pausedFlag, &width, &height, &err, Int32(err.count))
        // Volume is applied at the output (no queue lag). Before the output opens the first write is lost, so re-apply.
        volumeCheck += 1
        if volumeCheck % 30 == 0 {
            let read = buehne_mpv_get_volume(box)
            if read >= 0, abs(read - volume) > 0.005 { buehne_mpv_set_volume(box, volume) }
        }
        if let target = seekTarget {
            // Until mpv reports the new position, keep showing the target instead of the old time.
            if abs(t - target.value) <= 1.5 || Date().timeIntervalSince(target.at) > 1.5 {
                seekTarget = nil
                time = t
            } else {
                time = target.value
            }
        } else {
            time = t
        }
        if d > 0 { duration = d }
        paused = pausedFlag != 0
        if width > 1, height > 1 {
            coded = VideoSize(width: Double(width), height: Double(height))
        }
        guard width > 1, height > 1 else { return }
        let display = PictureLayout.displayAspect(
            codedWidth: Double(width), codedHeight: Double(height),
            aspect: aspectName, crop: cropName, rotation: rotationDegrees
        )
        let longSide = 1920.0
        let targetW: Int
        let targetH: Int
        if display >= 1 {
            targetW = 1920
            targetH = max(2, Int((longSide / display).rounded()))
        } else {
            targetH = 1920
            targetW = max(2, Int((longSide * display).rounded()))
        }
        var raw: UnsafeMutableRawPointer?
        let rc = buehne_mpv_render_surface(box, Int32(targetW), Int32(targetH), &raw, &err, Int32(err.count))
        if rc == 0, let raw {
            let io = Unmanaged<IOSurface>.fromOpaque(raw).takeUnretainedValue()
            surface.present(ioSurface: io, width: targetW, height: targetH, peakNits: displayPeakNits)
            hdrReport = signal(box)
        }
        if detectBars, picture == nil, scanAttempts < 6, surface.presentedFrames > 120, surface.presentedFrames % 4 == 1 {
            scanAttempts += 1
            scanBars(box: box, codedW: Int(width), codedH: Int(height))
        }
}

    private func scanBars(box: OpaquePointer, codedW: Int, codedH: Int) {
        let longSide = max(codedW, codedH)
        let scale = longSide > 480 ? 480.0 / Double(longSide) : 1
        let targetW = max(2, Int((Double(codedW) * scale).rounded()))
        let targetH = max(2, Int((Double(codedH) * scale).rounded()))
        var pixels = [UInt16](repeating: 0, count: targetW * targetH * 4)
        var err = [CChar](repeating: 0, count: 256)
        let rc = pixels.withUnsafeMutableBytes { raw in
            buehne_mpv_render_linear(box, Int32(targetW), Int32(targetH), raw.baseAddress, &err, Int32(err.count))
        }
        guard rc == 0 else { return }
        let preview = previewBytes(pixels, width: targetW, height: targetH)
        let decision = preview.withUnsafeBufferPointer { buf in
            LetterboxScan.decide(width: targetW, height: targetH, bytesPerRow: targetW * 4, pixels: buf.baseAddress!)
        }
        guard !decision.nearlyDark else { return }
        votes.append(decision.bounds)
        if let agreed = LetterboxScan.agreed(votes, width: targetW, height: targetH) {
            picture = agreed
            pictureSpace = VideoSize(width: Double(targetW), height: Double(targetH))
            applyDetectedCrop(box: box, codedW: codedW, codedH: codedH)
        }
    }

    public func snapshot() -> PlaybackSnapshot {
        let size: VideoSize
        if detectBars, let picture, pictureSpace.width > 1, pictureSpace.height > 1, coded.width > 1, coded.height > 1 {
            let scaleX = coded.width / pictureSpace.width
            let scaleY = coded.height / pictureSpace.height
            size = VideoSize(
                width: (Double(picture.width) * scaleX).rounded(),
                height: (Double(picture.height) * scaleY).rounded()
            )
        } else {
            size = coded
        }
        if let failure, box == nil {
            return PlaybackSnapshot(phase: .failed, engine: .libmpv, error: failure, videoSize: size)
        }
        return PlaybackSnapshot(
            phase: paused ? .paused : .playing,
            currentTime: time,
            duration: duration > 0 ? duration : nil,
            rate: rate,
            volume: volume,
            engine: .libmpv,
            videoSize: size
        )
    }

    public func tracks() -> MediaTracks {
        reloadTracks()
        return loadedTracks
    }

    public func stringProperty(_ name: String) -> String {
        guard let box else { return "" }
        var buf = [CChar](repeating: 0, count: 512)
        let rc = name.withCString { buehne_mpv_property(box, $0, &buf, Int32(buf.count)) }
        return rc == 0 ? String(cString: buf) : ""
    }

    public func selectAudio(id: String?) {
        setTrack("aid", id)
    }

    public func selectSubtitle(id: String?) -> Bool {
        setTrack("sid", id)
        return true
    }

    public func selectSecondarySubtitle(id: String?) -> Bool {
        setTrack("secondary-sid", id)
        return true
    }

    public func applyPicture(aspect: String, crop: String, rotation: Int) {
        aspectName = aspect
        cropName = crop
        rotationDegrees = PictureLayout.normalizedRotation(rotation)
        guard let box else { return }
        let codedW = coded.width > 1 ? coded.width : 1920
        let codedH = coded.height > 1 ? coded.height : 1080
        setString("video-aspect-override", PictureLayout.mpvAspectOverride(aspect))
        setString("video-crop", PictureLayout.mpvCrop(codedWidth: codedW, codedHeight: codedH, crop: crop))
        setString("video-rotate", PictureLayout.mpvRotate(rotation))
    }

    private func setString(_ name: String, _ value: String) {
        guard let box else { return }
        _ = name.withCString { key in
            value.withCString { text in buehne_mpv_set(box, key, text) }
        }
    }
    public func trackJSON() -> String {
        guard let box else { return "[]" }
        var buf = [CChar](repeating: 0, count: 65536)
        _ = buehne_mpv_track_json(box, &buf, Int32(buf.count))
        return String(cString: buf)
    }

    public func reloadTracks() {
        loadedTracks = TrackListParser.parse(trackJSON())
    }

    private func setTrack(_ property: String, _ id: String?) {
        guard let box else { return }
        let value = TrackListParser.propertyValue(for: id)
        _ = property.withCString { name in
            value.withCString { text in buehne_mpv_set(box, name, text) }
        }
        reloadTracks()
    }

    public func close() {
        if let box { buehne_mpv_close(box) }
        self.box = nil
        loadedTracks = .empty
        frame = nil
        picture = nil
        surface.cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        votes.removeAll()
        pictureSpace = VideoSize(width: 0, height: 0)
    }

    private func cropFrame(_ bytes: [UInt8], width: Int, stride: Int, crop: PictureBounds) -> RenderedFrame {
        let row = crop.width * 4
        var out = [UInt8](repeating: 0, count: row * crop.height)
        for y in 0..<crop.height {
            let src = (crop.y + y) * stride + crop.x * 4
            let dst = y * row
            if src + row <= bytes.count, dst + row <= out.count {
                out.replaceSubrange(dst..<(dst + row), with: bytes[src..<(src + row)])
            }
        }
        return RenderedFrame(width: crop.width, height: crop.height, bgra: Data(out))
    }

    private func signal(_ box: OpaquePointer) -> String {
        func prop(_ name: String) -> String {
            var buf = [CChar](repeating: 0, count: 128)
            let rc = buf.withUnsafeMutableBufferPointer { raw in
                name.withCString { buehne_mpv_property(box, $0, raw.baseAddress, Int32(raw.count)) }
            }
            return rc == 0 ? String(cString: buf) : "-"
        }
        let prim = prop("video-params/primaries")
        let gamma = prop("video-params/gamma")
        let peak = prop("video-params/sig-peak")
        let targetGamma = prop("video-target-params/gamma")
        let targetPrim = prop("video-target-params/primaries")
        let targetPeak = prop("video-target-params/sig-peak")
        let requested = prop("target-trc")
        return "primaries=\(prim) gamma=\(gamma) peak=\(peak) targetPrim=\(targetPrim) targetGamma=\(targetGamma) targetPeak=\(targetPeak) targetTrc=\(requested) \(surface.descriptionText) presented=\(surface.presented ? 1 : 0)"
    }

    public func playbackProbe() -> String {
        let fps = prop("estimated-vf-fps")
        let hw = prop("hwdec-current")
        let dropped = prop("frame-drop-count")
        let decoderDropped = prop("decoder-frame-drop-count")
        return "vfFps=\(fps) hwdec=\(hw) dropped=\(dropped) decoderDropped=\(decoderDropped) presented=\(presentedFrames)"
    }

    private func prop(_ name: String) -> String {
        guard let box else { return "-" }
        var buf = [CChar](repeating: 0, count: 128)
        let rc = buf.withUnsafeMutableBufferPointer { raw in
            name.withCString { buehne_mpv_property(box, $0, raw.baseAddress, Int32(raw.count)) }
        }
        return rc == 0 ? String(cString: buf) : "-"
    }

    private func frameStats(_ pixels: [UInt16], width: Int, height: Int) -> String {
        var peak = Float(0)
        var sum = Float(0)
        var count = 0
        pixels.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Float16.self)
            let step = max(1, (width * height) / 4000)
            var i = 0
            while i < width * height {
                let g = Float(samples[i * 4 + 1])
                peak = max(peak, g)
                sum += g
                count += 1
                i += step
            }
        }
        let mean = count > 0 ? sum / Float(count) : 0
        return String(format: "samplePeak=%.3f sampleMean=%.3f", peak, mean)
    }
    private func previewBytes(_ pixels: [UInt16], width: Int, height: Int) -> [UInt8] {
        let gain = Float(max(displayPeakNits, 203) / 203)
        var out = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Float16.self)
            for i in 0..<(width * height) {
                let base = i * 4
                let r = min(1, max(0, Float(samples[base]) * gain))
                let g = min(1, max(0, Float(samples[base + 1]) * gain))
                let b = min(1, max(0, Float(samples[base + 2]) * gain))
                out[base] = UInt8(b * 255)
                out[base + 1] = UInt8(g * 255)
                out[base + 2] = UInt8(r * 255)
                out[base + 3] = 255
            }
        }
        return out
    }
}
