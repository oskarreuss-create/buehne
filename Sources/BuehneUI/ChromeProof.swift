import AppKit
import BuehneCore
import BuehneEngine
import SwiftUI

/// Renders the real control bar on a clear field. Used by the playback self-check.
@MainActor
public enum BuehneChromeProof {
    public static func controlBarOpaquePixels() -> Int {
        let session = PlayerSession(store: MemoryPositionStore())
        let settings = BuehneSettings(defaults: UserDefaults(suiteName: "buehne.chrome-proof") ?? .standard)
        let view = ControlBarProof(session: session, settings: settings)
            .frame(width: 720, height: 120)
            .preferredColorScheme(.dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.isOpaque = false
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return 0 }
        var count = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                if let color = rep.colorAt(x: x, y: y), color.alphaComponent > 0.2 {
                    count += 1
                }
            }
        }
        return count
    }
}

private struct ControlBarProof: View {
    @ObservedObject var session: PlayerSession
    @ObservedObject var settings: BuehneSettings
    @State private var volumeOpen = true
    @State private var scrub: Double?

    var body: some View {
        GlassPanel(radius: 26, opacity: 0.9, isLight: false, interactive: true) {
            ControlBar(
                session: session,
                settings: settings,
                volumeOpen: $volumeOpen,
                scrubTime: $scrub,
                isLight: false,
                onFloating: {},
                onPip: {},
                onSettings: {}
            )
        }
        .padding(12)
    }
}
