import AppKit
import BuehneCore
import SwiftUI

/// Fixed hit target. The glyph may scale; this view does not, so the hit rect stays put.
/// A press that stays put is a click (fires on release, or after a short hold for press-and-hold buttons);
/// a press that moves drags the whole control bar instead. Only the seek slider drags in place.
public final class BarHitView: NSView {
    public var onDown: () -> Void = {}
    public var onUp: () -> Void = {}
    public var onHover: (Bool) -> Void = { _ in }
    public var onDrag: (CGSize) -> Void = { _ in }
    public var onDragEnd: () -> Void = {}

    static let dragThreshold: CGFloat = 4
    static let holdDelay: TimeInterval = 0.18

    private var origin: NSPoint?
    private var dragging = false
    private var fired = false
    private var holdWork: DispatchWorkItem?

    public override var isOpaque: Bool { false }
    public override var mouseDownCanMoveWindow: Bool { false }

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        BarHitPolicy.acceptsFirstMouse
    }

    public override func mouseDown(with event: NSEvent) {
        guard BarHitPolicy.firesOnMouseDown else { return }
        origin = event.locationInWindow
        dragging = false
        fired = false
        holdWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.dragging, !self.fired else { return }
            self.fired = true
            self.onDown()
        }
        holdWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.holdDelay, execute: work)
    }

    public override func mouseDragged(with event: NSEvent) {
        guard let origin else { return }
        let p = event.locationInWindow
        let delta = CGSize(width: p.x - origin.x, height: origin.y - p.y)
        if !dragging {
            guard hypot(delta.width, delta.height) > Self.dragThreshold else { return }
            dragging = true
            holdWork?.cancel()
            if fired { onUp() }
        }
        onDrag(delta)
    }

    public override func mouseUp(with event: NSEvent) {
        holdWork?.cancel()
        defer {
            origin = nil
            dragging = false
            fired = false
        }
        if dragging {
            onDragEnd()
            return
        }
        if !fired { onDown() }
        onUp()
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    public override func mouseEntered(with event: NSEvent) { onHover(true) }
    public override func mouseExited(with event: NSEvent) { onHover(false) }
}

struct BarHitTarget: NSViewRepresentable {
    var side: CGFloat
    @Binding var hovering: Bool
    var onDown: () -> Void
    var onUp: () -> Void = {}
    var onDrag: (CGSize) -> Void = { _ in }
    var onDragEnd: () -> Void = {}

    func makeNSView(context: Context) -> BarHitView {
        let view = BarHitView(frame: NSRect(x: 0, y: 0, width: side, height: side))
        return view
    }

    func updateNSView(_ view: BarHitView, context: Context) {
        view.setFrameSize(NSSize(width: side, height: side))
        view.onDown = onDown
        view.onUp = onUp
        view.onDrag = onDrag
        view.onDragEnd = onDragEnd
        view.onHover = { hovering = $0 }
    }
}

struct BarDragActions: @unchecked Sendable {
    var onMove: (CGSize) -> Void = { _ in }
    var onEnd: () -> Void = {}
}

private struct BarDragKey: EnvironmentKey {
    static let defaultValue = BarDragActions()
}

extension EnvironmentValues {
    var buehneBarDrag: BarDragActions {
        get { self[BarDragKey.self] }
        set { self[BarDragKey.self] = newValue }
    }
}

struct BarIconButton<Icon: View>: View {
    var label: String
    var identifier: String
    var action: () -> Void
    var onUp: () -> Void = {}
    @ViewBuilder var icon: () -> Icon
    @Environment(\.buehneBarScale) private var barScale
    @Environment(\.buehneBarDrag) private var barDrag
    @State private var hovering = false
    @State private var showTip = false
    @State private var tipTask: Task<Void, Never>?

    var body: some View {
        let side = CGFloat(BarScale.hitSide(BarHitPolicy.side, scale: barScale))
        let hover = BarScale.hoverMagnification(scale: barScale)
        icon()
            .scaleEffect(hovering ? hover : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.68), value: hovering)
            .allowsHitTesting(false)
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .overlay(BarHitTarget(side: side, hovering: $hovering, onDown: action, onUp: onUp, onDrag: barDrag.onMove, onDragEnd: barDrag.onEnd))
            .overlay(alignment: .top) {
                if showTip && !label.isEmpty {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.82)))
                        .offset(y: -side - 2)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .zIndex(showTip ? 10 : 0)
            .onChange(of: hovering) { _, now in
                tipTask?.cancel()
                if now {
                    tipTask = Task {
                        try? await Task.sleep(for: .milliseconds(120))
                        if !Task.isCancelled { showTip = true }
                    }
                } else {
                    showTip = false
                }
            }
            .accessibilityLabel(label)
            .accessibilityIdentifier(identifier)
            .accessibilityAddTraits(.isButton)
    }
}
