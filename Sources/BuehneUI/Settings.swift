import BuehneCore
import Combine
import Foundation
import SwiftUI

@MainActor
public final class BuehneSettings: ObservableObject {
    @Published public var theme: String
    @Published public var glassOpacity: Double
    @Published public var barTransparency: Double
    @Published public var onScreenMessages: Bool
    @Published public var onScreenMenu: Bool
    @Published public var sidebar: Bool
    @Published public var videoFillsWindow: Bool
    @Published public var lockAspect: Bool
    @Published public var aspect: String
    @Published public var crop: String
    @Published public var rotation: Int
    @Published public var detectBars: Bool
    @Published public var language: String
    @Published public var floating: Bool
    @Published public var alwaysOnTop: Bool
    @Published public var brandedFileIcons: Bool
    @Published public var iconFolders: [String]
    @Published public var playlistFolders: [String]
    @Published public var playlistOnBar: Bool
    private let defaults: UserDefaults
    private var writing = false

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = defaults.string(forKey: Key.theme) ?? "auto"
        let storedGlass = defaults.object(forKey: Key.glassOpacity) as? Double
        let glassUnit = defaults.string(forKey: Key.glassOpacityUnit)
        glassOpacity = GlassAppearance.resolvedTransparency(stored: storedGlass, unit: glassUnit)
        if let storedBar = defaults.object(forKey: Key.barTransparency) as? Double {
            barTransparency = min(100, max(0, storedBar))
        } else {
            barTransparency = GlassAppearance.defaultTransparency
        }
        onScreenMessages = defaults.object(forKey: Key.onScreenMessages) as? Bool ?? true
        onScreenMenu = defaults.object(forKey: Key.onScreenMenu) as? Bool ?? true
        sidebar = defaults.object(forKey: Key.sidebar) as? Bool ?? false
        videoFillsWindow = defaults.object(forKey: Key.videoFillsWindow) as? Bool ?? false
        lockAspect = defaults.object(forKey: Key.lockAspect) as? Bool ?? true
        aspect = defaults.string(forKey: Key.aspect) ?? "fit"
        crop = defaults.string(forKey: Key.crop) ?? "none"
        rotation = defaults.object(forKey: Key.rotation) as? Int ?? 0
        detectBars = defaults.object(forKey: Key.detectBars) as? Bool ?? true
        let storedLanguage = defaults.string(forKey: Key.language) ?? L10n.systemLanguage()
        language = L10n.resolve(storedLanguage)
        floating = false
        alwaysOnTop = false
        brandedFileIcons = FileIconApply.enabled(defaults: defaults)
        playlistFolders = defaults.stringArray(forKey: "buehne.playlistFolders") ?? []
        playlistOnBar = defaults.object(forKey: "buehne.playlistOnBar") as? Bool ?? false
        if let storedFolders = defaults.stringArray(forKey: FileIconApply.foldersKey) {
            iconFolders = FileIconPolicy.migrated(stored: storedFolders, home: FileManager.default.homeDirectoryForCurrentUser)
        } else {
            iconFolders = FileIconPolicy.defaultFolders(home: FileManager.default.homeDirectoryForCurrentUser).map(\.path)
        }
        writing = true
    }

    public func persist() {
        guard writing else { return }
        defaults.set(theme, forKey: Key.theme)
        defaults.set(glassOpacity, forKey: Key.glassOpacity)
        defaults.set(GlassAppearance.percentUnit, forKey: Key.glassOpacityUnit)
        defaults.set(barTransparency, forKey: Key.barTransparency)
        defaults.set(onScreenMessages, forKey: Key.onScreenMessages)
        defaults.set(onScreenMenu, forKey: Key.onScreenMenu)
        defaults.set(sidebar, forKey: Key.sidebar)
        defaults.set(videoFillsWindow, forKey: Key.videoFillsWindow)
        defaults.set(lockAspect, forKey: Key.lockAspect)
        defaults.set(aspect, forKey: Key.aspect)
        defaults.set(crop, forKey: Key.crop)
        defaults.set(rotation, forKey: Key.rotation)
        defaults.set(detectBars, forKey: Key.detectBars)
        defaults.set(language, forKey: Key.language)
        defaults.set(brandedFileIcons, forKey: FileIconApply.enabledKey)
        defaults.set(iconFolders, forKey: FileIconApply.foldersKey)
        defaults.set(playlistFolders, forKey: "buehne.playlistFolders")
        defaults.set(playlistOnBar, forKey: "buehne.playlistOnBar")
    }

    public var preferredScheme: ColorScheme? { BuehneTheme.preferredScheme(theme) }

    /// Settings, empty card, and context chrome share this transparency percent. The control bar does not.
    public var menuOpacity: Double { glassOpacity }
    public var chromeOpacity: Double { glassOpacity }

    public var resolvedLanguage: String { L10n.resolve(language) }

    public func text(_ key: L10nKey) -> String { L10n.text(key, language: language) }

    private enum Key {
        static let theme = "buehne.theme"
        static let glassOpacity = "buehne.glassOpacity"
        static let glassOpacityUnit = "buehne.glassOpacityUnit"
        static let barTransparency = "buehne.barTransparency"
        static let onScreenMessages = "buehne.onScreenMessages"
        static let onScreenMenu = "buehne.onScreenMenu"
        static let sidebar = "buehne.sidebar"
        static let videoFillsWindow = "buehne.videoFillsWindow"
        static let lockAspect = "buehne.lockAspect"
        static let aspect = "buehne.aspect"
        static let crop = "buehne.crop"
        static let rotation = "buehne.rotation"
        static let detectBars = "buehne.detectBars"
        static let language = "buehne.language"
    }
}

public enum BuehneColor {
    public static let lightBackground = Color(red: 250.0 / 255, green: 250.0 / 255, blue: 255.0 / 255)
    public static let darkPanel = Color(red: 32.0 / 255, green: 32.0 / 255, blue: 32.0 / 255)
    public static let markRed = Color(red: 227.0 / 255, green: 6.0 / 255, blue: 19.0 / 255)
    public static let accent = Color(red: 10.0 / 255, green: 132.0 / 255, blue: 255.0 / 255)
}

public enum BuehneFont {
    public static var body: Font { .custom(BuehneTypeName.body, size: 13) }
    public static var panelTitle: Font { .custom(BuehneTypeName.panelTitle, size: 22) }
    public static var sectionTitle: Font { .custom(BuehneTypeName.sectionTitle, size: 22) }
    public static var itemTitle: Font { .custom(BuehneTypeName.itemTitle, size: 15) }
    public static var label: Font { .custom(BuehneTypeName.label, size: 14) }
    public static var caption: Font { .custom(BuehneTypeName.caption, size: 12) }
    public static var micro: Font { .custom(BuehneTypeName.micro, size: 10) }
    public static func light(_ size: CGFloat) -> Font { .custom(BuehneTypeName.body, size: size) }
    public static func regular(_ size: CGFloat) -> Font { .custom(BuehneTypeName.label, size: size) }
    public static func bold(_ size: CGFloat) -> Font { .custom(BuehneTypeName.panelTitle, size: size) }
    public static func title(_ size: CGFloat) -> Font { .custom(BuehneTypeName.sectionTitle, size: size) }
}
