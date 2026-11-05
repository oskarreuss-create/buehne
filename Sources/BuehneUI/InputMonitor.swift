import AppKit
import BuehneCore
import Foundation
import SwiftUI

/// Mouse, keys, and two-finger trackpad. Three-finger swipes are left to the system.
@MainActor
final class InputMonitor {
    var onCommand: (PlayerCommand) -> Void = { _ in }
    var onContextMenu: (NSEvent) -> Void = { _ in }
    /// Called when a press on the picture was dragged sideways and released: the window should shrink to a floating mini window.
    var onVideoDragged: (NSEvent) -> Void = { _ in }
    var volumeNow: () -> Double = { 1 }
    var settingsOpen = false
    var fullscreen = false
    var controlFrame: CGRect = .null
    /// False while the floating bar is hidden. A stale control frame must not eat right-clicks.
    var barAcceptsHits = true
    var settingsFrame: CGRect = .null
    var chromeFrames: [CGRect] = []
    private var chromeByName: [String: CGRect] = [:]

    var isVideoHit: (NSEvent) -> Bool = { _ in false }

    private var reducer = InputReducer()
    private var token: Any?
    private var downAt: Date?
    private var downScreen: NSPoint?
    private var holdWork: DispatchWorkItem?
    private var confirmWork: DispatchWorkItem?
    private var rewindTimer: Timer?

    func noteChrome(_ name: String, _ rect: CGRect) {
        chromeByName[name] = rect
        chromeFrames = Array(chromeByName.values)
    }

