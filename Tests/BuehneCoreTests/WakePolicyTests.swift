import Testing
@testable import BuehneCore

@Test func screenStaysAwakeWhilePlayingAndForHalfAnHourAfterPause() {
    #expect(WakePolicy.holdsAwake(phase: .playing, pausedFor: 0))
    #expect(WakePolicy.holdsAwake(phase: .opening, pausedFor: 0))
    #expect(WakePolicy.holdsAwake(phase: .paused, pausedFor: 29 * 60))
    #expect(!WakePolicy.holdsAwake(phase: .paused, pausedFor: 30 * 60))
    #expect(!WakePolicy.holdsAwake(phase: .idle, pausedFor: 0))
    #expect(!WakePolicy.holdsAwake(phase: .failed, pausedFor: 0))
    #expect(WakePolicy.recheckDelay(phase: .paused, pausedFor: 10 * 60) == Optional(1200.0))
    #expect(WakePolicy.recheckDelay(phase: .playing, pausedFor: 0) == nil)
}
