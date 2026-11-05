import BuehneCore
import Foundation
import IOKit.pwr_mgt

/// Keeps the display and the system awake while a video plays, and for 30 minutes after a pause.
@MainActor
final class WakeKeeper {
    private var assertionID: IOPMAssertionID = 0
    private var held = false
    private var pausedSince: Date?
    private var phase: PlaybackPhase = .idle
    private var timer: Timer?

    func update(_ newPhase: PlaybackPhase) {
        if newPhase == .paused {
            if phase != .paused { pausedSince = Date() }
        } else {
            pausedSince = nil
        }
        phase = newPhase
        evaluate()
    }

    private func evaluate() {
        timer?.invalidate()
        timer = nil
        let pausedFor = pausedSince.map { Date().timeIntervalSince($0) } ?? 0
        setHeld(WakePolicy.holdsAwake(phase: phase, pausedFor: pausedFor))
        if let delay = WakePolicy.recheckDelay(phase: phase, pausedFor: pausedFor) {
            timer = Timer.scheduledTimer(withTimeInterval: delay + 1, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.evaluate() }
            }
        }
    }

    private func setHeld(_ want: Bool) {
        guard want != held else { return }
        if want {
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertPreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "BÜHNE is playing a video" as CFString,
                &assertionID
            )
            held = result == kIOReturnSuccess
        } else {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
            held = false
        }
    }

    deinit {
        if held { IOPMAssertionRelease(assertionID) }
    }
}
