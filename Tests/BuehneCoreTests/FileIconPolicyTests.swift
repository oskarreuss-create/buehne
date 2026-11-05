import BuehneCore
import Foundation
import Testing

@Test func playableExtensionsIncludeTheContainersThePlayerOpens() {
    #expect(FileIconPolicy.isPlayableExtension("mp4"))
    #expect(FileIconPolicy.isPlayableExtension("MKV"))
    #expect(FileIconPolicy.isPlayableExtension("avi"))
    #expect(!FileIconPolicy.isPlayableExtension("txt"))
    #expect(!FileIconPolicy.isPlayableExtension("jpg"))
    #expect(!FileIconPolicy.isPlayableExtension(""))
}

@Test func frameTimeIsTenPercentAndAMissingDurationIsOneSecond() {
    #expect(FileIconPolicy.frameSeconds(duration: 100) == 10)
    #expect(FileIconPolicy.frameSeconds(duration: nil) == 1)
    #expect(FileIconPolicy.frameSeconds(duration: 0) == 1)
}

@Test func decideSkipsDisabledUnreadableDatalessAndCached() {
    let token = FileIconPolicy.cacheToken(mtime: 10, size: 20)
    #expect(FileIconPolicy.decide(extension: "mp4", readable: true, dataless: false, enabled: true, cachedToken: nil, currentToken: token) == nil)
    #expect(FileIconPolicy.decide(extension: "mp4", readable: true, dataless: false, enabled: false, cachedToken: nil, currentToken: token) == "disabled")
    #expect(FileIconPolicy.decide(extension: "txt", readable: true, dataless: false, enabled: true, cachedToken: nil, currentToken: token) == "extension")
    #expect(FileIconPolicy.decide(extension: "mp4", readable: false, dataless: false, enabled: true, cachedToken: nil, currentToken: token) == "unreadable")
    #expect(FileIconPolicy.decide(extension: "mkv", readable: true, dataless: true, enabled: true, cachedToken: nil, currentToken: token) == "dataless")
    #expect(FileIconPolicy.decide(extension: "avi", readable: true, dataless: false, enabled: true, cachedToken: token, currentToken: token) == "cached")
}

@Test func datalessIsNotDownloadedOrZeroAllocatedBytes() {
    #expect(FileIconPolicy.isDataless(downloadingStatusNotDownloaded: true, allocatedBytes: 100, logicalBytes: 100))
    #expect(FileIconPolicy.isDataless(downloadingStatusNotDownloaded: false, allocatedBytes: 0, logicalBytes: 40))
    #expect(!FileIconPolicy.isDataless(downloadingStatusNotDownloaded: false, allocatedBytes: 40, logicalBytes: 40))
}

@Test func downloadInProgressSparseFileIsSkipped() {
    #expect(FileIconPolicy.isDataless(downloadingStatusNotDownloaded: false, allocatedBytes: 60_000_000, logicalBytes: 49_000_000_000))
    #expect(!FileIconPolicy.isDataless(downloadingStatusNotDownloaded: false, allocatedBytes: 8_688_000_000, logicalBytes: 8_700_000_000))
}

@Test func onlyDownloadsIsScannedByDefaultAndLegacyListMigratesToIt() {
    let home = URL(fileURLWithPath: "/tmp/buehne-icon-home", isDirectory: true)
    #expect(FileIconPolicy.defaultFolders(home: home).map(\.path) == ["/tmp/buehne-icon-home/Downloads"])
    let legacy = FileIconPolicy.legacyDefaultFolders(home: home).map(\.path)
    #expect(legacy == [
        "/tmp/buehne-icon-home/Downloads",
        "/tmp/buehne-icon-home/Movies",
        "/tmp/buehne-icon-home/Documents/Ström",
        "/tmp/buehne-icon-home/Desktop",
    ])
    #expect(FileIconPolicy.migrated(stored: legacy, home: home) == ["/tmp/buehne-icon-home/Downloads"])
    #expect(FileIconPolicy.migrated(stored: [], home: home) == ["/tmp/buehne-icon-home/Downloads"])
    #expect(FileIconPolicy.migrated(stored: ["/tmp/buehne-icon-home/Movies"], home: home) == ["/tmp/buehne-icon-home/Downloads"])
    #expect(FileIconPolicy.migrated(stored: ["/tmp/buehne-icon-home/Videos"], home: home) == ["/tmp/buehne-icon-home/Videos"])
    #expect(FileIconPolicy.concurrency == 4)
    #expect(FileIconPolicy.sizes == [1024, 512, 256, 128, 32])
}
