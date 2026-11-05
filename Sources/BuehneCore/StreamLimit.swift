import Foundation

/// STRÖM streams a video that is still downloading through a local address:
/// `http://127.0.0.1:<port>/v/<token>/<name>`. The same server tells how much is already on disk at
/// `http://127.0.0.1:<port>/status/<token>` (`{"size":…,"prefix":…,"complete":…}`).
/// Rule from the owner: the player must never let the viewer jump past the part that has been downloaded.
public struct StreamLimit: Sendable, Equatable {
    public let statusURL: URL

    /// Returns nil for any address that is not a STRÖM stream (local files, other web addresses).
    public init?(streamURL url: URL) {
        guard url.scheme == "http", let host = url.host, host == "127.0.0.1" || host == "localhost",
              let port = url.port else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count >= 2, parts[0] == "v", !parts[1].isEmpty else { return nil }
        guard let status = URL(string: "http://\(host):\(port)/status/\(parts[1])") else { return nil }
        statusURL = status
    }

    public struct Status: Decodable, Sendable, Equatable {
        public let size: Int64
        public let prefix: Int64
        public let complete: Bool?
        public init(size: Int64, prefix: Int64, complete: Bool? = nil) {
            self.size = size
            self.prefix = prefix
            self.complete = complete
        }
    }

    /// Latest second the viewer may jump to. Bytes are not evenly spread over time, so a small safety margin is kept.
    /// `.infinity` means the whole file is on disk.
    public static func allowedTime(_ status: Status, duration: TimeInterval) -> TimeInterval {
        guard status.size > 0, duration.isFinite, duration > 0 else { return 0 }
        if status.prefix >= status.size || status.complete == true { return .infinity }
        let fraction = Double(max(0, status.prefix)) / Double(status.size)
        return max(0, duration * fraction * 0.97)
    }

    /// A forward jump is cut at the limit; going back, or staying where we are, is always allowed.
    public static func clamp(_ target: TimeInterval, current: TimeInterval, allowed: TimeInterval) -> TimeInterval {
        guard target > allowed else { return target }
        return max(allowed, min(current, target))
    }
}
