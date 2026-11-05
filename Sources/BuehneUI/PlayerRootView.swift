import AppKit
import AVFoundation
import BuehneCore
import BuehneEngine
import SwiftUI
import UniformTypeIdentifiers

public struct PlayerRootView: View {
    @ObservedObject var session: PlayerSession
    @StateObject private var settings: BuehneSettings
    @Environment(\.colorScheme) private var colorScheme
    @State private var showSettings = false
    @State private var isFullscreen = false
    @State private var barAnchor = BarAnchor(rawValue: UserDefaults.standard.string(forKey: BarAnchor.storageKey) ?? "") ?? .bottomCenter
    @State private var barDrag = CGSize.zero
    @State private var barDragging = false
    @State private var controlsVisible = true
    @State private var hover = FloatingBarVisibility()
    @State private var hoverHide: Task<Void, Never>?
    @State private var volumeOpen = false
    @State private var scrubTime: Double?
    @State private var osd: String?
    @State private var volumeHUD: Int?
    @State private var hideTask: Task<Void, Never>?
    @State private var volumeHide: Task<Void, Never>?
    @State private var pip = PictureInPictureBridge()
    @State private var monitor = InputMonitor()
    @State private var contextMenu = VideoContextMenu()
    private let launchURL: URL?
    private let keepOffscreen: Bool

    public init(session: PlayerSession, settings: BuehneSettings? = nil, launchURL: URL? = nil, keepOffscreen: Bool = false) {
        self.session = session
        _settings = StateObject(wrappedValue: settings ?? BuehneSettings())
        self.launchURL = launchURL
        self.keepOffscreen = keepOffscreen
    }

    private var isLight: Bool { BuehneTheme.isLight(theme: settings.theme, system: colorScheme) }

