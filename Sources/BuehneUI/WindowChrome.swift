import AppKit
import BuehneCore
import SwiftUI

struct WindowChrome: NSViewRepresentable {
    var lockAspect: Bool
    var aspect: Double
    var floating: Bool
    var alwaysOnTop: Bool
    var videoWidth: Double
    var videoHeight: Double
    var keepOffscreen: Bool
    var showTrafficLights: Bool

    func makeNSView(context: Context) -> ChromeView {
        let view = ChromeView()
        view.onConfigure = { window in
            apply(window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ view: ChromeView, context: Context) {
        view.onConfigure = { window in
            apply(window, coordinator: context.coordinator)
        }
        if let window = view.window {
            apply(window, coordinator: context.coordinator)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var appliedSize: (Double, Double, Double)?
        var appliedEmpty = false
        var trafficVisible: Bool?
        var trafficButtons: [NSButton] = []
        var loggedTraffic = false
        var restoredFloatingFrame: NSRect?
        var loggedFloating = false
        var loggedScaleProof = false
    }

    private func apply(_ window: NSWindow, coordinator: Coordinator) {
        window.title = OpenContract.displayName
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        // The welcome card is rounder than any system window corner, and the system frame draws a glassy
        // rim at its own corner radius behind the card. So the welcome state is a borderless window; once a
        // video is loaded the window is a normal titled one again (full screen needs it).
        let welcome = !(videoWidth > 1 && videoHeight > 1)
        // Changing the style mask rebuilds the frame view; doing it inside viewDidMoveToWindow or layout
        // aborts in AppKit (crash when a file is opened at launch), so it runs on the next run-loop turn.
        if !window.styleMask.contains(.fullScreen), window.styleMask.contains(.titled) == welcome {
            DispatchQueue.main.async { [weak window] in
                guard let window, !window.styleMask.contains(.fullScreen),
                      window.styleMask.contains(.titled) == welcome else { return }
                window.styleMask = welcome
                    ? [.borderless, .closable, .miniaturizable, .resizable]
                    : [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            }
        }
        window.isReleasedWhenClosed = false
        window.level = alwaysOnTop ? .floating : .normal
        window.acceptsMouseMovedEvents = true
        let ratio = aspect > 0.01 ? aspect : (WindowGeometry.emptyWidth / WindowGeometry.emptyHeight)
        if videoWidth > 1, videoHeight > 1 {
            if lockAspect || floating {
                window.contentAspectRatio = NSSize(width: ratio, height: 1)
            }
            window.contentMaxSize = NSSize(width: 16000, height: 16000)
            let key = (videoWidth, videoHeight, ratio)
            if coordinator.appliedSize.map({ $0.0 != key.0 || $0.1 != key.1 || abs($0.2 - key.2) > 0.01 }) ?? true,
               let screen = window.screen ?? NSScreen.main {
                coordinator.appliedSize = key
                if let fitted = WindowGeometry.openingSize(
                    videoWidth: videoWidth,
                    videoHeight: videoHeight,
                    screenWidth: screen.visibleFrame.width,
                    screenHeight: screen.visibleFrame.height
                ) {
                    window.setContentSize(NSSize(width: fitted.width, height: fitted.height))
                    if !keepOffscreen, !CommandLine.arguments.contains("--proof-offscreen") { window.center() }
                }
            }
        } else if !coordinator.appliedEmpty {
            coordinator.appliedEmpty = true
            window.contentAspectRatio = NSSize(width: WindowGeometry.emptyWidth, height: WindowGeometry.emptyHeight)
            window.setContentSize(NSSize(width: WindowGeometry.emptyWidth, height: WindowGeometry.emptyHeight))
            if !keepOffscreen, !CommandLine.arguments.contains("--proof-offscreen") { window.center() }
        }
        applyFloatingFrame(window, coordinator: coordinator, aspect: ratio)
        // The shadow is cut from the window's alpha. Rebuild it once the card has drawn,
        // or it keeps the system corner shape and shows as a glassy rim around the rounded card.
        DispatchQueue.main.async { window.invalidateShadow() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { window.invalidateShadow() }
        if keepOffscreen {
            window.alphaValue = 0
            window.ignoresMouseEvents = true
            window.setFrameOrigin(NSPoint(x: -32000, y: -32000))
        } else if CommandLine.arguments.contains("--proof-offscreen") {
            window.alphaValue = 1
            window.setFrameOrigin(NSPoint(x: -32000, y: -32000))
        }
        syncTrafficLights(window, coordinator: coordinator)
    }
    private func applyFloatingFrame(_ window: NSWindow, coordinator: Coordinator, aspect: Double) {
        guard videoWidth > 1, videoHeight > 1 else { return }
        let screen = window.screen ?? NSScreen.main
        let screenW = screen?.visibleFrame.width ?? 1440
        let screenH = screen?.visibleFrame.height ?? 900
        let proof = CommandLine.arguments.contains("--proof-offscreen")
        if floating {
            let cap = FloatingApply.contentSize(
                floating: true,
                screenWidth: screenW,
                screenHeight: screenH,
                aspect: aspect,
                restoredWidth: window.frame.width,
                restoredHeight: window.frame.height
            )
            window.contentMaxSize = NSSize(width: cap.width, height: cap.height)
            if coordinator.restoredFloatingFrame == nil {
                coordinator.restoredFloatingFrame = window.frame
            }
            let content = window.contentRect(forFrameRect: window.frame).size
            if abs(content.width - cap.width) > 2 || abs(content.height - cap.height) > 2 {
                window.setContentSize(NSSize(width: cap.width, height: cap.height))
                if !keepOffscreen && !proof { window.center() }
            }
            if CommandLine.arguments.contains("--press-expand"), !coordinator.loggedFloating {
                coordinator.loggedFloating = true
                print("FLOATING_SIZE \(Int(cap.width))x\(Int(cap.height))")
            }
            applyScaleProof(window, coordinator: coordinator)
        } else {
            window.contentMaxSize = NSSize(width: 16000, height: 16000)
            if let restored = coordinator.restoredFloatingFrame {
                coordinator.restoredFloatingFrame = nil
                window.setFrame(restored, display: true)
            }
        }
    }

    private func applyScaleProof(_ window: NSWindow, coordinator: Coordinator) {
        guard let raw = CommandLine.arguments.first(where: { $0.hasPrefix("--scale-width=") }),
              let width = Double(raw.dropFirst("--scale-width=".count)), width > 1 else { return }
        let height = max(200, width * 9 / 16)
        window.contentMinSize = NSSize(width: 200, height: 120)
        window.contentMaxSize = NSSize(width: 4000, height: 4000)
        let size = NSSize(width: width, height: height)
        if abs(window.contentRect(forFrameRect: window.frame).width - width) > 2 {
            window.setContentSize(size)
        }
        guard !coordinator.loggedScaleProof,
              let path = CommandLine.arguments.first(where: { $0.hasPrefix("--scale-png=") })?.dropFirst("--scale-png=".count),
              !path.isEmpty else { return }
        coordinator.loggedScaleProof = true
        let url = URL(fileURLWithPath: String(path))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            guard let view = window.contentView else { return }
            let bounds = view.bounds
            guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return }
            view.cacheDisplay(in: bounds, to: rep)
            guard let data = rep.representation(using: .png, properties: [:]) else { return }
            try? data.write(to: url)
            print("SCALE_CAPTURE \(url.path) \(Int(bounds.width))x\(Int(bounds.height))")
        }
    }
    private func syncTrafficLights(_ window: NSWindow, coordinator: Coordinator) {
        let show = showTrafficLights && !keepOffscreen
        if coordinator.trafficVisible == nil, !show {
            coordinator.trafficVisible = false
            concealTrafficLights(window, coordinator: coordinator, animated: false)
            return
        }
        let changed = coordinator.trafficVisible != show
        coordinator.trafficVisible = show
        if show {
            revealTrafficLights(window, coordinator: coordinator, animated: changed)
        } else {
            concealTrafficLights(window, coordinator: coordinator, animated: changed)
        }
    }

    private func prepareTrafficStyle(_ window: NSWindow) {
        window.styleMask.formUnion([.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView])
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
    }

    private func trafficButtons(_ window: NSWindow, coordinator: Coordinator) -> [NSButton] {
        if coordinator.trafficButtons.count < 3 {
            prepareTrafficStyle(window)
            let found = [
                window.standardWindowButton(.closeButton),
                window.standardWindowButton(.miniaturizeButton),
                window.standardWindowButton(.zoomButton)
            ].compactMap { $0 }
            if found.count == 3 { coordinator.trafficButtons = found }
            let names = ["buehne.traffic.close", "buehne.traffic.miniaturize", "buehne.traffic.zoom"]
            for (button, name) in zip(found, names) {
                button.identifier = NSUserInterfaceItemIdentifier(name)
            }
        }
        if CommandLine.arguments.contains("--paused-floating"), !coordinator.loggedTraffic {
            coordinator.loggedTraffic = true
            let frame = coordinator.trafficButtons.first?.frame ?? .zero
            print("TRAFFIC count=\(coordinator.trafficButtons.count) style=\(window.styleMask.rawValue) frame=\(frame)")
        }
        return coordinator.trafficButtons
    }

    private func revealTrafficLights(_ window: NSWindow, coordinator: Coordinator, animated: Bool) {
        let buttons = trafficButtons(window, coordinator: coordinator)
        guard !buttons.isEmpty else { return }
        placeTrafficLights(buttons, window: window)
        for button in buttons {
            button.isHidden = false
            button.isEnabled = true
        }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                for button in buttons { button.animator().alphaValue = 1 }
            }
        } else {
            for button in buttons { button.alphaValue = 1 }
        }
    }

    private func concealTrafficLights(_ window: NSWindow, coordinator: Coordinator, animated: Bool) {
        let buttons = coordinator.trafficButtons.isEmpty
            ? [
                window.standardWindowButton(.closeButton),
                window.standardWindowButton(.miniaturizeButton),
                window.standardWindowButton(.zoomButton)
            ].compactMap { $0 }
            : coordinator.trafficButtons
        guard !buttons.isEmpty else { return }
        let finish = {
            guard coordinator.trafficVisible != true else { return }
            for button in buttons {
                button.alphaValue = 0
                button.isHidden = true
                button.isEnabled = false
            }
        }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                for button in buttons { button.animator().alphaValue = 0 }
            } completionHandler: {
                finish()
            }
        } else {
            finish()
        }
    }

    private func placeTrafficLights(_ buttons: [NSButton], window: NSWindow) {
        guard let first = buttons.first else { return }
        let top = window.contentView?.bounds.height ?? window.frame.height
        let inWindow = first.convert(first.bounds, to: nil)
        let alreadyPlaced = inWindow.minX >= 4 && inWindow.minX <= 40 && inWindow.maxY >= top - 40
        if alreadyPlaced { return }
        var host = first.superview
        let width = first.bounds.width > 1 ? first.bounds.width : 14
        let height = first.bounds.height > 1 ? first.bounds.height : 14
        if (host?.bounds.height ?? 0) < height + 8, let content = window.contentView {
            for button in buttons where button.superview !== content {
                content.addSubview(button, positioned: .above, relativeTo: nil)
            }
            host = content
        }
        guard let host else { return }
        let y = max(0, host.bounds.height - height - 10)
        var x: CGFloat = 20
        for button in buttons {
            button.frame = NSRect(x: x, y: y, width: width, height: height)
            x += width + 8
        }
    }
}

final class ChromeView: NSView {
    var onConfigure: (NSWindow) -> Void = { _ in }
    private var pinTimer: Timer?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: nil)
        if let window {
            onConfigure(window)
            if CommandLine.arguments.contains("--proof-offscreen") {
                NotificationCenter.default.addObserver(self, selector: #selector(windowMoved), name: NSWindow.didMoveNotification, object: window)
            }
        } else {
            pinTimer?.invalidate()
            pinTimer = nil
        }
}

    @objc private func windowMoved() {
        guard let window, CommandLine.arguments.contains("--proof-offscreen") else { return }
        if window.frame.origin.x < -16000 { return }
        window.setFrameOrigin(NSPoint(x: -32000, y: -32000))
    }
    private var configuring = false

    override func layout() {
        super.layout()
        guard !configuring, let window else { return }
        configuring = true
        onConfigure(window)
        configuring = false
    }
}
