import SwiftUI

/// Shared chrome geometry. Panels remain separate from the movie and each other.
enum BuehneLayout {
    static let windowInset: CGFloat = 24
    static let settingsInset: CGFloat = 6
    static let panelGap: CGFloat = 16
    static let controlWidth: CGFloat = 500
    static let controlHeight: CGFloat = 34
    static let cardWidth: CGFloat = 460
    static let cardHeight: CGFloat = 620
    static let cardPadding: CGFloat = 24
    static let cornerRadius: CGFloat = 24
    static let rowHeight: CGFloat = 32
}

/// Active and inactive window chrome. Matches STRÖM's grayscale surfaces, not a tint.
public enum WindowActivity: Sendable {
    case active
    case inactive
}

public enum BuehneTheme {
    public static func sidebarWhite(isLight: Bool, activity: WindowActivity) -> Double {
        switch (isLight, activity) {
        case (true, .active): 0.955
        case (true, .inactive): 0.90
        case (false, .active): 0.10
        case (false, .inactive): 0.06
        }
    }

    public static func contentWhite(isLight: Bool, activity: WindowActivity) -> Double {
        switch (isLight, activity) {
        case (true, .active): 0.975
        case (true, .inactive): 0.925
        case (false, .active): 0.13
        case (false, .inactive): 0.08
        }
    }

    public static func sidebarSurface(isLight: Bool, activity: WindowActivity) -> Color {
        Color(white: sidebarWhite(isLight: isLight, activity: activity))
    }

    public static func contentSurface(isLight: Bool, activity: WindowActivity) -> Color {
        Color(white: contentWhite(isLight: isLight, activity: activity))
    }

    /// `auto` leaves semantic colors to the system. Light and dark force the scheme.
    public static func preferredScheme(_ theme: String) -> ColorScheme? {
        switch theme {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    public static func isLight(theme: String, system: ColorScheme) -> Bool {
        theme == "light" || (theme != "dark" && system == .light)
    }
}

/// One transparency percent for the bar, empty card, settings panel and context chrome.
/// 0 is a fully opaque plate. 100 is clear glass. Only a missing stored value uses the default.
public enum GlassAppearance {
    public static let defaultTransparency = 65.0
    public static let percentUnit = "percent"

    public static func resolvedTransparency(stored: Double?, unit: String?) -> Double {
        guard let stored else { return defaultTransparency }
        if unit == percentUnit {
            return min(100, max(0, stored))
        }
        let legacyPlate = min(1, max(0, stored))
        return min(100, max(0, (1 - legacyPlate) * 100))
    }

    /// Plate opacity. Higher transparency yields a lower plate, with no floor.
    public static func sharedBacking(_ transparency: Double) -> Double {
        let percent = min(100, max(0, transparency))
        return 1 - percent / 100
    }

    public static func backingOpacity(_ transparency: Double) -> Double {
        sharedBacking(transparency)
    }

    public static func readableBacking(_ transparency: Double) -> Double {
        sharedBacking(transparency)
    }

    public static func menuBacking(_ transparency: Double) -> Double {
        sharedBacking(transparency)
    }

    public static func percentLabel(_ transparency: Double) -> String {
        "\(Int(min(100, max(0, transparency)).rounded()))%"
    }
}

public enum BuehneTypeName {
    public static let body = "Helvetica-Light"
    public static let panelTitle = "Helvetica-Bold"
    public static let sectionTitle = "HelveticaNeue-Light"
    public static let itemTitle = "Helvetica-Bold"
    public static let label = "Helvetica"
    public static let caption = "Helvetica-Light"
    public static let micro = "Helvetica-Light"
}
