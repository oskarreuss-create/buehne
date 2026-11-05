import AppKit
import BuehneCore
import Testing
import BuehneUI

@MainActor
private func mouseDownEvent() -> NSEvent {
    NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: NSPoint(x: 16, y: 16),
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        eventNumber: 1,
        clickCount: 1,
        pressure: 1
    )!
}

@MainActor
@Test func barHitFiresOnMouseDownAndNotAgainOnMouseUp() {
    var fires = 0
    let view = BarHitView(frame: NSRect(x: 0, y: 0, width: BarHitPolicy.side, height: BarHitPolicy.side))
    view.onDown = { fires += 1 }
    let down = mouseDownEvent()
    let up = NSEvent.mouseEvent(
        with: .leftMouseUp,
        location: NSPoint(x: 16, y: 16),
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        eventNumber: 1,
        clickCount: 1,
        pressure: 0
    )!
    view.mouseDown(with: down)
    view.mouseUp(with: up)
    #expect(fires == 1)
    #expect(view.acceptsFirstMouse(for: nil))
    #expect(view.frame.width >= 32 && view.frame.height >= 32)
    #expect(view.frame.width >= 32 && view.frame.height >= 32)
    let side = BarScale.hitSide(BarHitPolicy.side, scale: BarScale.minimum)
    #expect(side >= BarScale.minimumHit)
    let small = BarHitView(frame: NSRect(x: 0, y: 0, width: side, height: side))
    var smallFires = 0
    small.onDown = { smallFires += 1 }
    small.mouseDown(with: down)
    small.mouseUp(with: up)
    #expect(smallFires == 1)
    #expect(small.frame.width >= 24 && small.frame.height >= 24)
    #expect(small.acceptsFirstMouse(for: nil))
}

@MainActor
@Test func expandButtonActionCountEqualsClicks() {
    var floating = false
    var count = 0
    let view = BarHitView(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
    view.onDown = {
        floating = FloatingApply.toggled(floating)
        count += 1
    }
    let down = mouseDownEvent()
    view.mouseDown(with: down)
    view.mouseDown(with: down)
    #expect(count == 2)
    #expect(floating == false)
}

@MainActor
@Test func gearHitTogglesTwiceInTwoMouseDowns() {
    var open = false
    let view = BarHitView(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
    view.onDown = { open = SettingsClick.afterGear(open: open) }
    let down = mouseDownEvent()
    view.mouseDown(with: down)
    #expect(open)
    view.mouseDown(with: down)
    #expect(!open)
}
@MainActor
@Test func hoverTrackerInstallsEnteredExitedAndMoved() {
    let view = FloatingHoverView(frame: NSRect(x: 0, y: 0, width: 320, height: 180))
    view.trackingEnabled = true
    let window = NSWindow(
        contentRect: NSRect(x: -32000, y: -32000, width: 320, height: 180),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.setFrameOrigin(NSPoint(x: -32000, y: -32000))
    window.contentView = view
    view.refreshTracking()
    let options = view.trackingAreas.first?.options ?? []
    #expect(!view.trackingAreas.isEmpty)
    #expect(options.contains(.mouseEnteredAndExited))
    #expect(options.contains(.mouseMoved))
    #expect(options.contains(.activeAlways))
    #expect(view.hitTest(NSPoint(x: 10, y: 10)) == nil)
    var enters = 0
    var exits = 0
    var moves = 0
    view.onEnter = { enters += 1 }
    view.onExit = { exits += 1 }
    view.onMove = { moves += 1 }
    let down = mouseDownEvent()
    view.mouseEntered(with: down)
    view.mouseMoved(with: down)
    view.mouseExited(with: down)
    #expect(enters == 1 && moves == 1 && exits == 1)
    window.orderOut(nil)
}
