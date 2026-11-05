import Testing
@testable import BuehneCore

@Test func barShedsPartsAsItShrinks() {
    #expect(BarTier.forWidth(500) == .full)
    #expect(BarTier.forWidth(300) == .compact)
    #expect(BarTier.forWidth(180) == .minimal)
}

@Test func newPointerDownReleasesAStuckHold() {
    var box = InputReducer()
    _ = box.reduce(.pointerDown(region: .video, xFraction: 0.8, clickCount: 1))
    _ = box.reduce(.holdDelayElapsed)
    let next = box.reduce(.pointerDown(region: .video, xFraction: 0.8, clickCount: 1))
    #expect(next.contains(.endFastForward))
}
