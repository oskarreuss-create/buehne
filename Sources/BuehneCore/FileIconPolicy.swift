import Foundation

/// Which files get a branded Finder icon, and when a scan may skip them.
/// Pure: no file I/O, so a test can cover the rules without touching a library.
public enum FileIconPolicy {
    public static let frameFraction = 0.10
    public static let concurrency = 4
    public static let sizes = [1024, 512, 256, 128, 32]
    public static let cacheName = "file-icon-cache.json"

    /// Extensions the player is built to open. Unknown names stay undecorated.
    public static let playableExtensions: Set<String> = [
        "mp4", "m4v", "mov", "mkv", "avi", "webm", "mpg", "mpeg",
        "m2ts", "ts", "mts", "m2v", "wmv", "flv", "ogv", "ogm",
        "3gp", "3g2", "vob", "divx", "asf", "qt", "mk3d", "f4v", "mxf",
    ]

    public static func isPlayableExtension(_ ext: String) -> Bool {
        playableExtensions.contains(ext.lowercased())
    }

    /// 10% into the file. A missing duration seeks one second in, not to the first black frame.
    public static func frameSeconds(duration: Double?) -> Double {
        guard let duration, duration.isFinite, duration > 0 else { return 1 }
        return duration * frameFraction
    }

    public static func cacheToken(mtime: TimeInterval, size: Int) -> String {
        "\(Int(mtime.rounded()))-\(size)"
    }

    public static func decide(
        extension ext: String,
        readable: Bool,
        dataless: Bool,
        enabled: Bool,
        cachedToken: String?,
        currentToken: String
    ) -> String? {
        if !enabled { return "disabled" }
        if !isPlayableExtension(ext) { return "extension" }
        if !readable { return "unreadable" }
        if dataless { return "dataless" }
        if cachedToken == currentToken { return "cached" }
        return nil
    }

    /// Only Downloads, where STRÖM saves finished files. Movies, Documents and Desktop are not scanned:
    /// touching them at launch triggers extra macOS privacy prompts.
    public static func defaultFolders(home: URL) -> [URL] {
        [home.appendingPathComponent("Downloads", isDirectory: true)]
    }

    /// The roots earlier builds scanned by default. A stored list equal to this is migrated to empty.
    public static func legacyDefaultFolders(home: URL) -> [URL] {
        [
            home.appendingPathComponent("Downloads", isDirectory: true),
            home.appendingPathComponent("Movies", isDirectory: true),
            home.appendingPathComponent("Documents", isDirectory: true).appendingPathComponent("Ström", isDirectory: true),
            home.appendingPathComponent("Desktop", isDirectory: true),
        ]
    }

    /// Drops the roots earlier builds scanned besides Downloads (the folder list is not editable in the UI,
    /// so they are leftovers, not a choice). Other stored folders stay; an empty result means the default.
    public static func migrated(stored: [String], home: URL) -> [String] {
        let downloads = home.appendingPathComponent("Downloads", isDirectory: true).path
        let dropped = Set(legacyDefaultFolders(home: home).map(\.path)).subtracting([downloads])
        let kept = stored.filter { !dropped.contains(($0 as NSString).expandingTildeInPath) }
        return kept.isEmpty ? defaultFolders(home: home).map(\.path) : kept
    }

    public static func isDataless(downloadingStatusNotDownloaded: Bool, allocatedBytes: Int?, logicalBytes: Int?) -> Bool {
        if downloadingStatusNotDownloaded { return true }
        if let allocatedBytes, allocatedBytes == 0, (logicalBytes ?? 0) > 0 { return true }
        // A download in progress is a sparse file: the size is final, the data is not there yet.
        if let allocatedBytes, let logicalBytes, logicalBytes > 1_000_000,
           Double(allocatedBytes) < Double(logicalBytes) * 0.9 { return true }
        return false
    }
}
