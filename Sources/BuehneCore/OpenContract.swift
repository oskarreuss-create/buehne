import Foundation

/// Launch contract shared by Finder, `open -a`, a path argument, and `buehne://open?path=`.
public enum OpenContract {
    public static let bundleIdentifier = "ch.oskarreus.buehne"
    public static let displayName = "BÜHNE"
    public static let executableName = "Buehne"
    public static let urlScheme = "buehne"

    public static func mediaURL(from arguments: [String]) -> URL? {
        for arg in arguments.dropFirst() {
            if arg == "--self-check" || arg == "--print-position" { continue }
            if arg.hasPrefix("-") { continue }
            return mediaURL(parsing: arg)
        }
        return nil
    }

    public static func mediaURL(fromLaunchURL url: URL) -> URL? {
        if url.isFileURL { return url }
        if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" { return url }
        guard url.scheme?.lowercased() == urlScheme else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let raw = components.queryItems?.first(where: { $0.name == "path" })?.value,
              !raw.isEmpty
        else { return nil }
        if raw.contains("://"), let remote = URL(string: raw) { return remote }
        return URL(fileURLWithPath: raw)
    }

    public static func mediaURL(parsing raw: String) -> URL? {
        if let url = URL(string: raw), url.scheme?.lowercased() == urlScheme {
            return mediaURL(fromLaunchURL: url)
        }
        if let url = URL(string: raw), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" || scheme == "file" {
            return url
        }
        if raw.hasPrefix("/") || raw.hasPrefix(".") || raw.hasPrefix("~") {
            let expanded = NSString(string: raw).expandingTildeInPath
            return URL(fileURLWithPath: expanded)
        }
        return nil
    }

    public static func positionKey(for url: URL) -> String {
        if url.isFileURL { return url.standardizedFileURL.path }
        return url.absoluteString
    }
}
