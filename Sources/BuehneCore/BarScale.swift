import Foundation

/// Floating control-bar scale. Linear in window width, clamped, monotonic.
public enum BarScale {
    public static let baselineWidth = 520.0
    public static let minimum = 0.6
    public static let maximum = 1.0
    public static let minimumIcon = 16.0
    public static let minimumHit = 24.0

    /// 1 at the 520-pt baseline. Never below 0.6 or above 1.6.
    public static func factor(windowWidth: Double) -> Double {
        guard windowWidth.isFinite, windowWidth > 0 else { return minimum }
        return min(maximum, max(minimum, windowWidth / baselineWidth))
    }

    public static func points(_ baseline: Double, scale: Double) -> Double {
        baseline * clamp(scale)
    }

    /// Visual icon size. The scale applies, but the result never drops under 16 pt.
    public static func icon(_ baseline: Double, scale: Double) -> Double {
        max(minimumIcon, baseline * clamp(scale))
    }

    /// Hit side. Item 10's 32 pt target shrinks with the window, but never under 24 pt.
    public static func hitSide(_ baseline: Double = 32, scale: Double) -> Double {
        max(minimumHit, baseline * clamp(scale))
    }

    /// Dock hover at the baseline is 1.2. The extra lift scales with the bar; the hit rect does not.
    public static func hoverMagnification(scale: Double, baseline: Double = 1.2) -> Double {
        1 + max(0, baseline - 1) * clamp(scale)
    }

    public static func clamp(_ scale: Double) -> Double {
        guard scale.isFinite else { return 1 }
        return min(maximum, max(minimum, scale))
    }
}