    func start() {
        guard token == nil else { return }
        token = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .rightMouseDown, .scrollWheel, .keyDown]) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    func stop() {
        if let token { NSEvent.removeMonitor(token) }
        token = nil
        holdWork?.cancel()
        confirmWork?.cancel()
        rewindTimer?.invalidate()
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        reducer.settingsOpen = settingsOpen
        reducer.fullscreen = event.window?.styleMask.contains(.fullScreen) == true
        switch event.type {
        case .leftMouseDown:
            return mouseDown(event)
        case .leftMouseUp:
            return mouseUp(event)
        case .rightMouseDown:
            return secondary(event)
        case .scrollWheel:
            scroll(event)
            return event
        case .keyDown:
            return keyDown(event)
        default:
            return event
        }
    }

    /// Classify without the video-layer hit test. Present on the next turn so menu tracking
    /// is not nested inside this monitor (that race dismissed the menu after one click).
    private func secondary(_ event: NSEvent) -> NSEvent? {
        confirmWork?.cancel()
        holdWork?.cancel()
        downAt = nil
        downScreen = nil
        let point = event.locationInWindow
        let content = event.window?.contentView
        let local = content?.convert(point, from: nil) ?? point
        let decision = InputReducer.secondary(
            pointInWindow: content?.bounds.contains(local) ?? false,
            onVisibleControl: barAcceptsHits && (controlFrame.contains(point) || hitIsControl(event)),
            onSettingsCard: settingsFrame.contains(point),
            onChrome: hitIsTrafficLight(event)
        )
        let commands = reducer.reduce(.secondaryClick(region: decision.region))
        apply(commands.filter { $0 != .showContextMenu })
        if decision.showMenu {
            onContextMenu(event)
        }
        return event
    }

    private func mouseDown(_ event: NSEvent) -> NSEvent? {
        if event.modifierFlags.contains(.control) {
            return secondary(event)
        }
        confirmWork?.cancel()
        let region = classify(event)
        let commands = reducer.reduce(.pointerDown(region: region, xFraction: xFraction(event), clickCount: event.clickCount))
        apply(commands)
        downAt = region == .video ? Date() : nil
        downScreen = region == .video ? NSEvent.mouseLocation : nil
        holdWork?.cancel()
        if region == .video, event.clickCount < 2 {
            let work = DispatchWorkItem { [weak self] in
                // Only while the button is really still down (a lost mouse-up must not leave fast forward on).
                guard let self, !self.pointerMoved(), NSEvent.pressedMouseButtons & 1 != 0 else { return }
                self.apply(self.reducer.reduce(.holdDelayElapsed))
            }
            holdWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + InputReducer.holdDelay, execute: work)
        }
        return event
    }

    private func mouseUp(_ event: NSEvent) -> NSEvent? {
        holdWork?.cancel()
        let moved = pointerMoved()
        let held = downAt.map { Date().timeIntervalSince($0) } ?? 0
        let draggedSideways = downAt != nil && downScreen.map { start in
            let now = NSEvent.mouseLocation
            return abs(now.x - start.x) >= 60 && abs(now.x - start.x) > abs(now.y - start.y)
        } == true
        downAt = nil
        downScreen = nil
        let commands = reducer.reduce(.pointerUp(
            region: classify(event),
            xFraction: xFraction(event),
            clickCount: event.clickCount,
            held: held
        ))
        apply(commands)
        if moved {
            apply(reducer.reduce(.cancelClick))
            if draggedSideways { onVideoDragged(event) }
            return event
        }
        if reducer.wantsClickConfirm {
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.apply(self.reducer.reduce(.confirmClick))
            }
            confirmWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: work)
        }
        return event
    }

    private func scroll(_ event: NSEvent) {
        if settingsOpen, settingsFrame.contains(event.locationInWindow) { return }
        reducer.noteVolume(volumeNow())
        let ended = event.phase.contains(.ended) || event.phase.contains(.cancelled) || event.momentumPhase.contains(.ended)
        apply(reducer.reduce(.scroll(
            deltaX: event.scrollingDeltaX,
            deltaY: event.scrollingDeltaY,
            natural: event.isDirectionInvertedFromDevice,
            precise: event.hasPreciseScrollingDeltas,
            ended: ended
        )))
    }

    private func keyDown(_ event: NSEvent) -> NSEvent? {
        guard let key = PlayerKey(event) else { return event }
        if event.isARepeat, key != .left, key != .right, key != .up, key != .down, key != .speedDown, key != .speedUp {
            return nil
        }
        let commands = reducer.reduce(.key(key))
        guard !commands.isEmpty else { return event }
        apply(commands)
        return nil
    }

    private func classify(_ event: NSEvent, requireKey: Bool = true) -> PointerRegion {
        let window = event.window
        let key = (window?.isKeyWindow ?? false) && NSApp.isActive
        let point = event.locationInWindow
        return InputReducer.region(
            windowWasKey: !requireKey || key,
            inControl: controlFrame.contains(point) || hitIsControl(event),
            inSettings: settingsOpen || settingsFrame.contains(point),
            inChrome: chromeFrames.contains { $0.contains(point) } || hitIsTrafficLight(event),
            inVideo: isVideoHit(event)
        )
    }

    private func hitIsControl(_ event: NSEvent) -> Bool {
        guard let content = event.window?.contentView else { return false }
        let local = content.convert(event.locationInWindow, from: nil)
        var hit: NSView? = content.hitTest(local)
        while let view = hit {
            if view is NSControl || view is BarHitView { return true }
            if let name = view.identifier?.rawValue, name.hasPrefix("buehne.control") { return true }
            hit = view.superview
        }
        return false
    }

    private func hitIsTrafficLight(_ event: NSEvent) -> Bool {
        guard let window = event.window else { return false }
        let theme = window.contentView?.superview ?? window.contentView
        let local = theme?.convert(event.locationInWindow, from: nil) ?? event.locationInWindow
        var view = theme?.hitTest(local)
        while let hit = view {
            if let button = hit as? NSButton {
                let tagged = button.identifier?.rawValue.hasPrefix("buehne.traffic") == true
                let standard = window.standardWindowButton(.closeButton) === button
                    || window.standardWindowButton(.miniaturizeButton) === button
                    || window.standardWindowButton(.zoomButton) === button
                if tagged || standard {
                    return !button.isHidden && button.alphaValue > 0.05 && button.isEnabled
                }
            }
            view = hit.superview
        }
        return false
    }

    private func pointerMoved() -> Bool {
        guard let start = downScreen else { return false }
        let now = NSEvent.mouseLocation
        return hypot(now.x - start.x, now.y - start.y) > 6
    }

    private func xFraction(_ event: NSEvent) -> Double {
        let width = event.window?.contentView?.bounds.width ?? 1
        return width > 1 ? event.locationInWindow.x / width : 0.5
    }

    private func apply(_ commands: [PlayerCommand]) {
        for command in commands {
            if command == .beginRewind { startRewind() }
            if command == .endRewind { stopRewind() }
            onCommand(command)
        }
    }

    /// Drop any press-and-hold state (fast forward, rewind, pending click) after a window state change.
    func releaseHolds() {
        confirmWork?.cancel()
        holdWork?.cancel()
        downAt = nil
        downScreen = nil
        apply(reducer.reduce(.releaseAll))
        stopRewind()
    }

    private func startRewind() {
        rewindTimer?.invalidate()
        rewindTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.onCommand(.seek(-0.2)) }
        }
    }

    private func stopRewind() {
        rewindTimer?.invalidate()
        rewindTimer = nil
    }
}

extension PlayerKey {
    init?(_ event: NSEvent) {
        let command = event.modifierFlags.contains(.command)
        if command, event.charactersIgnoringModifiers == "o" { self = .openFile; return }
        if command, event.keyCode == 43 { self = .settings; return }
        if command { return nil }
        switch event.keyCode {
        case 49: self = .space
        case 123: self = .left
        case 124: self = .right
        case 125: self = .down
        case 126: self = .up
        case 3: self = .f
        case 46: self = .m
        case 53: self = .escape
        case 33: self = .speedDown
        case 30: self = .speedUp
        case 0: self = .audioNext
        case 1: self = .subtitleNext
        default: return nil
        }
    }
}

struct WindowFrameReader: NSViewRepresentable {
    var onFrame: (CGRect) -> Void

    func makeNSView(context: Context) -> FrameView {
        let view = FrameView()
        view.onFrame = onFrame
        return view
    }

    func updateNSView(_ view: FrameView, context: Context) {
        view.onFrame = onFrame
        view.publish()
    }

    final class FrameView: NSView {
        var onFrame: (CGRect) -> Void = { _ in }
        override func layout() {
            super.layout()
            publish()
        }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            publish()
        }
        func publish() {
            guard window != nil else { return }
            onFrame(convert(bounds, to: nil))
        }
    }
}
