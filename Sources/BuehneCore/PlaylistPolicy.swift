import Foundation

public enum PlaylistPolicy {
    public static let extensions: Set<String> = ["mkv", "mp4", "m4v", "mov", "avi", "webm", "ts", "m2ts", "wmv", "flv", "mpg", "mpeg"]

    public static func isVideo(extension ext: String) -> Bool {
        extensions.contains(ext.lowercased())
    }

    /// Where to resume. Nothing within the first second, and a finished film starts again.
    public static func resumePosition(saved: Double?, duration: Double?) -> Double? {
        guard let saved, saved.isFinite, saved > 1 else { return nil }
        if let duration, duration.isFinite, duration > 0, saved > duration - 8 { return nil }
        return saved
    }
}
