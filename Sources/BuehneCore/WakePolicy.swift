import Foundation

/// When the Mac must be kept awake: always while a video plays or opens, and for a grace period after a pause.
public enum WakePolicy {
    public static let pauseGrace: TimeInterval = 30 * 60

    public static func holdsAwake(phase: PlaybackPhase, pausedFor: TimeInterval) -> Bool {
        switch phase {
        case .opening, .playing: true
        case .paused: pausedFor < pauseGrace
        case .idle, .failed: false
        }
    }

    /// Seconds until the hold must be re-evaluated (nil when nothing is scheduled).
    public static func recheckDelay(phase: PlaybackPhase, pausedFor: TimeInterval) -> TimeInterval? {
        phase == .paused && pausedFor < pauseGrace ? pauseGrace - pausedFor : nil
    }
}
