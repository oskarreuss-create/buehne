import Foundation

/// Volume and rate writes. Each event is an engine value. Persist keeps only the latest.
public enum VolumeApply {
    public static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }

    public static func engineWrites(_ values: [Double]) -> [Double] {
        values.map(clamp)
    }

    public static func persistValue(_ values: [Double]) -> Double? {
        values.last.map(clamp)
    }
}

public enum RateApply {
    public static func clamp(_ value: Double) -> Double {
        RateRange.clamp(value)
    }

    public static func engineWrites(_ values: [Double]) -> [Double] {
        values.map(clamp)
    }
}

public enum SubtitleRow: String, Sendable {
    case primary
    case secondary
}

public enum SubtitleOffRule {
    /// If both tracks are on, either off button clears both. Otherwise it clears its own row.
    public static func afterOff(primaryOn: Bool, secondaryOn: Bool, which: SubtitleRow) -> (primary: Bool, secondary: Bool) {
        if primaryOn && secondaryOn { return (false, false) }
        switch which {
        case .primary: return (false, secondaryOn)
        case .secondary: return (primaryOn, false)
        }
    }
}

public enum TrafficLightVisibility {
    /// Native close, minimize, and zoom while a loaded video is paused and the window is not full screen.
    public static func show(fullscreen: Bool, paused: Bool, hasMedia: Bool) -> Bool {
        !fullscreen && paused && hasMedia
    }
}

public enum SettingsClick {
    /// One gear click flips the panel exactly once.
    public static func afterGear(open: Bool) -> Bool { !open }

    public static func afterOutside(open: Bool) -> Bool { false }

    /// A gear hit owns the click. Outside dismissal must not also run and reopen it.
    public static func resolve(open: Bool, gear: Bool, outside: Bool) -> Bool {
        if gear { return !open }
        if outside { return false }
        return open
    }
}

public enum FloatingApply {
    public static func toggled(_ floating: Bool) -> Bool { !floating }

    public static func actions(clicks: Int, start: Bool = false) -> (floating: Bool, count: Int) {
        var floating = start
        var count = 0
        for _ in 0..<max(0, clicks) {
            floating = toggled(floating)
            count += 1
        }
        return (floating, count)
    }

    public static func contentSize(
        floating: Bool,
        screenWidth: Double,
        screenHeight: Double,
        aspect: Double,
        restoredWidth: Double,
        restoredHeight: Double
    ) -> (width: Double, height: Double) {
        if floating {
            return WindowGeometry.floatingMaxSize(
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                aspect: aspect
            )
        }
        return (max(restoredWidth, 1), max(restoredHeight, 1))
    }
}

public enum BarHitPolicy {
    public static let side = 32.0
    public static let acceptsFirstMouse = true
    public static let firesOnMouseDown = true
}
/// Floating-window control bar. Shown while the pointer is inside; a leave arms a
/// cancelable hide. Re-entering before the delay cancels it. Settings and drags hold it.
public struct FloatingBarVisibility: Equatable, Sendable {
    public enum Event: Equatable, Sendable {
        case entered
        case moved
        case exited
        case hideDelayElapsed
        case settings(Bool)
        case dragging(Bool)
    }

    public enum Effect: Equatable, Sendable {
        case show
        case armHide
        case cancelHide
        case hide
        case hold
    }

    public var inside = false
    public var hideArmed = false
    public var settingsOpen = false
    public var dragging = false
    public var visible = false

    /// Fade-in duration. The 0.2 s value is the leave delay, not this animation.
    public static let fadeIn = 0.15
    public static let fadeOut = 0.075
    public static let hideDelay = 0.1

    public var pinned: Bool { settingsOpen || dragging }

    public init() {}

    public mutating func reduce(_ event: Event) -> Effect {
        switch event {
        case .entered:
            return showAndCancel()
        case .moved:
            if inside { return .hold }
            return showAndCancel()
        case .exited:
            inside = false
            if pinned {
                hideArmed = false
                visible = true
                return .cancelHide
            }
            hideArmed = true
            return .armHide
        case .hideDelayElapsed:
            guard hideArmed, !inside, !pinned else {
                if inside || pinned { hideArmed = false }
                return .hold
            }
            hideArmed = false
            visible = false
            return .hide
        case .settings(let open):
            settingsOpen = open
            return refreshHold()
        case .dragging(let active):
            dragging = active
            return refreshHold()
        }
    }

    private mutating func showAndCancel() -> Effect {
        inside = true
        hideArmed = false
        visible = true
        return .show
    }

    private mutating func refreshHold() -> Effect {
        if pinned || inside {
            hideArmed = false
            visible = true
            return .cancelHide
        }
        hideArmed = true
        return .armHide
    }
}
