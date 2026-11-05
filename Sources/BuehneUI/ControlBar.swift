import BuehneCore
import BuehneEngine
import AppKit
import SwiftUI

private struct BarWidthKey: EnvironmentKey { static let defaultValue: CGFloat = 0 }
extension EnvironmentValues {
    var buehneBarWidth: CGFloat {
        get { self[BarWidthKey.self] }
        set { self[BarWidthKey.self] = newValue }
    }
}

struct ControlBar: View {
    @ObservedObject var session: PlayerSession
    @ObservedObject var settings: BuehneSettings
    @Binding var volumeOpen: Bool
    @Binding var scrubTime: Double?
    var isLight: Bool
    var isFullscreen: Bool = false
    var onFloating: () -> Void
    var onPip: () -> Void
    var onSettings: () -> Void
    var onVolume: () -> Void = {}
    var onDrag: (Bool) -> Void = { _ in }
    var onMove: (CGSize) -> Void = { _ in }
    var onMoveEnd: () -> Void = {}
    @Environment(\.buehneBarScale) private var barScale
    @Environment(\.buehneBarWidth) private var barWidth
    @State private var playlistOpen = false
    @ObservedObject private var playlistStore = PlaylistStore.shared

    private func px(_ value: CGFloat) -> CGFloat { CGFloat(BarScale.points(Double(value), scale: barScale)) }
    private func iconPx(_ value: CGFloat) -> CGFloat { CGFloat(BarScale.icon(Double(value), scale: barScale)) }
    var body: some View {
        let duration = session.snapshot.duration
        let shown = scrubTime ?? session.snapshot.currentTime
        GeometryReader { geometry in
            let tier = BarTier.forWidth(Double(geometry.size.width))
            HStack(spacing: 0) {
                if tier == .minimal {
                    Spacer(minLength: 0)
                    pinButton
                    Spacer(minLength: 0)
                    playButton
                    Spacer(minLength: 0)
                    expandButton
                    Spacer(minLength: 0)
                } else {
                    volumeControl(inline: false, compact: true)
                    transport(compact: true)
                    HStack(spacing: px(6)) {
                        if tier == .full {
                            Text(BuehneTime.format(shown))
                                .font(BuehneFont.regular(px(10)))
                                .monospacedDigit()
                                .lineLimit(1)
                                .fixedSize()
                        }
                        LensSlider(
                            value: Binding(
                                get: { scrubTime ?? session.snapshot.currentTime },
                                set: { scrubTime = $0 }
                            ),
                            range: 0...max(duration ?? 1, 0.001),
                            tint: isLight ? .black : .white,
                            onEditingChanged: { editing in
                                onDrag(editing)
                                if !editing, let scrubTime {
                                    session.seek(to: scrubTime)
                                    self.scrubTime = nil
                                }
                            }
                        )
                        .disabled(duration == nil)
                        .frame(height: px(12))
                        .accessibilityLabel(settings.text(.timeline))
                        if tier == .full {
                            Text(BuehneTime.remaining(duration, elapsed: shown))
                                .font(BuehneFont.regular(px(10)))
                                .monospacedDigit()
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                    .padding(.horizontal, px(6))
                    HStack(spacing: 0) {
                        expandButton
                        pinButton
                        playlistButton
                        iconButton(.settings, label: settings.text(.settings), compact: true, action: onSettings)
                    }
                }
            }
            .padding(.horizontal, px(6))
            .background(BarDragHandle(onMove: onMove, onEnd: onMoveEnd))
        }
        .frame(height: CGFloat(BarScale.hitSide(32, scale: barScale)) + px(2))
        .frame(width: barWidth > 0 ? barWidth : px(BuehneLayout.controlWidth))
        .foregroundStyle(isLight ? Color.black : Color.white)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("buehne.controlBar")
    }

    private var expandButton: some View {
        iconButton(isFullscreen ? .exitFloating : .floating, label: settings.text(.fullScreen), compact: true, action: onFloating)
    }

    @ViewBuilder private var playlistButton: some View {
        if settings.playlistOnBar && !settings.playlistFolders.isEmpty {
            symbolButton("list.bullet", label: settings.text(.playlist), compact: true) { playlistOpen.toggle() }
                .popover(isPresented: $playlistOpen, arrowEdge: .top) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(playlistStore.items) { item in
                                Button {
                                    playlistOpen = false
                                    Task { await session.open(url: item.url) }
                                } label: {
                                    Text(item.name)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 5)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                    }
                    .frame(width: 280, height: min(320, CGFloat(max(1, playlistStore.items.count)) * 28 + 24))
                }
        }
    }

    private var pinButton: some View {
        symbolButton(settings.alwaysOnTop ? "pin.fill" : "pin", label: settings.text(.alwaysOnTop), compact: true) { settings.alwaysOnTop.toggle() }
    }

    private var playButton: some View {
        BarIconButton(label: settings.text(session.snapshot.phase == .playing ? .pause : .play), identifier: "buehne.play", action: { session.togglePlay() }) {
            BuehneIcon(session.snapshot.phase == .playing ? .pause : .play, size: iconPx(18))
        }
    }

    private func volumeControl(inline: Bool, compact: Bool) -> some View {
        HStack(spacing: 4) {
            iconButton(session.volume <= 0.001 ? .muted : .volume, label: settings.text(.volume), compact: compact) {
                volumeOpen.toggle()
            }
            .popover(isPresented: Binding(get: { volumeOpen && !inline }, set: { volumeOpen = $0 }), arrowEdge: .bottom) {
                Slider(
                    value: Binding(get: { session.volume }, set: { session.setVolume($0); onVolume() }),
                    in: 0...1,
                    onEditingChanged: { onDrag($0) }
                )
                    .frame(width: 120)
                    .padding(12)
                    .accessibilityLabel(settings.text(.volume))
            }
            if volumeOpen && inline {
                Slider(
                    value: Binding(get: { session.volume }, set: { session.setVolume($0); onVolume() }),
                    in: 0...1,
                    onEditingChanged: { onDrag($0) }
                )
                    .frame(width: 72)
                    .tint(isLight ? .black : .white)
                    .accessibilityLabel(settings.text(.volume))
            }
        }
    }

    private func transport(compact: Bool) -> some View {
        HStack(spacing: compact ? 2 : 8) {
            seekButton(glyph: .backward, label: settings.text(.back10), delta: -10, compact: compact)
            BarIconButton(label: settings.text(session.snapshot.phase == .playing ? .pause : .play), identifier: "buehne.play", action: { session.togglePlay() }) {
                BuehneIcon(session.snapshot.phase == .playing ? .pause : .play, size: iconPx(18))
            }
            seekButton(glyph: .forward, label: settings.text(.forward10), delta: 10, compact: compact)
        }
    }

    private func iconButton(_ glyph: BuehneGlyph, label: String, compact: Bool = false, action: @escaping () -> Void) -> some View {
        BarIconButton(label: label, identifier: glyph == .settings ? "buehne.settings" : (glyph == .floating || glyph == .exitFloating ? "buehne.expand" : "buehne.control.icon"), action: action) {
            BuehneIcon(glyph, size: iconPx(compact ? 11 : 12))
        }
    }

    private func symbolButton(_ name: String, label: String, compact: Bool = false, action: @escaping () -> Void) -> some View {
        BarIconButton(label: label, identifier: "buehne.control.pin", action: action) {
            Image(systemName: name)
                .font(.system(size: iconPx(compact ? 11 : 12), weight: .regular))
        }
    }

    private func seekButton(glyph: BuehneGlyph, label: String, delta: TimeInterval, compact: Bool) -> some View {
        SeekHoldButton(glyph: glyph, label: label, delta: delta, compact: compact) { committed in
            session.seek(by: committed)
        } preview: { offset in
            scrubTime = max(0, session.snapshot.currentTime + offset)
        }
    }
}

/// A tap seeks 10 seconds. A hold accelerates a preview and commits the real seek on release.
private struct SeekHoldButton: View {
    var glyph: BuehneGlyph
    var label: String
    var delta: TimeInterval
    var compact: Bool
    var commit: (TimeInterval) -> Void
    var preview: (TimeInterval) -> Void
    @Environment(\.buehneBarScale) private var barScale
    @State private var holding = false
    @State private var steps = 1

