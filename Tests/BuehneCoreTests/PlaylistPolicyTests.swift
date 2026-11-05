import Testing
@testable import BuehneCore

@Test func playlistKnowsVideoExtensions() {
    #expect(PlaylistPolicy.isVideo(extension: "MKV"))
    #expect(PlaylistPolicy.isVideo(extension: "mp4"))
    #expect(!PlaylistPolicy.isVideo(extension: "txt"))
}

@Test func resumeSkipsStartAndFinishedFilms() {
    #expect(PlaylistPolicy.resumePosition(saved: 0.5, duration: 100) == nil)
    #expect(PlaylistPolicy.resumePosition(saved: 50, duration: 100) == 50)
    #expect(PlaylistPolicy.resumePosition(saved: 97, duration: 100) == nil)
    #expect(PlaylistPolicy.resumePosition(saved: 50, duration: nil) == 50)
}
