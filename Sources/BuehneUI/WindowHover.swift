import AppKit
import SwiftUI

/// Full-window tracking. Hit testing stays nil so the bar and video keep their clicks.
struct FloatingHoverTracker: NSViewRepresentable {
    var enabled: Bool
    var onEnter: () -> Void
    var onMove: () -> Void
    var onExit: () -> Void

    func makeNSView(context: Context) -> FloatingHoverView {
        let view = FloatingHoverView()
        view.onEnter = onEnter
        view.onMove = onMove
        view.onExit = onExit
        view.trackingEnabled = enabled
        return view
    }

    func updateNSView(_ view: FloatingHoverView, context: Context) {
        view.onEnter = onEnter
        view.onMove = onMove
        view.onExit = onExit
        let turnedOn = enabled && !view.trackingEnabled
        view.trackingEnabled = enabled
        view.refreshTracking()
        if turnedOn { view.syncIfInside() }
    }
}

public final class FloatingHoverView: NSView {
    public var trackingEnabled = false
    public var onEnter: () -> Void = {}
    public var onMove: () -> Void = {}
    public var onExit: () -> Void = {}
    private var area: NSTrackingArea?

    public override var isOpaque: Bool { false }

    public override func hitTest(_ point: NSPoint) -> NSView? { nil }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        refreshTracking()
    }

    public func refreshTracking() {
        if let area {
            removeTrackingArea(area)
            self.area = nil
        }
        guard trackingEnabled, bounds.width > 1, bounds.height > 1 else { return }
        let next = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(next)
        area = next
        window?.acceptsMouseMovedEvents = true
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        refreshTracking()
    }

    public override func mouseEntered(with event: NSEvent) { onEnter() }
    public override func mouseMoved(with event: NSEvent) { onMove() }
    public override func mouseExited(with event: NSEvent) { onExit() }

    public func syncIfInside() {
        guard trackingEnabled, let window else { return }
        let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        if bounds.contains(point) { onMove() }
    }
}
