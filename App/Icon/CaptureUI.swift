// Real PlayerRootView, wholly offscreen. Never activates or captures the desktop.
import AppKit
import AVFoundation
import BuehneCore
import BuehneEngine
@testable import BuehneUI
import SwiftUI

private final class IconProofWindow: NSWindow {
    override var alphaValue: CGFloat { get { super.alphaValue } set { super.alphaValue = 1 } }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        var rect = frameRect; rect.origin = NSPoint(x: -32000, y: -32000); return rect
    }
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        var rect = frameRect; rect.origin = NSPoint(x: -32000, y: -32000); super.setFrame(rect, display: flag)
    }
    override func setFrameOrigin(_ point: NSPoint) { super.setFrameOrigin(NSPoint(x: -32000, y: -32000)) }
}

@main @MainActor struct IconUICapture {
    static func main() {
        NSApplication.shared.setActivationPolicy(.accessory)
        Task {
            do { try await run(); exit(0) }
            catch { print("ICON_UI_FAIL \(error)"); exit(1) }
        }
        NSApplication.shared.run()
    }

    static func run() async throws {
        let phase = CommandLine.arguments.dropFirst().first ?? "after"
        precondition(["before", "after"].contains(phase))
        if phase == "after" {
            let proof = HStack(spacing: 0) {
                BuehneWordmark().environment(\.colorScheme, .light)
                    .padding(24).background(Color(red: 250/255, green: 250/255, blue: 1))
                BuehneWordmark().environment(\.colorScheme, .dark)
                    .padding(24).background(Color(red: 32/255, green: 32/255, blue: 32/255))
            }
            let renderer = ImageRenderer(content: proof)
            renderer.scale = 2
            guard let image = renderer.cgImage else { throw CocoaError(.fileReadCorruptFile) }
            try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
                .write(to: URL(fileURLWithPath: "reference/buehne-icons-wordmark-view.png"))
            print("ICON_WORDMARK_VIEW_OK themes=2 source=standalone-view-not-emptyState")
        }
        let url = URL(fileURLWithPath: "/tmp/buehne-icons-video.mp4")
        let frame = try await AVAssetImageGenerator(asset: AVURLAsset(url: url)).image(at: .zero).image
        for panel in [false, true] {
            let session = PlayerSession(store: MemoryPositionStore())
            session.setVolume(0)
            await session.open(url: url)
            let suite = "buehne.icons.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let settings = BuehneSettings(defaults: defaults)
            settings.theme = "dark"; settings.language = "en"; settings.lockAspect = false
            let bounds = NSRect(x: 0, y: 0, width: 960, height: 640)
            let host = NSHostingView(rootView: PlayerRootView(session: session, settings: settings, keepOffscreen: true))
            host.frame = bounds
            let container = NSView(frame: bounds)
            // AppKit cacheDisplay omits AVPlayer's hardware plane. Use the actual
            // decoded first frame of the playing fixture below the real UI.
            let underlay = NSImageView(frame: bounds)
            underlay.image = NSImage(cgImage: frame, size: .zero)
            underlay.imageScaling = .scaleAxesIndependently
            container.addSubview(underlay); container.addSubview(host)
            let window = IconProofWindow(contentRect: NSRect(x: -32000, y: -32000, width: 960, height: 640),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            // NSWindow's initializer may constrain the requested origin without
            // dispatching our overrides. Force placement before attaching/showing.
            precondition(!window.isVisible)
            let initialFrame = window.frame
            window.setFrameOrigin(NSPoint(x: -32000, y: -32000))
            print("ICON_WINDOW_PLACEMENT initial=\(initialFrame) forced=\(window.frame) visibleBeforeOrder=\(window.isVisible)")
            window.isReleasedWhenClosed = false
            window.ignoresMouseEvents = true
            window.contentView = container
            window.appearance = NSAppearance(named: .darkAqua)
            precondition(NSScreen.screens.allSatisfy { !$0.frame.intersects(window.frame) })
            window.orderFrontRegardless()
            try await Task.sleep(for: .milliseconds(200))
            window.setContentSize(bounds.size)
            if panel { PlayerHost.shared.toggleSettings() }
            try await Task.sleep(for: .milliseconds(600))
            host.layoutSubtreeIfNeeded(); host.display(); window.displayIfNeeded(); CATransaction.flush()
            precondition(window.alphaValue == 1 && window.frame.maxX < 0 && window.frame.maxY < 0)
            precondition(NSScreen.screens.allSatisfy { !$0.frame.intersects(window.frame) })
            let bitmap = container.bitmapImageRepForCachingDisplay(in: bounds)!
            container.cacheDisplay(in: bounds, to: bitmap)
            let path = "reference/buehne-icons-\(phase)-\(panel ? "settings" : "player").png"
            try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
            print("ICON_UI_CAPTURE \(path) \(bitmap.pixelsWide)x\(bitmap.pixelsHigh) offscreen=1 actualHostingView=1")
            window.close()
        }
    }
}