    public var body: some View {
        ZStack {
            Color.clear
            video
            chrome
            WindowChrome(
                lockAspect: settings.lockAspect,
                aspect: windowAspect,
                floating: settings.floating,
                alwaysOnTop: settings.alwaysOnTop,
                videoWidth: displayVideoSize.0,
                videoHeight: displayVideoSize.1,
                keepOffscreen: keepOffscreen,
                showTrafficLights: showTrafficLights
)
            .frame(width: 0, height: 0)
        }
        .font(BuehneFont.regular(13))
        .tracking(0.15)
        .tint(BuehneColor.accent)
        .preferredColorScheme(settings.preferredScheme)
        .environment(\.locale, Locale(identifier: settings.resolvedLanguage))
        .containerBackground(.clear, for: .window)
        .focusable()
        .focusEffectDisabled()
        .onAppear(perform: appeared)
        .onDisappear { monitor.stop() }
        .onContinuousHover { phase in
            if settings.floating { return }
            if case .active = phase { revealControls() }
        }
        .background {
            FloatingHoverTracker(
                enabled: settings.floating && hoverScript == nil,
                onEnter: { noteHover(.entered) },
                onMove: { noteHover(.moved) },
                onExit: { noteHover(.exited) }
            )
            .ignoresSafeArea()
        }
        .onChange(of: showSettings) { _, open in
            monitor.settingsOpen = open
            syncBarHits()
            if !open { monitor.settingsFrame = .null }
            noteHover(.settings(open || volumeOpen))
        }
        .onChange(of: volumeOpen) { _, open in
            noteHover(.settings(showSettings || open))
        }
        .onChange(of: settings.floating) { _, floating in
            if floating { seedFloatingHover() } else {
                hoverHide?.cancel()
                revealControls()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil, perform: dropFiles)
        .task { await poll() }
        .task(id: settings.playlistFolders) { await PlaylistStore.shared.refresh(folders: settings.playlistFolders) }
        .onChange(of: settings.detectBars) { _, enabled in session.detectBars = enabled }
        .onChange(of: settings.aspect) { _, _ in pushPicture() }
        .onChange(of: settings.crop) { _, _ in pushPicture() }
        .onChange(of: session.snapshot.phase) { _, phase in
            guard CommandLine.arguments.contains("--paused-floating"), phase == .playing else { return }
            session.togglePlay()
        }
        .onChange(of: settings.rotation) { _, _ in pushPicture() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in session.persistPosition() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in session.persistPosition() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in isFullscreen = true }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in isFullscreen = false }
        .onChange(of: showSettings) { _, open in if open { session.setHoldFastForward(false) } }
        .onOpenURL { url in
            guard let media = OpenContract.mediaURL(fromLaunchURL: url) else { return }
            Task { await session.open(url: media) }
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private var chrome: some View {
        GeometryReader { geo in
            let scale = settings.floating ? BarScale.factor(windowWidth: geo.size.width) : 1
            ZStack {
            if showsEmptyCard {
                emptyState
                    .environment(\.buehneBarWidth, max(1, geo.size.width - 2 * 12))
            }
            if let osd, settings.onScreenMessages {
                GlassPanel(radius: 100, opacity: settings.chromeOpacity, isLight: isLight) {
                    Text(osd)
                        .font(BuehneFont.regular(13))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .offset(y: -36)
            }
            if let volumeHUD {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(volumeHUD)")
                            .font(.system(size: 56 * scale, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.7), radius: 1.5, y: 1)
                            .padding(.trailing, 22)
                            .padding(.bottom, showsEmptyCard ? 20 : 62)
                            .accessibilityIdentifier("buehne.volumeHUD")
                    }
                }
                .allowsHitTesting(false)
            }
            if !showsEmptyCard && (settings.floating || controlsVisible || showSettings) {
                let inset = BuehneLayout.windowInset * scale
                let cardRoom = showSettings ? min(BuehneLayout.cardWidth, geo.size.width) + BuehneLayout.settingsInset : 0
                let areaW = max(1, geo.size.width - cardRoom)
                let barW = min(BuehneLayout.controlWidth * scale, max(1, areaW - 2 * inset))
                let barH = CGFloat(BarScale.hitSide(32, scale: scale)) + 2 * scale
                let freeW = max(0, areaW - 2 * inset - barW)
                let freeH = max(0, geo.size.height - 2 * inset - barH)
                let unit = barAnchor.unit
                let baseX = inset + barW / 2 + unit.x * freeW
                let baseY = inset + barH / 2 + unit.y * freeH
                bar
                    .environment(\.buehneBarScale, scale)
                    .environment(\.buehneBarWidth, barW)
                    .opacity(settings.floating && !hover.visible ? 0 : 1)
                    .allowsHitTesting(!settings.floating || hover.visible)
                    .animation(
                        .easeInOut(duration: hover.visible ? FloatingBarVisibility.fadeIn : FloatingBarVisibility.fadeOut),
                        value: hover.visible
                    )
                    .position(x: baseX + barDrag.width, y: baseY + barDrag.height)
                    .animation(barDragging ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: barDrag)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: barAnchor)
                    .transition(.opacity)
                    .zIndex(20)
                    .onChange(of: barDragging) { _, dragging in
                        if !dragging {
                            let cx = baseX + barDrag.width - barW / 2 - inset
                            let cy = baseY + barDrag.height - barH / 2 - inset
                            let next = BarAnchor.nearest(x: freeW > 0 ? cx / freeW : 0.5, y: freeH > 0 ? cy / freeH : 1)
                            barAnchor = next
                            UserDefaults.standard.set(next.rawValue, forKey: BarAnchor.storageKey)
                            barDrag = .zero
                        }
                    }
            }
            if isFullscreen && session.snapshot.phase == .paused {
                HStack(spacing: 0) {
                    fullscreenDot(.red, symbol: "xmark", label: settings.text(.closeWindow)) { NSApp.keyWindow?.close() }
                    fullscreenDot(.yellow, symbol: "minus", label: settings.text(.minimize)) {
                        let window = NSApp.keyWindow
                        window?.toggleFullScreen(nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { window?.miniaturize(nil) }
                    }
                    fullscreenDot(.green, symbol: "arrow.down.right.and.arrow.up.left", label: settings.text(.fullScreen)) {
                        NSApp.keyWindow?.toggleFullScreen(nil)
                    }
                }
                .padding(.leading, 6)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .zIndex(25)
                .transition(.opacity)
            }
            if showSettings {
                settingsCard
                    .transition(.move(edge: .trailing))
                    .zIndex(30)
            }
        }
            .animation(.easeInOut(duration: 0.22), value: showSettings)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }


    @ViewBuilder private var video: some View {
        if session.snapshot.engine == .libmpv {
            videoSurface(gravity: .resizeAspect)
                .ignoresSafeArea()
        } else {
            GeometryReader { geometry in
                let size = session.snapshot.videoSize
                let placement = PictureLayout.placement(
                    windowWidth: geometry.size.width,
                    windowHeight: geometry.size.height,
                    codedWidth: size.isKnown ? size.width : 16,
                    codedHeight: size.isKnown ? size.height : 9,
                    aspect: settings.aspect,
                    crop: settings.crop,
                    rotation: settings.rotation,
                    fill: settings.videoFillsWindow
                )
                let gravity: AVLayerVideoGravity = placement.cropToFill ? .resizeAspectFill : (PictureLayout.ratio(settings.aspect) == nil ? .resizeAspect : .resize)
                videoSurface(gravity: gravity)
                    .frame(width: placement.sourceWidth, height: placement.sourceHeight)
                    .scaleEffect(
                        x: placement.contentWidth / placement.sourceWidth,
                        y: placement.contentHeight / placement.sourceHeight
                    )
                    .frame(width: placement.contentWidth, height: placement.contentHeight)
                    .rotationEffect(.degrees(Double(placement.rotation)))
                    .frame(width: placement.boxWidth, height: placement.boxHeight)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .ignoresSafeArea()
        }
    }

    private func videoSurface(gravity: AVLayerVideoGravity) -> some View {
        VideoSurface(player: session.avPlayer, gravity: gravity, frame: session.renderedFrame, metalLayer: session.displayLayer) { layer in
            pip.attach(layer)
        }
    }


    @ViewBuilder private var bar: some View {
        GlassPanel(radius: BuehneLayout.cornerRadius, opacity: settings.barTransparency, isLight: isLight, interactive: true) {
            barControls
        }
        .background(WindowFrameReader { monitor.controlFrame = $0 })
        .contentShape(Rectangle())
    }

    private var barControls: some View {
        ControlBar(
            session: session,
            settings: settings,
            volumeOpen: $volumeOpen,
            scrubTime: $scrubTime,
            isLight: isLight,
            isFullscreen: isFullscreen,
            onFloating: {
                // A floating window carries a contentMaxSize cap; AppKit refuses native full screen under it.
                let window = NSApp.keyWindow
                if settings.floating && window?.styleMask.contains(.fullScreen) != true {
                    settings.floating = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { window?.toggleFullScreen(nil) }
                } else {
                    window?.toggleFullScreen(nil)
                }
            },
            onPip: {
                if let message = pip.toggle() { flash(message) }
            },
            onSettings: {
                showSettings = SettingsClick.afterGear(open: showSettings)
                monitor.settingsOpen = showSettings
                controlsVisible = true
            },
            onVolume: { showVolumeHUD() },
            onDrag: { noteHover(.dragging($0)) },
            onMove: { barDrag = $0; barDragging = true },
            onMoveEnd: { barDragging = false }
        )
    }

    private func fullscreenDot(_ color: Color, symbol: String, label: String, action: @escaping () -> Void) -> some View {
        BarIconButton(label: label, identifier: "buehne.fs.\(symbol)", action: action) {
            Circle()
                .fill(color)
                .frame(width: 13, height: 13)
                .overlay(Image(systemName: symbol).font(.system(size: 7, weight: .bold)).foregroundStyle(Color.black.opacity(0.55)))
        }
    }

    private var showsEmptyCard: Bool {
        session.snapshot.phase == .idle || session.snapshot.phase == .failed
    }

    private var showTrafficLights: Bool {
        TrafficLightVisibility.show(
            fullscreen: isFullscreen,
            paused: session.snapshot.phase == .paused,
            hasMedia: session.snapshot.phase == .paused || session.snapshot.phase == .playing
        )
    }

    private var settingsCard: some View {
        GeometryReader { geometry in
            let width = max(0, min(BuehneLayout.cardWidth, geometry.size.width - 2 * BuehneLayout.settingsInset))
            ZStack(alignment: .trailing) {
                SettingsDismissalBackdrop(panelWidth: width, floating: settings.floating) {
                    showSettings = SettingsClick.afterOutside(open: showSettings)
                    monitor.settingsOpen = showSettings
                }
                SettingsCard(session: session, settings: settings, isLight: isLight) { showSettings = false }
                    .frame(
                        width: width,
                        height: max(0, geometry.size.height - 2 * BuehneLayout.settingsInset)
                    )
                    .background(WindowFrameReader { monitor.settingsFrame = $0 })
                    .padding(BuehneLayout.settingsInset)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }

    private var emptyState: some View {
        GlassPanel(radius: BuehneLayout.welcomeRadius, opacity: settings.glassOpacity, isLight: isLight) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: 10) {
                    BuehneWordmark(width: 220)
                    Text(session.snapshot.phase == .failed ? (session.snapshot.error ?? settings.text(.fileMissing)) : settings.text(.dropVideo))
                        .font(BuehneFont.regular(12))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                    Button(settings.text(.open), action: chooseFile)
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel(settings.text(.open))
                }
                .padding(.horizontal, 28)
                Spacer(minLength: 0)
                barControls
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: BuehneLayout.welcomeRadius, style: .continuous))
        .background(WindowDragArea().clipShape(RoundedRectangle(cornerRadius: BuehneLayout.welcomeRadius, style: .continuous)))
        .overlay(alignment: .topLeading) { WelcomeWindowButtons().padding(.leading, 22).padding(.top, 18) }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private var windowAspect: Double {
        let size = session.snapshot.videoSize
        return PictureLayout.displayAspect(
            codedWidth: size.isKnown ? size.width : 16,
            codedHeight: size.isKnown ? size.height : 9,
            aspect: settings.aspect,
            crop: settings.crop,
            rotation: settings.rotation
        )
    }

    private var displayVideoSize: (Double, Double) {
        let size = session.snapshot.videoSize
        guard size.isKnown else { return (0, 0) }
        return (windowAspect * 1000, 1000)
    }

    private func pushPicture() {
        session.applyPicture(aspect: settings.aspect, crop: settings.crop, rotation: settings.rotation)
    }

    private func appeared() {
        NSApp.setActivationPolicy(keepOffscreen ? .accessory : .regular)
        if CommandLine.arguments.contains("--show-volume-hud") { volumeHUD = 65 }
        session.detectBars = settings.detectBars
        pushPicture()
        if CommandLine.arguments.contains("--show-settings") { showSettings = true }
        if CommandLine.arguments.contains("--paused-floating") { settings.floating = true }
        if CommandLine.arguments.contains("--hover-in") || CommandLine.arguments.contains("--hover-out") {
            settings.floating = true
        }
        if CommandLine.arguments.contains("--press-expand") {
            settings.floating = FloatingApply.toggled(settings.floating)
        }
        if let bar = captureBarTransparency() {
            settings.barTransparency = bar
            showSettings = false
            controlsVisible = true
        }
        if let raw = CommandLine.arguments.first(where: { $0.hasPrefix("--open=") }) {
            let path = String(raw.dropFirst("--open=".count))
            if let url = OpenContract.mediaURL(parsing: path) {
                Task { await session.open(url: url) }
            }
        }
        FileIconService.shared.startIfEnabled()
        let headroom = NSScreen.main?.maximumExtendedDynamicRangeColorComponentValue ?? 1
        session.displayPeakNits = 203 * max(1, headroom)
        monitor.volumeNow = { session.volume }
        monitor.onCommand = { apply($0) }
        monitor.onContextMenu = { event in
            noteHover(.settings(true))
            guard let window = event.window else {
                noteHover(.settings(showSettings || volumeOpen))
                return
            }
            contextMenu.onCommand = { apply($0) }
            contextMenu.onAlwaysOnTop = { settings.alwaysOnTop = $0 }
            contextMenu.present(
                event: event, window: window,
                playing: session.snapshot.phase == .playing,
                settingsOpen: showSettings,
                pinned: settings.alwaysOnTop,
                text: settings.text
            )
            noteHover(.settings(showSettings || volumeOpen))
        }
        monitor.isVideoHit = { event in
            guard let content = event.window?.contentView else { return false }
            let local = content.convert(event.locationInWindow, from: nil)
            var hit = content.hitTest(local)
            while let view = hit {
                if view is PlayerLayerView { return true }
                hit = view.superview
            }
            return false
        }
        syncBarHits()
        if !keepOffscreen { monitor.start() }
        PlayerHost.shared.openPanel = chooseFile
        PlayerHost.shared.toggleSettings = {
            showSettings.toggle()
            monitor.settingsOpen = showSettings
            controlsVisible = true
        }
        if let launchURL {
            Task { await session.open(url: launchURL) }
        }
        if settings.floating { seedFloatingHover() } else { revealControls() }
    }

    private func apply(_ command: PlayerCommand) {
        switch command {
        case .togglePlay:
            session.togglePlay()
        case .seek(let delta):
            nudge(by: delta)
        case .adjustVolume(let delta):
            session.adjustVolume(by: delta)
            showVolumeHUD()
        case .toggleMute:
            session.toggleMute()
            showVolumeHUD()
        case .toggleFullscreen:
            let native = NSApp.keyWindow?.styleMask.contains(.fullScreen) == true
            if settings.floating && !native {
                settings.floating = false
            } else {
                NSApp.keyWindow?.toggleFullScreen(nil)
            }
        case .exitFullscreen:
            if NSApp.keyWindow?.styleMask.contains(.fullScreen) == true {
                NSApp.keyWindow?.toggleFullScreen(nil)
            } else if settings.floating {
                settings.floating = false
            }
        case .beginFastForward:
            session.setHoldFastForward(true)
        case .endFastForward:
            session.setHoldFastForward(false)
        case .beginRewind, .endRewind:
            break
        case .openFile:
            chooseFile()
        case .toggleSettings:
            showSettings.toggle()
            monitor.settingsOpen = showSettings
            controlsVisible = true
        case .closeSettings:
            showSettings = false
            monitor.settingsOpen = false
            monitor.settingsFrame = .null
        case .adjustRate(let delta):
            session.setPreferredRate(session.preferredRate + delta)
            flash(String(format: "%.2f×", session.preferredRate))
        case .cycleAudio:
            session.cycleAudio()
            flash(settings.text(.audioTrack))
        case .cycleSubtitle:
            session.cycleSubtitle()
            flash(settings.text(.primarySubtitles))
        case .showContextMenu:
            // InputMonitor supplies the originating event to onContextMenu.
            break
        }
    }

    private func showVolumeHUD() {
        volumeHUD = Int((session.volume * 100).rounded())
        let shown = volumeHUD
        volumeHide?.cancel()
        volumeHide = Task {
            try? await Task.sleep(for: .seconds(1.2))
            if !Task.isCancelled, volumeHUD == shown { volumeHUD = nil }
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = PlayerRootView.videoTypes
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await session.open(url: url) }
    }

    private func dropFiles(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = item as? URL
            }
            guard let url else { return }
            Task { @MainActor in await session.open(url: url) }
        }
        return true
    }

    private func nudge(by delta: TimeInterval) {
        session.seek(by: delta)
        flash(delta < 0 ? settings.text(.back10) : settings.text(.forward10))
    }

    private func flash(_ text: String) {
        guard settings.onScreenMessages else { return }
        osd = text
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            if osd == text { osd = nil }
        }
    }

