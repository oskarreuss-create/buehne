import AppKit
import BuehneCore
import SwiftUI

/// Fixed hit target. The glyph may scale; this view does not, so the hit rect stays put.
public final class BarHitView: NSView {
    public var onDown: () -> Void = {}
    public var onUp: () -> Void = {}
    public var onHover: (Bool) -> Void = { _ in }

    public override var isOpaque: Bool { false }
    public override var mouseDownCanMoveWindow: Bool { false }

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        BarHitPolicy.acceptsFirstMouse
    }

    public override func mouseDown(with event: NSEvent) {
        guard BarHitPolicy.firesOnMouseDown else { return }
        onDown()
    }

    public override func mouseDragged(with event: NSEvent) {}

    public override func mouseUp(with event: NSEvent) {
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

    func makeNSView(context: Context) -> BarHitView {
        let view = BarHitView(frame: NSRect(x: 0, y: 0, width: side, height: side))
        return view
    }

    func updateNSView(_ view: BarHitView, context: Context) {
        view.setFrameSize(NSSize(width: side, height: side))
        view.onDown = onDown
        view.onUp = onUp
        view.onHover = { hovering = $0 }
    }
}

struct BarIconButton<Icon: View>: View {
    var label: String
    var identifier: String
    var action: () -> Void
    var onUp: () -> Void = {}
    @ViewBuilder var icon: () -> Icon
    @Environment(\.buehneBarScale) private var barScale
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
            .overlay(BarHitTarget(side: side, hovering: $hovering, onDown: action, onUp: onUp))
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
