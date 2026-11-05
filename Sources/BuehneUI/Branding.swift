import AppKit
import SwiftUI

/// Load standalone vector PDFs explicitly (they are not asset-catalog images).
@MainActor
private enum BrandImages {
    static func load(_ name: String) -> NSImage {
        guard let url = Bundle.module.url(forResource: name, withExtension: "pdf"),
              let image = NSImage(contentsOf: url) else {
            preconditionFailure("Missing required brand resource: \(name).pdf")
        }
        image.isTemplate = false
        return image
    }
}

/// Reference 13: a single horizontal lockup, not a generic play tile plus text.
/// Paths are generated from App/Icon/main.swift; PDFs contain no embedded font.
struct BuehneWordmark: View {
    var width: CGFloat = 280
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(nsImage: BrandImages.load("BuehneWordmark-\(colorScheme == .dark ? "dark" : "light")"))
            .resizable()
            .scaledToFit()
            .frame(width: width, height: width * 332 / 1646)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("BÜHNE")
    }
}

/// Matching standalone vector mark for an owner replacing the old BuehneMark.
struct BuehneBrandMark: View {
    var width: CGFloat = 92
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(nsImage: BrandImages.load("BuehneMark-\(colorScheme == .dark ? "dark" : "light")"))
            .resizable()
            .scaledToFit()
            .frame(width: width, height: width * 694 / 950)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("BÜHNE")
    }
}
