import Foundation

/// A video file that is still being downloaded by a torrent client is a sparse file: its size is final, but only
/// part of the bytes are on disk. Playing past that part freezes the picture while the sound goes on.
/// The rule is the same as for a STRÖM stream: never let the viewer jump past what has been downloaded.
public enum PartialFile {
    /// The file exists only in iCloud: reading it first downloads it, which can take minutes.
    public static func isCloudOnly(path: String) -> Bool {
        var info = stat()
        return stat(path, &info) == 0 && info.st_flags & 0x4000_0000 != 0   // SF_DATALESS
    }

    /// Size and the length of the continuous part from byte 0. Nil for a complete file (or one we cannot read).
    public static func status(path: String) -> StreamLimit.Status? {
        var info = stat()
        guard stat(path, &info) == 0, info.st_size > 1_000_000 else { return nil }
        let size = Int64(info.st_size)
        // A cloud-only file (iCloud) has no local data: opening and probing it would start a download and block.
        if info.st_flags & 0x4000_0000 != 0 { return nil }   // SF_DATALESS
        // Nearly all blocks are on disk: an ordinary complete file, nothing to probe.
        guard Int64(info.st_blocks) * 512 < size / 100 * 98 else { return nil }
        let descriptor = open(path, O_RDONLY)
        guard descriptor >= 0 else { return nil }
        defer { close(descriptor) }
        let hole = lseek(descriptor, 0, SEEK_HOLE)
        // SEEK_HOLE reports the end of the file when there is no hole before it.
        guard hole >= 0, Int64(hole) < size else { return nil }
        return StreamLimit.Status(size: size, prefix: Int64(hole))
    }
}
