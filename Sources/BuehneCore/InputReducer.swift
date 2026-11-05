import Foundation

/// Where a pointer event landed. Overlays win over the video surface.
public enum PointerRegion: String, Sendable, Equatable {
    case video
    case control
    case settings
    case chrome
    case activating
    case outside
}

public enum PlayerKey: String, Sendable, Equatable {
    case space
    case left, right, up, down
    case f, m, escape
    case openFile
    case settings
    case speedDown, speedUp
    case audioNext, subtitleNext
}

public enum InputEvent: Sendable, Equatable {
    case pointerDown(region: PointerRegion, xFraction: Double, clickCount: Int)
    case pointerUp(region: PointerRegion, xFraction: Double, clickCount: Int, held: Double)
    case secondaryClick(region: PointerRegion)
    case holdDelayElapsed
    case confirmClick
    case cancelClick
    case scroll(deltaX: Double, deltaY: Double, natural: Bool, precise: Bool, ended: Bool)
    case key(PlayerKey)
}

public enum PlayerCommand: Sendable, Equatable {
    case togglePlay
    case seek(Double)
    case adjustVolume(Double)
    case toggleMute
    case toggleFullscreen
    case exitFullscreen
    case beginFastForward
    case endFastForward
    case beginRewind
    case endRewind
    case openFile
    case toggleSettings
    case closeSettings
    case adjustRate(Double)
    case cycleAudio
    case cycleSubtitle
    case showContextMenu
}

/// Pure input rules. AppKit classifies the hit; this type only emits commands.
public struct InputReducer: Sendable, Equatable {
    public var volume: Double
    public var rate: Double
    public var settingsOpen: Bool
    public var fullscreen: Bool
    public private(set) var wantsClickConfirm = false

    private var downRegion: PointerRegion?
    private var downX = 0.5
    private var holding = false
    private var scrollX = 0.0
    private var seekedThisGesture = false

    public static let holdDelay = 0.3
    public static let volumeKeyStep = 0.05
    public static let seekStep = 10.0

    public init(volume: Double = 1, rate: Double = 1, settingsOpen: Bool = false, fullscreen: Bool = false) {
        self.volume = min(1, max(0, volume))
        self.rate = min(3, max(0.5, rate))
        self.settingsOpen = settingsOpen
        self.fullscreen = fullscreen
    }

    /// Control, settings, and chrome beat the video. A click that only activates the window is not a hit.
    public static func region(windowWasKey: Bool, inControl: Bool, inSettings: Bool, inChrome: Bool, inVideo: Bool) -> PointerRegion {
        if !windowWasKey { return .activating }
        if inSettings { return .settings }
        if inControl { return .control }
        if inChrome { return .chrome }
        if inVideo { return .video }
        return .outside
    }

    /// Right-click opens the video menu even when the window is not key, playback is paused,
    /// settings are open elsewhere, or a hidden bar still has a frame. A visible control, the
    /// settings card, and chrome do not.
    public static func secondary(
        pointInWindow: Bool,
        onVisibleControl: Bool,
        onSettingsCard: Bool,
        onChrome: Bool
    ) -> (showMenu: Bool, region: PointerRegion) {
        if onChrome { return (false, .chrome) }
        if onSettingsCard { return (false, .settings) }
        if onVisibleControl { return (false, .control) }
        if pointInWindow { return (true, .video) }
        return (false, .outside)
    }

    /// AppKit already inverted `scrollingDeltaY` when natural scrolling is on. Undo that so physical up is positive.
    public static func physicalDelta(_ delta: Double, natural: Bool) -> Double {
        natural ? -delta : delta
    }

    public mutating func noteVolume(_ value: Double) {
        volume = min(1, max(0, value))
    }

