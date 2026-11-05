import AppKit
import BuehneCore
@testable import BuehneUI
import Testing

@Test @MainActor func nativeVideoMenuContainsActionsAndDispatches() {
    _ = NSApplication.shared
    let window = MenuWindowProbe(contentRect: NSRect(x: -32000, y: -32000, width: 640, height: 360),
                                 styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    defer { window.close() }
    let owner = VideoContextMenu()
    var commands: [PlayerCommand] = []
    owner.onCommand = { commands.append($0) }
    let text: (L10nKey) -> String = { L10n.text($0, language: "en") }
    let menu = owner.makeMenu(window: window, playing: true, settingsOpen: false, text: text)
    #expect(menu.items.filter { !$0.isSeparatorItem }.map(\.title) == [
        "Pause", "Minimize", "Close", "Full Screen", "Always on Top", "Open File…", "Settings"
    ])
    #expect(menu.items.filter { !$0.isSeparatorItem }.allSatisfy { $0.target === owner && $0.action != nil && $0.isEnabled })
    for title in ["Pause", "Open File…", "Settings"] {
        menu.performActionForItem(at: menu.indexOfItem(withTitle: title))
    }
    #expect(commands == [.togglePlay, .openFile, .toggleSettings])
    for title in ["Minimize", "Close", "Full Screen"] {
        menu.performActionForItem(at: menu.indexOfItem(withTitle: title))
    }
    #expect(window.actions == ["minimize", "close", "fullscreen"])
    let top = menu.indexOfItem(withTitle: "Always on Top")
    menu.performActionForItem(at: top)
    #expect(window.level == .floating)
    #expect(menu.item(at: top)?.state == .on)
    let reopened = owner.makeMenu(window: window, playing: false, settingsOpen: true, text: text)
    #expect(reopened.items.first?.title == "Play")
    #expect(reopened.item(withTitle: "Always on Top")?.state == .on)
    #expect(reopened.item(withTitle: "Settings")?.state == .on)
    reopened.performActionForItem(at: reopened.indexOfItem(withTitle: "Always on Top"))
    #expect(window.level == .normal)
}

@Test @MainActor func rightMouseMonitorRoutesVideoButNotBar() {
    _ = NSApplication.shared
    let window = NSWindow(contentRect: NSRect(x: -32000, y: -32000, width: 640, height: 360),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let monitor = InputMonitor()
    var menus = 0
    var commands: [PlayerCommand] = []
    monitor.controlFrame = CGRect(x: 0, y: 0, width: 200, height: 100)
    monitor.isVideoHit = { $0.window === window }
    monitor.onContextMenu = { _ in menus += 1 }
    monitor.onCommand = { commands.append($0) }
    monitor.start()
    defer { monitor.stop(); window.close() }
    func send(_ point: NSPoint) {
        let event = NSEvent.mouseEvent(with: .rightMouseDown, location: point, modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
        NSApp.sendEvent(event)
    }
    send(NSPoint(x: 300, y: 250))
    #expect(menus == 1)
    send(NSPoint(x: 50, y: 50))
    #expect(menus == 1)
    // A right-click on the video opens the menu even while settings are open
    // (the settings panel itself is a separate hit region).
    monitor.settingsOpen = true
    send(NSPoint(x: 300, y: 250))
    #expect(menus == 2)
    #expect(!commands.contains(.togglePlay))
}

/// Assert dispatch to the correct AppKit APIs without foreground transitions.
@MainActor
private final class MenuWindowProbe: NSWindow {
    var actions: [String] = []
    override func miniaturize(_ sender: Any?) { actions.append("minimize") }
    override func performClose(_ sender: Any?) { actions.append("close") }
    override func toggleFullScreen(_ sender: Any?) { actions.append("fullscreen") }
}
