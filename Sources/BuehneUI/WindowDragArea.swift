import AppKit
import SwiftUI

/// Dragging anywhere on this area moves the window. The welcome window is borderless, so there is no
/// title bar to grab. Buttons and the control bar sit above it and keep their own clicks.
struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            // The glass is composited outside the window's backing store, so the window server sees the
            // card as (nearly) transparent and lets clicks fall through to whatever is behind. A
            // 2% layer makes the whole card catch the mouse without visibly changing it.
            wantsLayer = true
            layer?.backgroundColor = NSColor(white: 0, alpha: 0.02).cgColor
        }
        required init?(coder: NSCoder) { fatalError() }
        override var mouseDownCanMoveWindow: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }

    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ view: DragView, context: Context) {}
}
