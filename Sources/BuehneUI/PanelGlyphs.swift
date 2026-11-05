import SwiftUI

/// Only rows with an unredacted reference glyph receive a leading icon.
extension L10nKey {
    var panelGlyph: BuehneGlyph? {
        switch self {
        case .theme: .theme
        case .onScreenMessages: .messages
        case .onScreenMenu: .menu
        case .sidebar: .sidebar
        case .videoFillsWindow: .fillWindow
        case .lockAspect: .lockAspect
        case .aspect: .aspect
        case .crop: .crop
        case .rotation: .rotation
        case .speed: .speed
        case .primarySubtitles: .primarySubtitles
        case .secondarySubtitles: .secondarySubtitles
        default: nil
        }
    }
}

struct BuehneIconLabel: View {
    var key: L10nKey
    var text: String

    var body: some View {
        HStack(spacing: 8) {
            if let glyph = key.panelGlyph { BuehneIcon(glyph, size: 16) }
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
