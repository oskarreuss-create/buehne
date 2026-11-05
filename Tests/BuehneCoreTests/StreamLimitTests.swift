import Foundation
import Testing
@testable import BuehneCore

@Test func streamLimitRecognisesOnlyStromStreams() {
    let ok = StreamLimit(streamURL: URL(string: "http://127.0.0.1:5555/v/abc123/film.mkv")!)
    #expect(ok?.statusURL.absoluteString == "http://127.0.0.1:5555/status/abc123")
    #expect(StreamLimit(streamURL: URL(fileURLWithPath: "/tmp/film.mkv")) == nil)
    #expect(StreamLimit(streamURL: URL(string: "https://example.com/v/abc/film.mkv")!) == nil)
    #expect(StreamLimit(streamURL: URL(string: "http://192.168.1.5:5555/v/abc/film.mkv")!) == nil)
    #expect(StreamLimit(streamURL: URL(string: "http://127.0.0.1:5555/other/abc/film.mkv")!) == nil)
}

@Test func streamLimitFollowsDownloadedPart() {
    let half = StreamLimit.Status(size: 1000, prefix: 500)
    let allowed = StreamLimit.allowedTime(half, duration: 100)
    #expect(allowed > 40 && allowed < 50)
    #expect(StreamLimit.allowedTime(StreamLimit.Status(size: 1000, prefix: 0), duration: 100) == 0)
    #expect(StreamLimit.allowedTime(StreamLimit.Status(size: 1000, prefix: 1000), duration: 100).isInfinite)
    #expect(StreamLimit.allowedTime(half, duration: 0) == 0)
}

@Test func streamLimitCutsOnlyForwardJumps() {
    // Forward jump beyond the limit stops at the limit.
    #expect(StreamLimit.clamp(90, current: 10, allowed: 45) == 45)
    // Allowed jump is untouched.
    #expect(StreamLimit.clamp(30, current: 10, allowed: 45) == 30)
    // Going back is always fine, even if we are past the limit.
    #expect(StreamLimit.clamp(5, current: 50, allowed: 45) == 5)
    // Already past the limit: a forward jump does not move us.
    #expect(StreamLimit.clamp(60, current: 48, allowed: 45) == 48)
}

@Test func partialFileLimitsToDownloadedPart() throws {
    let path = NSTemporaryDirectory() + "partial-\(UUID().uuidString).mkv"
    defer { try? FileManager.default.removeItem(atPath: path) }
    let handle = try #require(FileHandle(forWritingAtPath: { FileManager.default.createFile(atPath: path, contents: nil); return path }()))
    try handle.write(contentsOf: Data(repeating: 7, count: 2_000_000))
    try handle.truncate(atOffset: 100_000_000)
    try handle.close()
    let status = try #require(PartialFile.status(path: path))
    #expect(status.size == 100_000_000)
    #expect(status.prefix >= 2_000_000 && status.prefix < 20_000_000)
    #expect(StreamLimit.allowedTime(status, duration: 1000) < 200)
}

@Test func completeFileHasNoLimit() throws {
    let path = NSTemporaryDirectory() + "full-\(UUID().uuidString).mkv"
    defer { try? FileManager.default.removeItem(atPath: path) }
    FileManager.default.createFile(atPath: path, contents: Data(repeating: 1, count: 3_000_000))
    #expect(PartialFile.status(path: path) == nil)
}
