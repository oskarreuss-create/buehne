import AVFoundation
import QuartzCore
import BuehneCore
import Foundation

/// Hardware decoding stays on AVFoundation's automatic path. There is no switch.
@MainActor
public final class AVFoundationEngine: PlaybackEngine {
    public let kind: EngineKind = .avFoundation
    public let player: AVPlayer
    private var item: AVPlayerItem?
    private var intendedRate = 1.0
    private var volume = 1.0
    private var volumeWrite: DispatchWorkItem?
    private var paused = true
    private var loadedSize = VideoSize(width: 0, height: 0)
    private var audioOptions: [String: AVMediaSelectionOption] = [:]
    private var subtitleOptions: [String: AVMediaSelectionOption] = [:]
    private var loadedTracks = MediaTracks.empty
    private var secondaryApplied = false

    public init(player: AVPlayer) {
        self.player = player
        player.automaticallyWaitsToMinimizeStalling = false
    }

    public func open(_ url: URL) async throws {
        let item = AVPlayerItem(url: url)
        self.item = item
        audioOptions = [:]
        subtitleOptions = [:]
        loadedTracks = .empty
        secondaryApplied = false
        player.replaceCurrentItem(with: item)
        let deadline = ContinuousClock.now.advanced(by: .seconds(12))
        while ContinuousClock.now < deadline {
            if item.status == .readyToPlay {
                loadTracks(from: item)
                let natural = item.presentationSize
                if natural.width > 0, natural.height > 0 {
                    loadedSize = VideoSize(width: Double(natural.width), height: Double(natural.height))
                }
                return
            }
            if item.status == .failed {
                throw PlaybackError.openFailed(item.error?.localizedDescription ?? url.lastPathComponent)
            }
            try await Task.sleep(for: .milliseconds(40))
        }
        throw PlaybackError.openFailed("timed out waiting for \(url.lastPathComponent)")
    }

    public func play() {
        paused = false
        player.playImmediately(atRate: Float(intendedRate))
    }

    public func pause() {
        paused = true
        player.pause()
    }

    public func seek(to time: TimeInterval) {
        let target = max(0, time)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    public func setVolume(_ volume: Double) {
        self.volume = min(1, max(0, volume))
        let target = Float(self.volume)
        volumeWrite?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            CATransaction.setAnimationDuration(0)
            self.player.volume = target
            CATransaction.commit()
            CATransaction.flush()
        }
        volumeWrite = work
        DispatchQueue.main.async(execute: work)
    }

    public func appliedVolume() -> Double { Double(player.volume) }

    public func setRate(_ rate: Double) {
        intendedRate = RateRange.clamp(rate)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setAnimationDuration(0)
        player.defaultRate = Float(intendedRate)
        if !paused { player.rate = Float(intendedRate) }
        CATransaction.commit()
        CATransaction.flush()
    }

    public func appliedRate() -> Double {
        let live = Double(player.rate)
        return live > 0.001 ? live : intendedRate
    }

    public func snapshot() -> PlaybackSnapshot {
        let item = player.currentItem
        let seconds = player.currentTime().seconds
        let current = seconds.isFinite && seconds >= 0 ? seconds : 0
        let rawDuration = item?.duration.seconds ?? .nan
        let duration = rawDuration.isFinite && rawDuration > 0 ? rawDuration : nil
        let playing = player.timeControlStatus == .playing
        if playing { paused = false }
        let phase: PlaybackPhase
        if item == nil {
            phase = .idle
        } else if item?.status == .failed {
            phase = .failed
        } else if playing {
            phase = .playing
        } else if item?.status == .readyToPlay {
            phase = paused ? .paused : .playing
        } else {
            phase = .opening
        }
        return PlaybackSnapshot(
            phase: phase,
            currentTime: current,
            duration: duration,
            rate: playing ? Double(player.rate) : 0,
            volume: volume,
            engine: .avFoundation,
            error: item?.error?.localizedDescription,
            videoSize: loadedSize
        )
    }

    public func tracks() -> MediaTracks { loadedTracks }

    public func selectAudio(id: String?) {
        guard let item, let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else { return }
        item.select(id.flatMap { audioOptions[$0] }, in: group)
        loadTracks(from: item)
    }

    public func selectSubtitle(id: String?) -> Bool {
        guard let item, let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else { return id == nil }
        item.select(id.flatMap { subtitleOptions[$0] }, in: group)
        loadTracks(from: item)
        return true
    }

    public func selectSecondarySubtitle(id: String?) -> Bool {
        secondaryApplied = false
        return id == nil
    }

    public func close() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        item = nil
        paused = true
        loadedSize = VideoSize(width: 0, height: 0)
        loadedTracks = .empty
    }

    private func loadTracks(from item: AVPlayerItem) {
        audioOptions = [:]
        subtitleOptions = [:]
        var audio: [MediaTrack] = []
        var subtitles: [MediaTrack] = []
        if let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) {
            let chosen = item.currentMediaSelection.selectedMediaOption(in: group)
            for (index, option) in group.options.enumerated() {
                let id = "a\(index)-\(option.extendedLanguageTag ?? option.displayName)"
                audioOptions[id] = option
                audio.append(MediaTrack(id: id, name: option.displayName, kind: .audio, lang: option.extendedLanguageTag ?? "", selected: option == chosen))
            }
        }
        if let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            let chosen = item.currentMediaSelection.selectedMediaOption(in: group)
            for (index, option) in group.options.enumerated() {
                let id = "s\(index)-\(option.extendedLanguageTag ?? option.displayName)"
                subtitleOptions[id] = option
                subtitles.append(MediaTrack(id: id, name: option.displayName, kind: .subtitle, lang: option.extendedLanguageTag ?? "", selected: option == chosen))
            }
        }
        loadedTracks = MediaTracks(audio: audio, subtitles: subtitles)
    }
}
