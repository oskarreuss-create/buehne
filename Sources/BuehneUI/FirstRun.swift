import AppKit
import SwiftUI

/// Where first-launch state lives. Keys are in the app's own defaults domain (the bundle id), nothing else is touched.
public enum FirstRunStore {
    public static let version = "1"
    static let acceptedKey = "buehne.firstRun.accepted"
    static let shortcutOfferedKey = "buehne.firstRun.shortcutOffered"
    static let shortcutMadeKey = "buehne.firstRun.shortcutMade"
    /// Reading the desktop makes macOS ask for permission, so only someone who has a shortcut goes there.
    /// Installs from before this key existed count as having one if the question was already answered.
    static var hasShortcut: Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: shortcutMadeKey) as? Bool ?? defaults.bool(forKey: shortcutOfferedKey)
    }
    public static var accepted: Bool { UserDefaults.standard.string(forKey: acceptedKey) == version }
}

/// Desktop shortcut and installer-disk helpers.
public enum InstallHelper {
    /// A shortcut only makes sense once the app sits in its final place (not on the disk image, not in a translocated copy).
    public static var canMakeDesktopShortcut: Bool {
        let path = Bundle.main.bundlePath
        return !path.contains("AppTranslocation") && !path.hasPrefix("/Volumes/")
    }

    /// Alias bookmark on the desktop plus the glass icon. Returns an error text or nil.
    @discardableResult
    public static func createDesktopShortcut(dark: Bool = false) -> String? {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        var target = desktop.appendingPathComponent("BÜHNE"); var suffix = 2
        while FileManager.default.fileExists(atPath: target.path) { target = desktop.appendingPathComponent("BÜHNE \(suffix)"); suffix += 1 }
        do {
            let data = try Bundle.main.bundleURL.bookmarkData(options: .suitableForBookmarkFile)
            try URL.writeBookmarkData(data, to: target)
            if let icon = Bundle.main.url(forResource: "BUEHNE-icon-glass", withExtension: "icns").flatMap({ NSImage(contentsOf: $0) }) {
                _ = NSWorkspace.shared.setIcon(icon, forFile: target.path, options: [])
            }
            return nil
        } catch { return error.localizedDescription }
    }


    /// macOS rewrites an alias when its app is replaced (a reinstall), which drops the custom icon and the shortcut
    /// shows the plain, system-tinted app icon (grey). On every launch from the final place, find shortcuts on the
    /// desktop that point at this app and put the glass icon back where it is missing.
    public static func repairShortcutIcons() {
        guard FirstRunStore.hasShortcut else { return }
        // Off the main thread: a permission dialog must never hold the player back.
        DispatchQueue.global(qos: .utility).async { repairNow() }
    }

    private static func repairNow() {
        let path = Bundle.main.bundlePath
        guard !path.hasPrefix("/Volumes/"), !path.contains("AppTranslocation"),
              let icon = Bundle.main.url(forResource: "BUEHNE-icon-glass", withExtension: "icns").flatMap({ NSImage(contentsOf: $0) }),
              let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first,
              let items = try? FileManager.default.contentsOfDirectory(at: desktop, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else { return }
        for item in items {
            let values = try? item.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values?.isRegularFile == true, let size = values?.fileSize, size > 0, size < 16_384, item.pathExtension.isEmpty else { continue }
            // Already has its own icon (resource fork present): leave it.
            if getxattr(item.path, "com.apple.ResourceFork", nil, 0, 0, XATTR_NOFOLLOW) > 0 { continue }
            guard let data = try? URL.bookmarkData(withContentsOf: item) else { continue }
            var stale = false
            guard let target = try? URL(resolvingBookmarkData: data, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale),
                  target.standardizedFileURL.path == Bundle.main.bundleURL.standardizedFileURL.path else { continue }
            _ = NSWorkspace.shared.setIcon(icon, forFile: item.path, options: [])
        }
    }

    /// After the app was dragged into Applications and started from there, the installer disk is no longer needed:
    /// eject it. Only the exact installer volume is touched (name BÜHNE holding BÜHNE.app and the Applications link).
    public static func ejectInstallerDisk() {
        let path = Bundle.main.bundlePath
        guard !path.hasPrefix("/Volumes/"), !path.contains("AppTranslocation") else { return }
        let volume = URL(fileURLWithPath: "/Volumes/BÜHNE", isDirectory: true)
        let manager = FileManager.default
        guard manager.fileExists(atPath: volume.appendingPathComponent("BÜHNE.app").path),
              manager.fileExists(atPath: volume.appendingPathComponent("Applications").path) else { return }
        DispatchQueue.global(qos: .utility).async { try? NSWorkspace.shared.unmountAndEjectDevice(at: volume) }
    }
}

/// Shows the first-launch windows in order: language + shortcut, terms, licence, README. Declining quits the app.
@MainActor
public final class FirstRunController: ObservableObject {
    public static let shared = FirstRunController()
    @Published public private(set) var needed = !FirstRunStore.accepted
    private var window: NSWindow?
    private var finished = false
    private var closeObserver: NSObjectProtocol?

