import BuehneCore
import Testing

@Test func clickOnBarDoesNotPause() {
    var box = InputReducer()
    let commands = box.reduce(.pointerDown(region: .control, xFraction: 0.5, clickCount: 1))
        + box.reduce(.pointerUp(region: .control, xFraction: 0.5, clickCount: 1, held: 0.08))
        + box.reduce(.confirmClick)
    #expect(!commands.contains(.togglePlay))
    var slider = InputReducer()
    let scrub = slider.reduce(.pointerDown(region: .control, xFraction: 0.2, clickCount: 1))
        + slider.reduce(.pointerUp(region: .control, xFraction: 0.4, clickCount: 1, held: 0.4))
    #expect(scrub.isEmpty)
    var card = InputReducer(settingsOpen: true)
    let settings = card.reduce(.pointerDown(region: .settings, xFraction: 0.5, clickCount: 1))
        + card.reduce(.pointerUp(region: .settings, xFraction: 0.5, clickCount: 1, held: 0.05))
        + card.reduce(.confirmClick)
    #expect(!settings.contains(.togglePlay))
    var chrome = InputReducer()
    let edge = chrome.reduce(.pointerDown(region: .chrome, xFraction: 0.1, clickCount: 1))
        + chrome.reduce(.pointerUp(region: .chrome, xFraction: 0.1, clickCount: 1, held: 0.05))
        + chrome.reduce(.confirmClick)
    #expect(edge.isEmpty)
}

@Test func videoClickTogglesOnce() {
    var box = InputReducer()
    #expect(box.reduce(.pointerDown(region: .video, xFraction: 0.4, clickCount: 1)).isEmpty)
    #expect(box.reduce(.pointerUp(region: .video, xFraction: 0.4, clickCount: 1, held: 0.05)).isEmpty)
    #expect(box.wantsClickConfirm)
    #expect(box.reduce(.confirmClick) == [.togglePlay])
    #expect(box.reduce(.confirmClick).isEmpty)
}

@Test func rightClickOpensVideoMenuWithoutPausing() {
    var box = InputReducer()
    // Cancel a pending single click instead of pausing behind the menu.
    _ = box.reduce(.pointerDown(region: .video, xFraction: 0.4, clickCount: 1))
    _ = box.reduce(.pointerUp(region: .video, xFraction: 0.4, clickCount: 1, held: 0.05))
    #expect(box.reduce(.secondaryClick(region: .video)) == [.showContextMenu])
    #expect(box.reduce(.confirmClick).isEmpty)
    #expect(box.reduce(.holdDelayElapsed).isEmpty)
    #expect(box.reduce(.pointerUp(region: .video, xFraction: 0.4, clickCount: 1, held: 0.05)).isEmpty)
    for region: PointerRegion in [.control, .settings, .chrome, .activating, .outside] {
        var excluded = InputReducer()
        #expect(excluded.reduce(.secondaryClick(region: region)).isEmpty)
        #expect(excluded.reduce(.confirmClick).isEmpty)
    }
    var settings = InputReducer(settingsOpen: true)
    #expect(settings.reduce(.secondaryClick(region: .video)) == [.showContextMenu])
}

@Test func secondaryClickIgnoresKeyPlaybackAndHiddenBar() {
    let open = InputReducer.secondary(pointInWindow: true, onVisibleControl: false, onSettingsCard: false, onChrome: false)
    #expect(open.showMenu && open.region == .video)
    let hiddenBar = InputReducer.secondary(pointInWindow: true, onVisibleControl: false, onSettingsCard: false, onChrome: false)
    #expect(hiddenBar.showMenu)
    let bar = InputReducer.secondary(pointInWindow: true, onVisibleControl: true, onSettingsCard: false, onChrome: false)
    #expect(!bar.showMenu && bar.region == .control)
    let card = InputReducer.secondary(pointInWindow: true, onVisibleControl: false, onSettingsCard: true, onChrome: false)
    #expect(!card.showMenu && card.region == .settings)
    let chrome = InputReducer.secondary(pointInWindow: true, onVisibleControl: false, onSettingsCard: false, onChrome: true)
    #expect(!chrome.showMenu && chrome.region == .chrome)
    var box = InputReducer()
    _ = box.reduce(.pointerDown(region: .control, xFraction: 0.5, clickCount: 1))
    let right = box.reduce(.secondaryClick(region: .control))
    #expect(!right.contains(.togglePlay))
    #expect(box.reduce(.confirmClick).isEmpty)
}

@Test func rightClickEndsHoldBeforeOpeningMenu() {
    var box = InputReducer()
    _ = box.reduce(.pointerDown(region: .video, xFraction: 0.8, clickCount: 1))
    #expect(box.reduce(.holdDelayElapsed) == [.beginFastForward])
    #expect(box.reduce(.secondaryClick(region: .video)) == [.endFastForward, .showContextMenu])
    #expect(box.reduce(.confirmClick).isEmpty)
}

