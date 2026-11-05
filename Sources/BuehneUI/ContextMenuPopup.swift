import AppKit

/// Menu presentation is behind this so probes can count popups without tracking a real menu.
@MainActor
public protocol ContextMenuPopup: AnyObject {
    func popUp(_ menu: NSMenu, event: NSEvent, view: NSView)
}

@MainActor
public final class AppKitContextMenuPopup: ContextMenuPopup {
    public init() {}
    public func popUp(_ menu: NSMenu, event: NSEvent, view: NSView) {
        // Next turn, not inside the rightMouseDown monitor. A popup started there
        // tracked the still-delivering click and dismissed before it could stay up.
        let menu = menu
        let event = event
        DispatchQueue.main.async {
            guard !AppKitContextMenuPopup.tracking else { return }
            AppKitContextMenuPopup.tracking = true
            NSMenu.popUpContextMenu(menu, with: event, for: view)
            AppKitContextMenuPopup.tracking = false
        }
    }

    private static var tracking = false
}

@MainActor
public final class CountingContextMenuPopup: ContextMenuPopup {
    public private(set) var count = 0
    public init() {}
    public func popUp(_ menu: NSMenu, event: NSEvent, view: NSView) {
        count += 1
    }
}
