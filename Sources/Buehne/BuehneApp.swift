import BuehneCore
import BuehneEngine
import BuehneUI
import AppKit
import SwiftUI

final class BuehneAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct BuehneApp: App {
    @NSApplicationDelegateAdaptor(BuehneAppDelegate.self) private var appDelegate
    @StateObject private var session: PlayerSession

    init() {
        let args = Array(CommandLine.arguments.dropFirst())
        if let index = args.firstIndex(of: "--print-position"), args.count > index + 1 {
            let url = URL(fileURLWithPath: (args[index + 1] as NSString).expandingTildeInPath)
            let key = OpenContract.positionKey(for: url)
            if let position = UserDefaultsPositionStore().position(for: key) {
                print(position)
                exit(0)
            }
            fputs("none\n", stderr)
            exit(2)
        }
        if let index = args.firstIndex(of: "--decorate"), args.count > index + 1 {
            let code = FileIconApply.decorateAndPrint(path: args[index + 1])
            exit(code)
        }
        _session = StateObject(wrappedValue: PlayerSession())
    }

    var body: some Scene {
        Window("BÜHNE", id: "main") {
            PlayerRootView(session: session, launchURL: OpenContract.mediaURL(from: CommandLine.arguments))
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: WindowGeometry.emptyWidth, height: WindowGeometry.emptyHeight)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open") { PlayerHost.shared.openPanel() }
                    .keyboardShortcut("o")
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings") { PlayerHost.shared.toggleSettings() }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
