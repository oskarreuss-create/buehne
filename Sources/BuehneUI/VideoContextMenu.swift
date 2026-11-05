import AppKit
import BuehneCore

/// Native menu reached only through InputMonitor's secondary-click reducer path.
@MainActor
final class VideoContextMenu: NSObject {
    var onCommand: (PlayerCommand) -> Void = { _ in }
    var onAlwaysOnTop: (Bool) -> Void = { _ in }
    var popup: ContextMenuPopup = AppKitContextMenuPopup()
    private var pinned = false
    private weak var window: NSWindow?

    private enum Action: Int {
        case play, minimize, close, fullscreen, open, settings, alwaysOnTop
    }

    func present(event: NSEvent, window: NSWindow, playing: Bool, settingsOpen: Bool, pinned: Bool = false, text: (L10nKey) -> String) {
        guard let content = window.contentView else { return }
        let menu = makeMenu(window: window, playing: playing, settingsOpen: settingsOpen, pinned: pinned, text: text)
        popup.popUp(menu, event: event, view: content)
    }

    func makeMenu(window: NSWindow, playing: Bool, settingsOpen: Bool, pinned: Bool = false, text: (L10nKey) -> String) -> NSMenu {
        self.window = window
        self.pinned = pinned
        let menu = NSMenu()
        menu.autoenablesItems = false
        func add(_ title: String, _ action: Action, checked: Bool = false) {
            let item = NSMenuItem(title: title, action: #selector(select(_:)), keyEquivalent: "")
            item.target = self
            item.tag = action.rawValue
            item.state = checked ? .on : .off
            menu.addItem(item)
        }
        add(text(playing ? .pause : .play), .play)
        menu.addItem(.separator())
        add(text(.minimize), .minimize)
        add(text(.closeWindow), .close)
        add(text(.fullScreen), .fullscreen, checked: window.styleMask.contains(.fullScreen))
        add(text(.alwaysOnTop), .alwaysOnTop, checked: window.level == .floating)
        menu.addItem(.separator())
        add(text(.openFile), .open)
        add(text(.settings), .settings, checked: settingsOpen)
        return menu
    }

    @objc private func select(_ sender: NSMenuItem) {
        guard let action = Action(rawValue: sender.tag) else { return }
        switch action {
        case .play: onCommand(.togglePlay)
        case .minimize: window?.miniaturize(nil)
        case .close: window?.performClose(nil)
        case .fullscreen: window?.toggleFullScreen(nil)
        case .open: onCommand(.openFile)
        case .settings: onCommand(.toggleSettings)
        case .alwaysOnTop:
            let next = window?.level != .floating
            pinned = next
            window?.level = next ? .floating : .normal
            sender.state = next ? .on : .off
            onAlwaysOnTop(next)
        }
    }
}