    private var hoverScript: String? {
        if CommandLine.arguments.contains("--hover-in") { return "in" }
        if CommandLine.arguments.contains("--hover-out") { return "out" }
        return nil
    }

    private func seedFloatingHover() {
        switch hoverScript {
        case "in":
            noteHover(.entered)
        case "out":
            noteHover(.entered)
            noteHover(.exited)
        default:
            if cursorInsidePlayer() { noteHover(.moved) }
        }
    }

    private func cursorInsidePlayer() -> Bool {
        let window = NSApp.keyWindow ?? NSApp.mainWindow
        guard let content = window?.contentView else { return false }
        let local = content.convert(window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)
        return content.bounds.contains(local)
    }

    private func noteHover(_ event: FloatingBarVisibility.Event) {
        var next = hover
        let effect = next.reduce(event)
        hover = next
        syncBarHits()
        switch effect {
        case .armHide:
            hoverHide?.cancel()
            hoverHide = Task { @MainActor in
                try? await Task.sleep(for: .seconds(FloatingBarVisibility.hideDelay))
                guard !Task.isCancelled else { return }
                noteHover(.hideDelayElapsed)
            }
        case .show, .cancelHide:
            hoverHide?.cancel()
            hoverHide = nil
        case .hide, .hold:
            break
        }
    }