    public func present() {
        guard needed, window == nil else { return }
        let view = FirstRunView(onFinish: { [weak self] in self?.finish() }, onDecline: { NSApp.terminate(nil) })
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 380), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        w.titleVisibility = .hidden; w.titlebarAppearsTransparent = true
        w.isReleasedWhenClosed = false
        let glass = NSVisualEffectView(frame: w.contentRect(forFrameRect: w.frame))
        glass.material = .popover; glass.blendingMode = .behindWindow; glass.state = .active
        let host = NSHostingView(rootView: view)
        host.translatesAutoresizingMaskIntoConstraints = false
        glass.addSubview(host)
        NSLayoutConstraint.activate([host.leadingAnchor.constraint(equalTo: glass.leadingAnchor), host.trailingAnchor.constraint(equalTo: glass.trailingAnchor), host.topAnchor.constraint(equalTo: glass.topAnchor), host.bottomAnchor.constraint(equalTo: glass.bottomAnchor)])
        w.contentView = glass
        w.isOpaque = false; w.backgroundColor = .clear; w.alphaValue = 0.96
        w.center()
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if self?.finished == false { NSApp.terminate(nil) } }
        }
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        finished = true
        window?.close(); window = nil
        needed = false
    }
}

/// Wraps the player: while first launch is pending, the player window stays invisible and empty.
public struct FirstRunGate<Content: View>: View {
    @ObservedObject private var controller = FirstRunController.shared
    private let content: () -> Content
    public init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    public var body: some View {
        if controller.needed {
            Color.clear.background(WindowVeil()).onAppear { controller.present() }
        } else {
            content().background(WindowVeil(veiled: false))
        }
    }
}

private final class VeilView: NSView {
    var veiled = true { didSet { apply() } }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); apply() }
    func apply() { window?.alphaValue = veiled ? 0 : 1; window?.ignoresMouseEvents = veiled }
}

private struct WindowVeil: NSViewRepresentable {
    var veiled = true
    func makeNSView(context: Context) -> VeilView { let v = VeilView(); v.veiled = veiled; return v }
    func updateNSView(_ view: VeilView, context: Context) { view.veiled = veiled }
}

struct FirstRunView: View {
    let onFinish: () -> Void
    let onDecline: () -> Void
    @State private var step: Int
    @State private var language: String
    @State private var shortcutTick = true

    init(onFinish: @escaping () -> Void, onDecline: @escaping () -> Void, step: Int = 1, language: String = "en") {
        self.onFinish = onFinish; self.onDecline = onDecline
        _step = State(initialValue: step); _language = State(initialValue: language)
    }

    private var pack: FirstRunPack { FirstRunTexts.pack(language) }
    private func licenseText() -> String {
        func load(_ name: String) -> String {
            Bundle.module.url(forResource: name, withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        }
        return load("NOTICE") + "\n\n" + load("LICENSE")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch step {
            case 1: welcome
            case 2: terms
            case 3: license
            default: readme
            }
        }
        .padding(.horizontal, 24).padding(.top, 30).padding(.bottom, 20)
        .frame(width: 440, height: 380)
        .font(.system(size: 12))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("BÜHNE").font(.system(size: 24, weight: .light))
            Spacer()
            if step > 1 { Text("\(pack.step) \(step)/4").font(.system(size: 11)).foregroundStyle(.secondary) }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider().opacity(0.4)
            Text(pack.language).font(.system(size: 13)).foregroundStyle(.secondary)
            Picker("", selection: $language) { ForEach(FirstRunTexts.languages, id: \.code) { Text($0.name).tag($0.code) } }
                .labelsHidden().pickerStyle(.menu).fixedSize()
            Spacer()
            Divider().opacity(0.4)
            HStack {
                if InstallHelper.canMakeDesktopShortcut {
                    Toggle(pack.shortcut, isOn: $shortcutTick).toggleStyle(.checkbox)
                }
                Spacer()
                Button("→") { step = 2 }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }
    }

    private var terms: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Text(pack.termsTitle).font(.system(size: 16, weight: .light))
            Divider().opacity(0.4)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(pack.terms.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(section.0).font(.system(size: 12, weight: .medium))
                            Text(section.1).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.trailing, 8)
            }
            Divider().opacity(0.4)
            HStack {
                Button(pack.decline, role: .destructive) { onDecline() }.buttonStyle(.bordered)
                Spacer()
                Button(pack.accept) { step = 3 }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }
    }

    private var license: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Text(pack.licenseTitle).font(.system(size: 16, weight: .light))
            Text(pack.licenseNote).font(.system(size: 11)).foregroundStyle(.secondary)
            Divider().opacity(0.4)
            ScrollView {
                Text(licenseText()).font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.trailing, 8)
            }
            Divider().opacity(0.4)
            HStack {
                Button(pack.decline, role: .destructive) { onDecline() }.buttonStyle(.bordered)
                Spacer()
                Button(pack.accept) { step = 4 }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }
    }

    private var readme: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Text(pack.readmeTitle).font(.system(size: 16, weight: .light))
            Divider().opacity(0.4)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(pack.readme.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(section.0).font(.system(size: 12, weight: .medium))
                            Text(section.1).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.trailing, 8)
            }
            Divider().opacity(0.4)
            HStack { Spacer(); Button(pack.start) { complete() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction) }
        }
    }

    /// Remember everything, then create the shortcut once (only if the box is still ticked and the app is in its final place).
    private func complete() {
        let defaults = UserDefaults.standard
        defaults.set(language, forKey: "buehne.language")
        defaults.set(FirstRunStore.version, forKey: FirstRunStore.acceptedKey)
        if !defaults.bool(forKey: FirstRunStore.shortcutOfferedKey) {
            defaults.set(true, forKey: FirstRunStore.shortcutOfferedKey)
            let make = shortcutTick && InstallHelper.canMakeDesktopShortcut
            defaults.set(make, forKey: FirstRunStore.shortcutMadeKey)
            if make { InstallHelper.createDesktopShortcut() }
        }
        onFinish()
    }
}
