import AVFoundation
import BuehneCore
import Foundation

@MainActor
public protocol PlaybackEngine: AnyObject {
    var kind: EngineKind { get }
    func open(_ url: URL) async throws
    func play()
    func pause()
    func seek(to time: TimeInterval)
    func setVolume(_ volume: Double)
    func setRate(_ rate: Double)
    func snapshot() -> PlaybackSnapshot
    func tracks() -> MediaTracks
    func selectAudio(id: String?)
    func selectSubtitle(id: String?) -> Bool
    func selectSecondarySubtitle(id: String?) -> Bool
    func applyPicture(aspect: String, crop: String, rotation: Int)
    func close()
}

public extension EngineRouter {
    @MainActor
    static func makeEngine(for route: EngineRoute, player: AVPlayer) -> any PlaybackEngine {
        switch route.kind {
        case .avFoundation:
            return AVFoundationEngine(player: player)
        case .libmpv:
            return LibmpvEngine()
        }
    }
}

public extension PlaybackEngine {
    func applyPicture(aspect: String, crop: String, rotation: Int) {}
}