    public mutating func reduce(_ event: InputEvent) -> [PlayerCommand] {
        switch event {
        case let .pointerDown(region, xFraction, clickCount):
            return pointerDown(region, xFraction: xFraction, clickCount: clickCount)
        case let .pointerUp(region, xFraction, clickCount, held):
            return pointerUp(region, xFraction: xFraction, clickCount: clickCount, held: held)
        case let .secondaryClick(region):
            var commands: [PlayerCommand] = []
            if holding { commands.append(downX < 0.5 ? .endRewind : .endFastForward) }
            holding = false
            downRegion = nil
            wantsClickConfirm = false
            if region == .video { commands.append(.showContextMenu) }
            return commands
        case .holdDelayElapsed:
            return armHold()
        case .confirmClick:
            guard wantsClickConfirm else { return [] }
            wantsClickConfirm = false
            return [.togglePlay]
        case .cancelClick:
            wantsClickConfirm = false
            return []
        case let .scroll(deltaX, deltaY, natural, precise, ended):
            return scroll(deltaX: deltaX, deltaY: deltaY, natural: natural, precise: precise, ended: ended)
        case let .key(key):
            return keyDown(key)
        }
    }

    private mutating func pointerDown(_ region: PointerRegion, xFraction: Double, clickCount: Int) -> [PlayerCommand] {
        var release: [PlayerCommand] = []
        if holding { release = downX < 0.5 ? [.endRewind] : [.endFastForward] }
        wantsClickConfirm = false
        holding = false
        downRegion = region
        downX = xFraction
        if clickCount >= 2, region == .video, !settingsOpen {
            return release + [.toggleFullscreen]
        }
        return release
    }

    private mutating func pointerUp(_ region: PointerRegion, xFraction: Double, clickCount: Int, held: Double) -> [PlayerCommand] {
        let armed = downRegion
        let wasHolding = holding
        downRegion = nil
        holding = false
        if wasHolding {
            return xFraction < 0.5 || (armed == .video && downX < 0.5) ? [.endRewind] : [.endFastForward]
        }
        guard armed == .video, region == .video, !settingsOpen else { return [] }
        if clickCount >= 2 || held >= Self.holdDelay {
            return []
        }
        wantsClickConfirm = true
        return []
    }

    private mutating func armHold() -> [PlayerCommand] {
        guard downRegion == .video, !settingsOpen, !holding else { return [] }
        holding = true
        wantsClickConfirm = false
        return downX < 0.5 ? [.beginRewind] : [.beginFastForward]
    }

    private mutating func scroll(deltaX: Double, deltaY: Double, natural: Bool, precise: Bool, ended: Bool) -> [PlayerCommand] {
        let px = Self.physicalDelta(deltaX, natural: natural)
        let py = Self.physicalDelta(deltaY, natural: natural)
        var commands: [PlayerCommand] = []
        if abs(px) > abs(py), abs(px) > 0.4 {
            scrollX += px
            if !seekedThisGesture, abs(scrollX) >= 40 {
                seekedThisGesture = true
                commands.append(.seek(scrollX > 0 ? Self.seekStep : -Self.seekStep))
            }
        } else if abs(py) > 0.15 {
            let gain = precise ? 0.006 : 0.06
            let next = min(1, max(0, volume + py * gain))
            let applied = next - volume
            if abs(applied) > 0.000_001 {
                volume = next
                commands.append(.adjustVolume(applied))
            }
        }
        if ended {
            scrollX = 0
            seekedThisGesture = false
        }
        return commands
    }

    private mutating func keyDown(_ key: PlayerKey) -> [PlayerCommand] {
        if settingsOpen, key != .escape, key != .openFile, key != .settings {
            return []
        }
        switch key {
        case .space:
            return [.togglePlay]
        case .left:
            return [.seek(-Self.seekStep)]
        case .right:
            return [.seek(Self.seekStep)]
        case .up:
            return volumeStep(Self.volumeKeyStep)
        case .down:
            return volumeStep(-Self.volumeKeyStep)
        case .f:
            fullscreen.toggle()
            return [.toggleFullscreen]
        case .m:
            return [.toggleMute]
        case .escape:
            if settingsOpen {
                settingsOpen = false
                return [.closeSettings]
            }
            if fullscreen {
                fullscreen = false
                return [.exitFullscreen]
            }
            return []
        case .openFile:
            return [.openFile]
        case .settings:
            settingsOpen.toggle()
            return [.toggleSettings]
        case .speedDown:
            return rateStep(-0.25)
        case .speedUp:
            return rateStep(0.25)
        case .audioNext:
            return [.cycleAudio]
        case .subtitleNext:
            return [.cycleSubtitle]
        }
    }

