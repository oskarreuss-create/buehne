import AppKit
import BuehneCore
import SwiftUI

/// Injects synthetic right-clicks through the same monitor path the player uses.
@MainActor
public enum ContextMenuProbe {
    public static let expected = 20

    public static func report() -> String {
        let fired = run()
        let ok = fired == expected
        return "BUEHNE_CONTEXT fired=\(fired) expected=\(expected) \(ok ? "BUEHNE_CONTEXT_OK" : "FAIL")"
    }

    /// Twenty video-area right-clicks: playing/paused, bar shown/hidden, settings open/closed, key/not key.
    public static func run() -> Int {
        let popup = CountingContextMenuPopup()
        let menu = VideoContextMenu()
        menu.popup = popup
        let monitor = InputMonitor()
        let window = makeWindow()
        monitor.isVideoHit = { event in
            guard let content = event.window?.contentView else { return false }
            let local = content.convert(event.locationInWindow, from: nil)
            var hit = content.hitTest(local)
            while let view = hit {
                if view is PlayerLayerView { return true }
                hit = view.superview
            }
            return false
        }
        monitor.onContextMenu = { event in
            menu.present(
                event: event,
                window: window,
                playing: monitor.fullscreen,
                settingsOpen: monitor.settingsOpen,
                text: { L10n.text($0, language: "en") }
            )
        }
        monitor.start()
        let scenarios: [(String, Bool, Bool, Bool, Bool)] = [
            ("play-hidden-closed-key", true, false, false, true),
            ("pause-shown-closed-idle", false, true, false, false),
            ("play-hidden-open-key", true, false, true, true),
            ("pause-shown-open-idle", false, true, true, false),
        ]
        let videoPoints = [
            NSPoint(x: 180, y: 280),
            NSPoint(x: 320, y: 360),
            NSPoint(x: 120, y: 220),
            NSPoint(x: 260, y: 400),
            NSPoint(x: 400, y: 300),
            NSPoint(x: 200, y: 40),
        ]
        for (name, playing, barShown, settingsOpen, key) in scenarios {
            _ = name
            monitor.fullscreen = playing
            monitor.settingsOpen = settingsOpen
            monitor.controlFrame = NSRect(x: 24, y: 16, width: 752, height: 68)
            monitor.barAcceptsHits = barShown
            monitor.settingsFrame = settingsOpen ? NSRect(x: 520, y: 24, width: 250, height: 440) : .null
            if key {
                window.makeKey()
            } else {
                window.resignKey()
            }
            let points = videoPoints.filter { point in
                if barShown, monitor.controlFrame.contains(point) { return false }
                if settingsOpen, monitor.settingsFrame.contains(point) { return false }
                return true
            }
            let chosen = Array(points.prefix(5))
            precondition(chosen.count == 5, "video points overlapped chrome")
            for point in chosen {
                guard let event = NSEvent.mouseEvent(
                    with: .rightMouseDown,
                    location: point,
                    modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber,
                    context: nil,
                    eventNumber: Int.random(in: 1...10_000),
                    clickCount: 1,
                    pressure: 1
                ) else { continue }
                NSApp.sendEvent(event)
            }
        }
        RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.2))
        monitor.stop()
        window.orderOut(nil)
        return popup.count
    }

    private static func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: -32000, y: -32000, width: 800, height: 500),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.alphaValue = 0
        window.setFrameOrigin(NSPoint(x: -32000, y: -32000))
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 500))
        let video = PlayerLayerView(frame: root.bounds)
        video.autoresizingMask = [.width, .height]
        root.addSubview(video)
        let overlay = NSHostingView(rootView: Color.clear)
        overlay.frame = root.bounds
        overlay.autoresizingMask = [.width, .height]
        root.addSubview(overlay)
        window.contentView = root
        window.orderFrontRegardless()
        return window
    }
}
