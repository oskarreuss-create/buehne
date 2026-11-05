import Foundation
import BuehneCore
import Testing

@Test func nativeContainersUseAVFoundation() {
    for name in ["clip.mp4", "clip.MP4", "clip.m4v", "clip.mov", "clip.MoV"] {
        let route = EngineRouter.route(URL(fileURLWithPath: "/tmp/\(name)"))
        #expect(route.kind == .avFoundation)
    }
    let remote = EngineRouter.route(URL(string: "https://example.com/a/clip.mp4?token=1")!)
    #expect(remote.kind == .avFoundation)
}

@Test func everythingElseUsesLibmpv() {
    for name in ["film.mkv", "film.avi", "film.webm", "film.wmv", "noext", "film.dv"] {
        let route = EngineRouter.route(URL(fileURLWithPath: "/tmp/\(name)"))
        #expect(route.kind == .libmpv)
    }
}

@Test func rateStaysInsideTheContract() {
    #expect(RateRange.clamp(0.1) == 0.5)
    #expect(RateRange.clamp(3) == 3)
    #expect(RateRange.clamp(4) == 4)
    #expect(RateRange.clamp(5) == 4)
    #expect(RateRange.clamp(1.25) == 1.25)
}

@Test func openingSizeNeverExceedsTheScreen() {
    let fitted = WindowGeometry.openingSize(videoWidth: 4000, videoHeight: 2000, screenWidth: 1440, screenHeight: 900)
    #expect(fitted?.width == 864)
    #expect(fitted?.height == 432)
    #expect(WindowGeometry.openingSize(videoWidth: 0, videoHeight: 1080, screenWidth: 1440, screenHeight: 900) == nil)
}

@Test func floatingModeCannotExceedAQuarterOfTheScreen() {
    let screenW = 1440.0
    let screenH = 900.0
    let cap = WindowGeometry.floatingMaxSize(screenWidth: screenW, screenHeight: screenH, aspect: 16.0 / 9.0)
    let area = cap.width * cap.height
    #expect(area <= screenW * screenH / 9 + 0.001)
    #expect(abs((cap.width / cap.height) - (16.0 / 9.0)) < 0.001)
}

@Test func launchURLExtractsTheMediaPath() {
    let spaced = OpenContract.mediaURL(fromLaunchURL: URL(string: "buehne://open?path=/tmp/my%20clip.mp4")!)
    #expect(spaced?.path == "/tmp/my clip.mp4")
    let remote = OpenContract.mediaURL(fromLaunchURL: URL(string: "buehne://open?path=https://example.com/a.mp4")!)
    #expect(remote?.absoluteString == "https://example.com/a.mp4")
    #expect(OpenContract.mediaURL(fromLaunchURL: URL(string: "buehne://open")!) == nil)
    #expect(OpenContract.mediaURL(fromLaunchURL: URL(fileURLWithPath: "/tmp/a b.mkv"))?.path == "/tmp/a b.mkv")
    let fromArgs = OpenContract.mediaURL(from: ["Buehne", "--self-check", "/tmp/clip.mp4"])
    #expect(fromArgs?.path == "/tmp/clip.mp4")
    #expect(OpenContract.mediaURL(parsing: "https://example.com/a.mkv")?.pathExtension == "mkv")
}