    private func syncBarHits() {
        let shown = showsEmptyCard || settings.floating || controlsVisible || showSettings
        monitor.barAcceptsHits = shown && (!settings.floating || showsEmptyCard || hover.visible)
        if !monitor.barAcceptsHits { monitor.controlFrame = .null }
    }

    private func revealControls() {
        controlsVisible = true
        syncBarHits()
        hideTask?.cancel()
        if captureBarTransparency() != nil { return }
        hideTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            if !Task.isCancelled, !showSettings {
                controlsVisible = false
                syncBarHits()
            }
        }
    }

    private func captureBarTransparency() -> Double? {
        guard let raw = CommandLine.arguments.first(where: { $0.hasPrefix("--bar-transparency=") }) else { return nil }
        let value = Double(raw.dropFirst("--bar-transparency=".count))
        guard let value, value.isFinite else { return nil }
        return min(100, max(0, value))
    }
    private func poll() async {
        // Common run-loop modes: the picture keeps moving while a menu is tracking.
        nonisolated(unsafe) let target = session
        let timer = Timer(timeInterval: 0.008, repeats: true) { _ in
            MainActor.assumeIsolated { target.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        defer { timer.invalidate() }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3600))
        }
    }

    public static let videoTypes: [UTType] = {
        var types: [UTType] = [.mpeg4Movie, .quickTimeMovie, .movie]
        for ext in ["mkv", "avi", "webm", "m4v", "wmv", "flv", "ts", "m2ts"] {
            if let type = UTType(filenameExtension: ext) { types.append(type) }
        }
        return types
    }()
}

