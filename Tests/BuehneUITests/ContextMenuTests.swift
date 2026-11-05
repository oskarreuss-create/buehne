import AppKit
import BuehneCore
import Testing
@testable import BuehneUI

@MainActor
@Test func monitorOpensMenuOnVideoRightClickAndControlClickButNotOnTheBar() {
    let window = NSWindow(
        contentRect: NSRect(x: -32000, y: -32000, width: 800, height: 500),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    window.isReleasedWhenClosed = false
    window.alphaValue = 0
    window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
    window.setFrameOrigin(NSPoint(x: -32000, y: -32000))
    window.orderFrontRegardless()
    let monitor = InputMonitor()
    monitor.barAcceptsHits = true
    monitor.controlFrame = NSRect(x: 0, y: 0, width: 800, height: 80)
    var menus = 0
    var paused = false
    monitor.onContextMenu = { _ in menus += 1 }
    monitor.onCommand = { if case .togglePlay = $0 { paused = true } }
    monitor.start()
    send(monitor, .rightMouseDown, NSPoint(x: 120, y: 240), window, .init())
    send(monitor, .rightMouseDown, NSPoint(x: 120, y: 20), window, .init())
    send(monitor, .leftMouseDown, NSPoint(x: 140, y: 240), window, .control)
    #expect(menus == 2)
    #expect(!paused)
    monitor.stop()
    window.orderOut(nil)
}

@MainActor
private func send(_ monitor: InputMonitor, _ type: NSEvent.EventType, _ point: NSPoint, _ window: NSWindow, _ flags: NSEvent.ModifierFlags) {
    guard let event = NSEvent.mouseEvent(
        with: type,
        location: point,
        modifierFlags: flags,
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 1,
        clickCount: 1,
        pressure: 1
    ) else {
        return
    }
    _ = monitor
    NSApp.sendEvent(event)
}
