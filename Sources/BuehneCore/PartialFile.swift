import Foundation

/// A video file that is still being downloaded by a torrent client is a sparse file: its size is final, but only
/// part of the bytes are on disk. Playing past that part freezes the picture while the sound goes on.
/// The rule is the same as for a STRÖM stream: never let the viewer jump past what has been downloaded.
public enum PartialFile {
    /// Size and the length of the continuous part from byte 0. Nil for a complete file (or one we cannot read).
    public static func status(path: String) -> StreamLimit.Status? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = (attributes[.size] as? NSNumber)?.int64Value, size > 1_000_000 else { return nil }
        let descriptor = open(path, O_RDONLY)
        guard descriptor >= 0 else { return nil }
        defer { close(descriptor) }
        let hole = lseek(descriptor, 0, SEEK_HOLE)
        // SEEK_HOLE reports the end of the file when there is no hole before it.
        guard hole >= 0, Int64(hole) < size else { return nil }
        return StreamLimit.Status(size: size, prefix: Int64(hole))
    }
}