@MainActor
public final class PlayerHost: ObservableObject {
    public static let shared = PlayerHost()
    public var openPanel: () -> Void = {}
    public var toggleSettings: () -> Void = {}
}

/// Window-background dragging must not swallow the modal dismissal click.
/// The native hit region excludes the card, so its fields keep normal input.
private struct SettingsDismissalBackdrop: NSViewRepresentable {
    var panelWidth: CGFloat
    var floating: Bool
    var onDismiss: () -> Void

    func makeNSView(context: Context) -> DismissView {
        let view = DismissView()
        view.panelWidth = panelWidth
        view.floating = floating
        view.onDismiss = onDismiss
        return view
    }

    func updateNSView(_ view: DismissView, context: Context) {
        view.panelWidth = panelWidth
        view.floating = floating
        view.onDismiss = onDismiss
    }

    final class DismissView: NSView {
        var panelWidth: CGFloat = 0
        var floating = false
        var onDismiss: () -> Void = {}
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? {
            let local = convert(point, from: superview)
            let scale = floating ? BarScale.factor(windowWidth: bounds.width) : 1
            let barTop = (BuehneLayout.windowInset + BuehneLayout.controlHeight) * scale + 16
            if local.y <= barTop || local.y >= bounds.height - barTop { return nil }
            let inset = BuehneLayout.settingsInset
            let card = CGRect(x: bounds.width - inset - panelWidth, y: inset,
                              width: panelWidth, height: max(0, bounds.height - 2 * inset))
            if card.contains(local) { return nil }
            return super.hitTest(point)
        }
        override func mouseDown(with event: NSEvent) { onDismiss() }
    }
}