@Test func windowActivationClickIsIgnored() {
    #expect(InputReducer.region(windowWasKey: false, inControl: false, inSettings: false, inChrome: false, inVideo: true) == .activating)
    var box = InputReducer()
    let commands = box.reduce(.pointerDown(region: .activating, xFraction: 0.5, clickCount: 1))
        + box.reduce(.pointerUp(region: .activating, xFraction: 0.5, clickCount: 1, held: 0.04))
        + box.reduce(.confirmClick)
    #expect(commands.isEmpty)
    #expect(InputReducer.region(windowWasKey: true, inControl: true, inSettings: false, inChrome: false, inVideo: true) == .control)
}

@Test func doubleClickFullscreensWithoutPause() {
    var box = InputReducer()
    box.reduce(.pointerDown(region: .video, xFraction: 0.5, clickCount: 1))
    box.reduce(.pointerUp(region: .video, xFraction: 0.5, clickCount: 1, held: 0.05))
    let second = box.reduce(.pointerDown(region: .video, xFraction: 0.5, clickCount: 2))
    let confirm = box.reduce(.confirmClick)
    #expect(second == [.toggleFullscreen])
    #expect(confirm.isEmpty)
}

@Test func scrollUpRaisesAndScrollDownLowers() {
    var classic = InputReducer(volume: 0.5)
    let classicDelta = volumeDelta(classic.reduce(.scroll(deltaX: 0, deltaY: 10, natural: false, precise: true, ended: false)))
    #expect(abs((classicDelta ?? 0) - 0.06) < 0.000_1)
    var naturalUp = InputReducer(volume: 0.5)
    let raised = volumeDelta(naturalUp.reduce(.scroll(deltaX: 0, deltaY: -8, natural: true, precise: true, ended: false)))
    #expect(abs((raised ?? 0) - 0.048) < 0.000_1)
    #expect(abs(naturalUp.volume - 0.548) < 0.000_1)
    var naturalDown = InputReducer(volume: 0.5)
    let lowered = volumeDelta(naturalDown.reduce(.scroll(deltaX: 0, deltaY: 8, natural: true, precise: true, ended: false)))
    #expect(abs((lowered ?? 0) + 0.048) < 0.000_1)
    var clamped = InputReducer(volume: 0.99)
    let topped = clamped.reduce(.scroll(deltaX: 0, deltaY: 100, natural: false, precise: false, ended: true))
    #expect(abs((volumeDelta(topped) ?? 0) - 0.01) < 0.000_1)
    #expect(clamped.volume == 1)
}

@Test func everyHotkeyMapsToOneCommand() {
    var box = InputReducer(volume: 0.4, rate: 1, settingsOpen: false, fullscreen: true)
    #expect(box.reduce(.key(.space)) == [.togglePlay])
    #expect(box.reduce(.key(.left)) == [.seek(-10)])
    #expect(box.reduce(.key(.right)) == [.seek(10)])
    #expect(abs((volumeDelta(box.reduce(.key(.up))) ?? 0) - 0.05) < 0.000_1)
    #expect(abs((volumeDelta(box.reduce(.key(.down))) ?? 0) + 0.05) < 0.000_1)
    #expect(box.reduce(.key(.escape)) == [.exitFullscreen])
    #expect(box.reduce(.key(.f)) == [.toggleFullscreen])
    #expect(box.reduce(.key(.m)) == [.toggleMute])
    #expect(box.reduce(.key(.speedDown)) == [.adjustRate(-0.25)])
    #expect(box.reduce(.key(.speedUp)) == [.adjustRate(0.25)])
    #expect(box.reduce(.key(.audioNext)) == [.cycleAudio])
    #expect(box.reduce(.key(.subtitleNext)) == [.cycleSubtitle])
    #expect(box.reduce(.key(.openFile)) == [.openFile])
    #expect(box.reduce(.key(.settings)) == [.toggleSettings])
    box.settingsOpen = true
    #expect(box.reduce(.key(.space)).isEmpty)
    #expect(box.reduce(.key(.escape)) == [.closeSettings])
}

@Test func holdOnVideoDoesNotToggle() {
    var box = InputReducer()
    box.reduce(.pointerDown(region: .video, xFraction: 0.8, clickCount: 1))
    #expect(box.reduce(.holdDelayElapsed) == [.beginFastForward])
    #expect(box.reduce(.pointerUp(region: .video, xFraction: 0.8, clickCount: 1, held: 0.4)) == [.endFastForward])
    #expect(box.reduce(.confirmClick).isEmpty)
    var left = InputReducer()
    left.reduce(.pointerDown(region: .video, xFraction: 0.2, clickCount: 1))
    #expect(left.reduce(.holdDelayElapsed) == [.beginRewind])
    var bar = InputReducer()
    bar.reduce(.pointerDown(region: .control, xFraction: 0.9, clickCount: 1))
    #expect(bar.reduce(.holdDelayElapsed).isEmpty)
}

private func volumeDelta(_ commands: [PlayerCommand]) -> Double? {
    for case let .adjustVolume(delta) in commands { return delta }
    return nil
}
