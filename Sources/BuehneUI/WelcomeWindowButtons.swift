import AppKit
import SwiftUI

/// Close / minimize / zoom for the borderless welcome window, which has no system title bar.
struct WelcomeWindowButtons: View {
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            light(Color(red: 1.0, green: 0.37, blue: 0.34), symbol: "xmark", label: "Close") { $0.close() }
            light(Color(red: 1.0, green: 0.74, blue: 0.18), symbol: "minus", label: "Minimize") { $0.miniaturize(nil) }
            light(Color(red: 0.16, green: 0.79, blue: 0.25), symbol: "plus", label: "Zoom") { $0.zoom(nil) }
        }
        .onHover { hovering = $0 }
    }

    private func light(_ color: Color, symbol: String, label: String, action: @escaping (NSWindow) -> Void) -> some View {
        Button {
            guard let window = NSApp.currentEvent?.window ?? NSApp.windows.first(where: { $0.isVisible }) else { return }
            action(window)
        } label: {
            Circle()
                .fill(color)
                .frame(width: 13, height: 13)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.18), lineWidth: 0.5))
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 7, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.6))
                        .opacity(hovering ? 1 : 0)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
