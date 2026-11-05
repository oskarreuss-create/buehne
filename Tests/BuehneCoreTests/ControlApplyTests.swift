import Testing
import BuehneCore

@Test func volumeWritesEveryEventAndPersistsOnlyTheLast() {
    let values = (0..<50).map { Double($0) / 49.0 }
    let writes = VolumeApply.engineWrites(values)
    #expect(writes.count == 50)
    #expect(writes[0] == 0)
    #expect(writes[49] == 1)
    #expect(VolumeApply.persistValue(values) == 1)
    #expect(VolumeApply.clamp(-1) == 0)
    #expect(VolumeApply.clamp(2) == 1)
}

@Test func rateWritesEveryEventImmediately() {
    let values = [0.2, 1, 4, 9]
    let writes = RateApply.engineWrites(values)
    #expect(writes == [0.5, 1, 4, 4])
}

@Test func eitherSubtitleOffClearsBothWhenBothAreOn() {
    let fromPrimary = SubtitleOffRule.afterOff(primaryOn: true, secondaryOn: true, which: .primary)
    let fromSecondary = SubtitleOffRule.afterOff(primaryOn: true, secondaryOn: true, which: .secondary)
    #expect(fromPrimary.primary == false && fromPrimary.secondary == false)
    #expect(fromSecondary.primary == false && fromSecondary.secondary == false)
    let onlyPrimary = SubtitleOffRule.afterOff(primaryOn: true, secondaryOn: false, which: .primary)
    #expect(onlyPrimary.primary == false && onlyPrimary.secondary == false)
    let onlySecondary = SubtitleOffRule.afterOff(primaryOn: false, secondaryOn: true, which: .secondary)
    #expect(onlySecondary.primary == false && onlySecondary.secondary == false)
    let otherRow = SubtitleOffRule.afterOff(primaryOn: true, secondaryOn: false, which: .secondary)
    #expect(otherRow.primary == true && otherRow.secondary == false)
}

@Test func trafficLightsShowOnlyWhenFloatingPausedWithMedia() {
    #expect(TrafficLightVisibility.show(fullscreen: false, paused: true, hasMedia: true))
    #expect(!TrafficLightVisibility.show(fullscreen: false, paused: false, hasMedia: true))
    #expect(!TrafficLightVisibility.show(fullscreen: true, paused: true, hasMedia: true))
    #expect(!TrafficLightVisibility.show(fullscreen: false, paused: true, hasMedia: false))
}

@Test func gearClickTogglesTwiceInTwoClicks() {
    var open = false
    open = SettingsClick.resolve(open: open, gear: true, outside: true)
    #expect(open)
    open = SettingsClick.resolve(open: open, gear: true, outside: true)
    #expect(!open)
    #expect(SettingsClick.afterGear(open: false))
    #expect(!SettingsClick.afterGear(open: true))
    #expect(!SettingsClick.afterOutside(open: true))
}

@Test func expandActionCountEqualsClicks() {
    let once = FloatingApply.actions(clicks: 1)
    let twice = FloatingApply.actions(clicks: 2)
    #expect(once.count == 1 && once.floating)
    #expect(twice.count == 2 && !twice.floating)
    let floating = FloatingApply.contentSize(
        floating: true, screenWidth: 1440, screenHeight: 900, aspect: 16.0 / 9.0,
        restoredWidth: 864, restoredHeight: 486
    )
    let restored = FloatingApply.contentSize(
        floating: false, screenWidth: 1440, screenHeight: 900, aspect: 16.0 / 9.0,
        restoredWidth: 864, restoredHeight: 486
    )
    #expect(floating.width * floating.height < 864 * 486)
    #expect(restored.width == 864 && restored.height == 486)
    #expect(BarHitPolicy.side >= 32)
    #expect(BarHitPolicy.acceptsFirstMouse)
    #expect(BarHitPolicy.firesOnMouseDown)
}
@Test func floatingBarShowsOnEnterAndHidesAfterLeaveDelay() {
    var bar = FloatingBarVisibility()
    #expect(bar.reduce(.entered) == .show)
    #expect(bar.visible && bar.inside && !bar.hideArmed)
    #expect(bar.reduce(.exited) == .armHide)
    #expect(bar.visible && bar.hideArmed)
    #expect(bar.reduce(.hideDelayElapsed) == .hide)
    #expect(!bar.visible && !bar.hideArmed)
    #expect(FloatingBarVisibility.fadeIn == 0.15)
    #expect(FloatingBarVisibility.hideDelay == 0.1)
    #expect(TrafficLightVisibility.show(fullscreen: false, paused: true, hasMedia: true))
}

@Test func floatingBarReenterWithinDelayCancelsHide() {
    var bar = FloatingBarVisibility()
    _ = bar.reduce(.entered)
    _ = bar.reduce(.exited)
    #expect(bar.reduce(.entered) == .show)
    #expect(bar.visible && !bar.hideArmed)
    #expect(bar.reduce(.hideDelayElapsed) == .hold)
    #expect(bar.visible)
    _ = bar.reduce(.exited)
    #expect(bar.reduce(.moved) == .show)
    #expect(bar.visible && bar.inside)
    #expect(bar.reduce(.moved) == .hold)
}

@Test func floatingBarDragAndSettingsHoldVisibilityOutside() {
    var dragging = FloatingBarVisibility()
    _ = dragging.reduce(.entered)
    #expect(dragging.reduce(.dragging(true)) == .cancelHide)
    #expect(dragging.reduce(.exited) == .cancelHide)
    #expect(dragging.visible && !dragging.hideArmed)
    #expect(dragging.reduce(.hideDelayElapsed) == .hold)
    #expect(dragging.visible)
    #expect(dragging.reduce(.dragging(false)) == .armHide)
    #expect(dragging.reduce(.hideDelayElapsed) == .hide)
    #expect(!dragging.visible)

    var settings = FloatingBarVisibility()
    _ = settings.reduce(.entered)
    _ = settings.reduce(.settings(true))
    _ = settings.reduce(.exited)
    #expect(settings.visible)
    #expect(settings.reduce(.hideDelayElapsed) == .hold)
    #expect(settings.reduce(.settings(false)) == .armHide)
    #expect(settings.reduce(.hideDelayElapsed) == .hide)
    #expect(!settings.visible)
    #expect(TrafficLightVisibility.show(fullscreen: false, paused: true, hasMedia: true))
    #expect(!TrafficLightVisibility.show(fullscreen: false, paused: false, hasMedia: true))
}
