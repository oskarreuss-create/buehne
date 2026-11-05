import Foundation

public enum PlaybackPhase: String, Sendable, Equatable {
    case idle
    case opening
    case playing
    case paused
    case failed
}

public struct VideoSize: Sendable, Equatable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public var isKnown: Bool { width > 0 && height > 0 }
    public var aspect: Double { height > 0 ? width / height : 0 }
}

public struct PlaybackSnapshot: Sendable, Equatable {
    public var phase: PlaybackPhase
    public var currentTime: TimeInterval
    public var duration: TimeInterval?
    public var rate: Double
    public var volume: Double
    public var engine: EngineKind?
    public var error: String?
    public var videoSize: VideoSize

    public init(
        phase: PlaybackPhase = .idle,
        currentTime: TimeInterval = 0,
        duration: TimeInterval? = nil,
        rate: Double = 1,
        volume: Double = 1,
        engine: EngineKind? = nil,
        error: String? = nil,
        videoSize: VideoSize = VideoSize(width: 0, height: 0)
    ) {
        self.phase = phase
        self.currentTime = currentTime
        self.duration = duration
        self.rate = rate
        self.volume = volume
        self.engine = engine
        self.error = error
        self.videoSize = videoSize
    }
}

public enum TrackKind: String, Sendable, Equatable {
    case audio
    case subtitle
}

public struct MediaTrack: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var kind: TrackKind

    public var lang: String
    public var title: String
    public var codec: String
    public var selected: Bool
    public var mpvID: Int

    public init(id: String, name: String, kind: TrackKind, lang: String = "", title: String = "", codec: String = "", selected: Bool = false, mpvID: Int = 0) {
        self.id = id
        self.name = name
        self.kind = kind
        self.lang = lang
        self.title = title
        self.codec = codec
        self.selected = selected
        self.mpvID = mpvID
    }
}

public struct MediaTracks: Sendable, Equatable {
    public var audio: [MediaTrack]
    public var subtitles: [MediaTrack]

    public static let empty = MediaTracks(audio: [], subtitles: [])

    public init(audio: [MediaTrack], subtitles: [MediaTrack]) {
        self.audio = audio
        self.subtitles = subtitles
    }
}

public enum PlaybackError: Error, Equatable, Sendable {
    case fileNotFound(String)
    case engineUnavailable(String)
    case openFailed(String)
}

public protocol PositionStore: Sendable {
    func position(for key: String) -> TimeInterval?
    func save(_ position: TimeInterval, for key: String)
}

public final class MemoryPositionStore: PositionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: TimeInterval] = [:]

    public init() {}

    public func position(for key: String) -> TimeInterval? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    public func save(_ position: TimeInterval, for key: String) {
        lock.lock()
        defer { lock.unlock() }
        values[key] = position
    }
}

public enum WindowGeometry {
    public static let emptyWidth = 440.0
    public static let emptyHeight = 290.0
    public static let screenCap = 0.60

    /// Coded frame fitted to about 60% of the screen. Nil when the coded size is unknown.
    public static func openingSize(
        videoWidth: Double,
        videoHeight: Double,
        screenWidth: Double,
        screenHeight: Double,
        margin: Double = 80
    ) -> (width: Double, height: Double)? {
        guard videoWidth > 0, videoHeight > 0, screenWidth > margin, screenHeight > margin else { return nil }
        let maxW = min(screenWidth - margin, screenWidth * screenCap)
        let maxH = min(screenHeight - margin, screenHeight * screenCap)
        let scale = min(1, maxW / videoWidth, maxH / videoHeight)
        return (videoWidth * scale, videoHeight * scale)
    }

    /// Hard cap: floating mode cannot exceed a ninth of the screen area. Aspect is preserved.
    public static func floatingMaxSize(screenWidth: Double, screenHeight: Double, aspect: Double) -> (width: Double, height: Double) {
        let area = max(screenWidth, 1) * max(screenHeight, 1) / 9
        let a = max(aspect, 0.01)
        return ((area * a).squareRoot(), (area / a).squareRoot())
    }
}
