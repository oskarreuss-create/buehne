import AVFoundation
import BuehneCore
import Combine
import Foundation
import QuartzCore

@MainActor
public final class PlayerSession: ObservableObject {
    @Published public private(set) var snapshot = PlaybackSnapshot()
    @Published public private(set) var tracks = MediaTracks.empty
    @Published public var volume: Double = 1
    @Published public var preferredRate: Double = 1
    @Published public var secondarySubtitleID: String?
    @Published public private(set) var secondarySubtitleRendered = false
    @Published public private(set) var renderedFrame: RenderedFrame?
    public var detectBars = true
    public var displayPeakNits = 1000.0
    @Published public private(set) var hdrReport = ""
    public var displayLayer: CALayer? {
        (engine as? LibmpvEngine)?.surface.layer
    }
    public let avPlayer = AVPlayer()
    private var engine: (any PlaybackEngine)?
    private let store: any PositionStore
    private var openGeneration = 0
    private var lastTrackPoll = Date.distantPast
    private var mediaKey: String?
    private var lastSaved: TimeInterval = -1
    private var holdRateRestore: Double?
    private var muteRestore = 1.0

    public init(store: (any PositionStore)? = nil) {
        self.store = store ?? UserDefaultsPositionStore()
    }

    public func open(url: URL) async {
        openGeneration += 1
        holdRateRestore = nil
        let generation = openGeneration
        engine?.close()
        engine = nil
        tracks = .empty
        secondarySubtitleID = nil
        mediaKey = nil
        lastSaved = -1
        if url.isFileURL && !FileManager.default.fileExists(atPath: url.path) {
            snapshot = PlaybackSnapshot(phase: .failed, engine: nil, error: PlaybackError.fileNotFound(url.path).description(url))
            return
        }
        let route = EngineRouter.route(url)
        let next = EngineRouter.makeEngine(for: route, player: avPlayer)
        engine = next
        if let mpv = next as? LibmpvEngine {
            mpv.displayPeakNits = displayPeakNits
        }
        snapshot = PlaybackSnapshot(phase: .opening, volume: volume, engine: route.kind)
        do {
            try await next.open(url)
            if generation != openGeneration { return }
            next.setVolume(volume)
            next.setRate(preferredRate)
            let key = OpenContract.positionKey(for: url)
            mediaKey = key
            let saved = store.position(for: key)
            next.play()
            tracks = next.tracks()
            snapshot = next.snapshot()
            if saved != nil {
                // The file may still be loading. Wait for a duration, then jump to the saved spot.
                for _ in 0..<60 {
                    if generation != openGeneration { return }
                    if let duration = next.snapshot().duration {
                        if let target = PlaylistPolicy.resumePosition(saved: saved, duration: duration) {
                            next.seek(to: target)
                            snapshot = next.snapshot()
                        }
                        break
                    }
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
        } catch let error as PlaybackError {
            if generation != openGeneration { return }
            snapshot = PlaybackSnapshot(phase: .failed, volume: volume, engine: route.kind, error: error.description(url))
        } catch {
            if generation != openGeneration { return }
            snapshot = PlaybackSnapshot(phase: .failed, volume: volume, engine: route.kind, error: error.localizedDescription)
        }
    }

    public func togglePlay() {
        guard let engine else { return }
        if snapshot.phase == .playing {
            engine.pause()
            savePosition(force: true)
        } else {
            engine.setRate(preferredRate)
            engine.play()
        }
        snapshot = engine.snapshot()
    }

    public func seek(by delta: TimeInterval) {
        let base = snapshot.duration.map { min(snapshot.currentTime, $0) } ?? snapshot.currentTime
        seek(to: base + delta)
    }

    public func seek(to time: TimeInterval) {
        guard let engine else { return }
        let upper = snapshot.duration ?? time
        engine.seek(to: min(max(0, time), max(upper, 0)))
        snapshot = engine.snapshot()
        savePosition(force: true)
    }

    public func setPreferredRate(_ rate: Double) {
        let next = RateApply.clamp(rate)
        engine?.setRate(next)
        preferredRate = next
    }

    public func setVolume(_ value: Double) {
        let next = VolumeApply.clamp(value)
        engine?.setVolume(next)
        volume = next
    }

    public func readAppliedVolume() -> Double {
        if let mpv = engine as? LibmpvEngine { return mpv.appliedVolume() }
        if let av = engine as? AVFoundationEngine { return av.appliedVolume() }
        return volume
    }

    public func readAppliedRate() -> Double {
        if let mpv = engine as? LibmpvEngine { return mpv.appliedRate() }
        if let av = engine as? AVFoundationEngine { return av.appliedRate() }
        return preferredRate
    }

    public func adjustVolume(by delta: Double) {
        setVolume(volume + delta)
    }

    public func toggleMute() {
        if volume > 0.001 {
            muteRestore = volume
            setVolume(0)
        } else {
            setVolume(muteRestore > 0.001 ? muteRestore : 1)
        }
    }

    public func cycleAudio() {
        let list = tracks.audio
        guard !list.isEmpty else { return }
        let current = list.firstIndex(where: \.selected) ?? -1
        selectAudio(id: list[(current + 1) % list.count].id)
    }

    public func cycleSubtitle() {
        let list = tracks.subtitles
        guard !list.isEmpty else { return }
        if let index = list.firstIndex(where: \.selected) {
            selectSubtitle(id: index + 1 < list.count ? list[index + 1].id : nil)
        } else {
            selectSubtitle(id: list[0].id)
        }
    }

    /// Right-edge hold: play at 2× the preferred rate until `ended`.
    public func setHoldFastForward(_ active: Bool) {
        guard let engine else { return }
        if active {
            if holdRateRestore == nil { holdRateRestore = preferredRate }
            engine.setRate(min(RateRange.maximum, max(preferredRate * 2, 2)))
            if snapshot.phase != .playing { engine.play() }
        } else if let restore = holdRateRestore {
            holdRateRestore = nil
            engine.setRate(restore)
        }
        snapshot = engine.snapshot()
    }

    public func selectAudio(id: String?) {
        engine?.selectAudio(id: id?.isEmpty == true ? nil : id)
        tracks = engine?.tracks() ?? tracks
    }

    public func selectSubtitle(id: String?) {
        _ = engine?.selectSubtitle(id: id?.isEmpty == true ? nil : id)
        tracks = engine?.tracks() ?? tracks
    }

    public func selectSecondarySubtitle(id: String?) -> Bool {
        let cleaned = id?.isEmpty == true ? nil : id
        secondarySubtitleID = cleaned
        let applied = engine?.selectSecondarySubtitle(id: cleaned) ?? false
        secondarySubtitleRendered = applied && cleaned != nil
        return applied
    }

    public func applyPicture(aspect: String, crop: String, rotation: Int) {
        engine?.applyPicture(aspect: aspect, crop: crop, rotation: rotation)
    }

    public func engineProperty(_ name: String) -> String {
        (engine as? LibmpvEngine)?.stringProperty(name) ?? ""
    }

    public var presentedFrames: Int { (engine as? LibmpvEngine)?.presentedFrames ?? 0 }

    public func playbackProbe() -> String { (engine as? LibmpvEngine)?.playbackProbe() ?? "presented=0" }

    public func refresh() {
        guard let engine else { return }
        if let mpv = engine as? LibmpvEngine {
            mpv.setDetectBars(detectBars)
            mpv.displayPeakNits = displayPeakNits
            mpv.render()
            let frame = mpv.frame
            if frame != nil || renderedFrame != nil { renderedFrame = frame }
            let report = mpv.hdrReport
            if report != hdrReport { hdrReport = report }
        } else if renderedFrame != nil {
            renderedFrame = nil
        }
        if lastTrackPoll.timeIntervalSinceNow < -0.5 {
            lastTrackPoll = Date()
            let nextTracks = engine.tracks()
            if nextTracks != tracks { tracks = nextTracks }
        }
        let next = engine.snapshot()
        if next.phase != snapshot.phase
            || abs(next.currentTime - snapshot.currentTime) >= 0.25
            || next.duration != snapshot.duration
            || next.videoSize != snapshot.videoSize
            || next.rate != snapshot.rate {
            snapshot = next
        }
        if next.phase == .playing { savePosition(force: false) }
    }

    /// Called when the app quits or the window closes, so the last second is kept too.
    public func persistPosition() {
        let live = engine?.snapshot().currentTime ?? snapshot.currentTime
        guard let mediaKey, live.isFinite, live > 1 else { return }
        store.save(live, for: mediaKey)
    }

    private func savePosition(force: Bool) {
        guard let mediaKey, snapshot.currentTime.isFinite else { return }
        if !force, abs(snapshot.currentTime - lastSaved) < 2 { return }
        store.save(snapshot.currentTime, for: mediaKey)
        lastSaved = snapshot.currentTime
    }
}

private extension PlaybackError {
    func description(_ url: URL) -> String {
        switch self {
        case .fileNotFound(let path):
            return path
        case .engineUnavailable(let detail):
            return detail
        case .openFailed(let detail):
            return detail
        }
    }
}

public final class UserDefaultsPositionStore: PositionStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let prefix = "buehne.position."

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func position(for key: String) -> TimeInterval? {
        let stored = defaults.object(forKey: prefix + key)
        guard let number = stored as? Double, number.isFinite, number >= 0 else { return nil }
        return number
    }

    public func save(_ position: TimeInterval, for key: String) {
        guard position.isFinite, position >= 0 else { return }
        defaults.set(position, forKey: prefix + key)
    }
}
