import Foundation

/// Local diagnostic for "the film jumped back by itself": who asked for a jump, and any jump of the clock nobody asked for.
/// One short line each in ~/Library/Logs/BUEHNE/seek.log, kept on this Mac, never sent anywhere, capped at 256 KB.
public enum SeekLog {
    public static func note(_ text: String) {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/BUEHNE", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("seek.log")
        if let size = (try? FileManager.default.attributesOfItem(atPath: file.path))?[.size] as? NSNumber, size.intValue > 262_144 {
            try? FileManager.default.removeItem(at: file)
        }
        let line = Data("\(ISO8601DateFormatter().string(from: Date())) \(text)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: file) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
            try? handle.close()
        } else {
            try? line.write(to: file)
        }
    }
}