    var body: some View {
        BarIconButton(label: label, identifier: "buehne.control.seek", action: begin, onUp: end) {
            Image(systemName: glyph == .backward ? "gobackward.10" : "goforward.10")
                .font(.system(size: CGFloat(BarScale.icon(16, scale: barScale)), weight: .regular))
        }
        .onReceive(Timer.publish(every: 0.18, on: .main, in: .common).autoconnect()) { _ in
            guard holding else { return }
            steps = min(steps + 1, 12)
            preview(delta * Double(steps))
        }
    }

    private func begin() {
        holding = true
        steps = 1
        preview(delta)
    }

    private func end() {
        let committed = delta * Double(max(steps, 1))
        holding = false
        preview(0)
        commit(committed)
        steps = 1
    }
}

/// Grab the island by its glass, not by a button. Never moves the window.
struct BarDragHandle: NSViewRepresentable {
    var onMove: (CGSize) -> Void
    var onEnd: () -> Void

    final class HandleView: NSView {
        var onMove: (CGSize) -> Void = { _ in }
        var onEnd: () -> Void = {}
        private var origin: NSPoint?
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) { origin = event.locationInWindow }
        override func mouseDragged(with event: NSEvent) {
            guard let origin else { return }
            let p = event.locationInWindow
            onMove(CGSize(width: p.x - origin.x, height: origin.y - p.y))
        }
        override func mouseUp(with event: NSEvent) {
            origin = nil
            onEnd()
        }
    }

    func makeNSView(context: Context) -> HandleView { HandleView() }
    func updateNSView(_ view: HandleView, context: Context) {
        view.onMove = onMove
        view.onEnd = onEnd
    }
}