    private mutating func volumeStep(_ delta: Double) -> [PlayerCommand] {
        let next = min(1, max(0, volume + delta))
        let applied = next - volume
        volume = next
        return abs(applied) > 0.000_001 ? [.adjustVolume(applied)] : []
    }

    private mutating func rateStep(_ delta: Double) -> [PlayerCommand] {
        let next = min(3, max(0.5, rate + delta))
        let applied = next - rate
        rate = next
        return abs(applied) > 0.000_001 ? [.adjustRate(applied)] : []
    }
}

public enum InputProbe {
    public static func report() -> String {
        var lines: [String] = []
        func check(_ name: String, _ ok: Bool) {
            lines.append(ok ? "pass \(name)" : "FAIL \(name)")
        }
        var box = InputReducer(volume: 0.4)
        let control = box.reduce(.pointerDown(region: .control, xFraction: 0.5, clickCount: 1))
            + box.reduce(.pointerUp(region: .control, xFraction: 0.5, clickCount: 1, held: 0.05))
            + box.reduce(.confirmClick)
        check("bar-click", !control.contains(.togglePlay))
        box.reduce(.pointerDown(region: .video, xFraction: 0.5, clickCount: 1))
        box.reduce(.pointerUp(region: .video, xFraction: 0.5, clickCount: 1, held: 0.05))
        let once = box.reduce(.confirmClick)
        let twice = box.reduce(.confirmClick)
        check("video-once", once == [.togglePlay] && twice.isEmpty)
        var wake = InputReducer()
        let ignored = wake.reduce(.pointerDown(region: .activating, xFraction: 0.2, clickCount: 1))
            + wake.reduce(.pointerUp(region: .activating, xFraction: 0.2, clickCount: 1, held: 0.05))
            + wake.reduce(.confirmClick)
        check("activate", ignored.isEmpty)
        var up = InputReducer(volume: 0.5)
        let raised = up.reduce(.scroll(deltaX: 0, deltaY: 10, natural: false, precise: true, ended: false))
        var down = InputReducer(volume: 0.5)
        let lowered = down.reduce(.scroll(deltaX: 0, deltaY: 10, natural: true, precise: true, ended: false))
        check("scroll-sign", (raised.firstVolume ?? 0) > 0 && (lowered.firstVolume ?? 0) < 0)
        var keys = InputReducer(volume: 0.5, rate: 1)
        check("space", keys.reduce(.key(.space)) == [.togglePlay])
        check("arrows", keys.reduce(.key(.left)) == [.seek(-10)] && (keys.reduce(.key(.up)).firstVolume ?? 0) > 0)
        check("f", keys.reduce(.key(.f)) == [.toggleFullscreen])
        check("m", keys.reduce(.key(.m)) == [.toggleMute])
        check("speed", keys.reduce(.key(.speedUp)) == [.adjustRate(0.25)])
        check("tracks", keys.reduce(.key(.audioNext)) == [.cycleAudio] && keys.reduce(.key(.subtitleNext)) == [.cycleSubtitle])
        check("open", keys.reduce(.key(.openFile)) == [.openFile])
        check("comma", keys.reduce(.key(.settings)) == [.toggleSettings])
        let failed = lines.contains { $0.hasPrefix("FAIL") }
        lines.append(failed ? "BUEHNE_INPUT_FAIL" : "BUEHNE_INPUT_OK")
        return lines.joined(separator: "\n")
    }
}

private extension Array where Element == PlayerCommand {
    var firstVolume: Double? {
        for case let .adjustVolume(delta) in self { return delta }
        return nil
    }
}
