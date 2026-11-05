import Foundation

public enum L10nKey: String, CaseIterable, Sendable {
    case open, play, pause, volume, back10, forward10, floating, exitFloating, pip, settings, done
    case theme, dark, light, automatic, liquidGlass, onScreenMessages, onScreenMenu, sidebar, opacity
    case barTransparency
    case videoFillsWindow, lockAspect, aspect, rotation, speed, language, brightness, contrast, saturation, gamma
    case brandedFileIcons, removeBrandedIcons, addIconFolder
    case detectBars, audioTrack, primarySubtitles, secondarySubtitles, none, dropVideo
    case secondaryNotRendered, fileMissing, openVideo
    case fit, fill, crop, timeline
    case minimize, closeWindow, fullScreen, alwaysOnTop, openFile
    case playlist, playlistOnBar
    case companionTitle, companionBody, companionLink
    case notDownloaded, inCloud
}

public enum L10n {
    public static let menuOrder = ["en", "de", "fr", "it", "ru", "es"]

    /// A missing or unknown preference is English. System language is ignored.
    /// First system language we ship, else English.
    public static func systemLanguage() -> String {
        for id in Locale.preferredLanguages {
            let code = String(id.prefix(2)).lowercased()
            if menuOrder.contains(code) { return code }
        }
        return "en"
    }

    public static func resolve(_ preference: String) -> String {
        menuOrder.contains(preference) ? preference : "en"
    }

    /// Looks up `Localization/Localizable.xcstrings` through the UI bundle. A missing catalog returns the key.
    public static func text(_ key: L10nKey, language preference: String) -> String {
        let language = resolve(preference)
        let bundle = bundle(for: language) ?? .module
        let table: String
        switch key {
        case .crop, .timeline, .minimize, .closeWindow, .fullScreen, .alwaysOnTop, .openFile:
            table = "PlayerChrome"
        default:
            table = "Localizable"
        }
        let value = bundle.localizedString(forKey: key.rawValue, value: key.rawValue, table: table)
        if value != key.rawValue { return value }
        return Bundle.module.localizedString(forKey: key.rawValue, value: key.rawValue, table: table)
    }

    private static let languages: Set<String> = ["en", "de", "fr", "it", "ru", "es"]

    private static func bundle(for language: String) -> Bundle? {
        guard let path = Bundle.module.path(forResource: language, ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }
}

public enum BuehneTime {
    /// Time left, with a minus sign. Unknown duration shows a dash.
    public static func remaining(_ duration: TimeInterval?, elapsed: TimeInterval) -> String {
        guard let duration, duration.isFinite, duration > 0, elapsed.isFinite else { return "\u{2212}\u{2014}" }
        return "\u{2212}" + format(max(0, duration - max(0, elapsed)))
    }

    public static func format(_ time: TimeInterval?) -> String {
        guard let time, time.isFinite, time >= 0 else { return "—" }
        let total = Int(time.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
