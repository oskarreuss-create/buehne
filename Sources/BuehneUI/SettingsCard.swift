import AppKit
import BuehneCore
import BuehneEngine
import SwiftUI

struct SettingsCard: View {
    @ObservedObject var session: PlayerSession
    @ObservedObject var settings: BuehneSettings
    var isLight: Bool
    var onClose: () -> Void
    @State private var playlistExpanded = false
    @ObservedObject private var playlistStore = PlaylistStore.shared

    private var panel: some View {
        GlassPanel(radius: BuehneLayout.cornerRadius, opacity: settings.glassOpacity, isLight: isLight, menu: true) {
            VStack(spacing: 0) {
                header
                Divider().padding(.horizontal, BuehneLayout.cardPadding)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        companionSection
                        appearanceSection
                        playlistSection
                        videoSection
                        audioSection
                        subtitleSection
                    }
                    .padding(BuehneLayout.cardPadding)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .font(BuehneFont.regular(14))
        .foregroundStyle(isLight ? Color.black : Color.white)
        .controlSize(.small)
        .accessibilityIdentifier("buehne.control.settings")
    }

    var body: some View {
        panel
        .onChange(of: settings.theme) { _, _ in settings.persist() }
        .onChange(of: settings.glassOpacity) { _, _ in settings.persist() }
        .onChange(of: settings.barTransparency) { _, _ in settings.persist() }
        .onChange(of: settings.onScreenMessages) { _, _ in settings.persist() }
        .onChange(of: settings.onScreenMenu) { _, _ in settings.persist() }
        .onChange(of: settings.sidebar) { _, _ in settings.persist() }
        .onChange(of: settings.videoFillsWindow) { _, _ in settings.persist() }
        .onChange(of: settings.lockAspect) { _, _ in settings.persist() }
        .onChange(of: settings.aspect) { _, _ in settings.persist() }
        .onChange(of: settings.crop) { _, _ in settings.persist() }
        .onChange(of: settings.rotation) { _, _ in settings.persist() }
        .onChange(of: settings.detectBars) { _, _ in settings.persist() }
        .onChange(of: settings.playlistFolders) { _, _ in settings.persist() }
        .onChange(of: settings.playlistOnBar) { _, _ in settings.persist() }
            .onChange(of: settings.language) { _, _ in settings.persist() }
            .onChange(of: settings.brandedFileIcons) { _, _ in
                settings.persist()
                FileIconService.shared.restart()
            }
            .onChange(of: settings.iconFolders) { _, _ in
                settings.persist()
                FileIconService.shared.restart()
            }
    }

    private var appearanceSection: some View {
        section(.layout, label: settings.text(.theme)) {
            menuRow(.theme, selection: $settings.theme, options: [
                ("dark", settings.text(.dark)),
                ("light", settings.text(.light)),
                ("auto", settings.text(.automatic)),
            ])
            menuRow(.language, selection: $settings.language, options: [
                ("en", "English"),
                ("de", "Deutsch"),
                ("fr", "Français"),
                ("it", "Italiano"),
                ("ru", "Русский"),
                ("es", "Español"),
            ])
            HStack(spacing: 8) {
                BuehneIcon(.liquidGlass, size: 18)
                Text(settings.text(.liquidGlass))
            }
            .padding(.top, 8)
            toggleRow(.onScreenMessages, isOn: $settings.onScreenMessages)
            toggleRow(.onScreenMenu, isOn: $settings.onScreenMenu)
            toggleRow(.sidebar, isOn: $settings.sidebar)
            sliderRow(.opacity, value: $settings.glassOpacity, range: 0...100, percent: true, step: 1)
            sliderRow(.barTransparency, value: $settings.barTransparency, range: 0...100, percent: true, step: 1)
        }
    }

    private var playlistSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet").frame(width: 24, height: 24)
                Text(settings.text(.playlist)).font(BuehneFont.regular(14))
                Spacer(minLength: 0)
                Button(action: pickPlaylistFolder) {
                    Image(systemName: "folder").font(.system(size: 15))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(settings.text(.addIconFolder))
            }
            if let folder = settings.playlistFolders.first {
                Text(folder).font(BuehneFont.regular(11)).lineLimit(1).truncationMode(.middle).opacity(0.6)
                Button {
                    playlistExpanded.toggle()
                } label: {
                    HStack {
                        Text(settings.text(.playlist))
                        Spacer(minLength: 0)
                        Image(systemName: playlistExpanded ? "chevron.up" : "chevron.down")
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if playlistExpanded {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(playlistStore.items) { item in
                            Button {
                                Task { await session.open(url: item.url) }
                            } label: {
                                Text(item.name)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                toggleRow(.playlistOnBar, isOn: $settings.playlistOnBar)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static let companionURL = URL(string: "https://github.com/oskarreuss-create/strom/releases")!

    private var companionSection: some View {
        Button {
            NSWorkspace.shared.open(Self.companionURL)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                if let url = Bundle.module.url(forResource: "StromIcon", withExtension: "png"),
                   let image = NSImage(contentsOf: url) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.text(.companionTitle)).font(BuehneFont.bold(14))
                    Text(settings.text(.companionBody))
                        .font(BuehneFont.regular(12))
                        .opacity(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 4) {
                        Text(settings.text(.companionLink))
                        Image(systemName: "arrow.up.right")
                    }
                    .font(BuehneFont.regular(13))
                    .foregroundStyle(Color(nsColor: .systemBlue))
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill((isLight ? Color.black : Color.white).opacity(0.06)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("buehne.companion.link")
    }

    private func pickPlaylistFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            settings.playlistFolders = [url.path]
        }
    }

    private var videoSection: some View {
        section(.video, label: settings.text(.openVideo)) {
            toggleRow(.videoFillsWindow, isOn: $settings.videoFillsWindow)
            toggleRow(.lockAspect, isOn: $settings.lockAspect)
            menuRow(.aspect, selection: $settings.aspect, options: aspectOptions)
            menuRow(.crop, selection: $settings.crop, options: [
                ("none", settings.text(.none)),
                ("4:3", "4:3"), ("16:9", "16:9"), ("16:10", "16:10"),
                ("21:9", "21:9"), ("5:4", "5:4"), ("1:1", "1:1"),
            ])
            rotationRow
            sliderRow(.speed, value: Binding(get: { session.preferredRate }, set: { session.setPreferredRate(RateRange.stepped($0)) }), range: RateRange.minimum...RateRange.maximum, percent: false, editable: true, step: RateRange.step, reset: { session.setPreferredRate(1) })
            toggleRow(.detectBars, isOn: $settings.detectBars)
        }
    }

    private var audioSection: some View {
        section(.audio, label: settings.text(.audioTrack)) {
            trackMenu(.audioTrack, tracks: session.tracks.audio, selection: .constant(session.tracks.audio.first { $0.selected }?.id ?? ""), onSelect: { session.selectAudio(id: $0.isEmpty ? nil : $0) })
        }
    }

    private var subtitleSection: some View {
        section(.subtitles, label: settings.text(.primarySubtitles)) {
            trackMenu(.primarySubtitles, tracks: session.tracks.subtitles, selection: .constant(session.tracks.subtitles.first { $0.selected }?.id ?? ""), onOff: { turnSubtitlesOff(.primary) }, onSelect: { session.selectSubtitle(id: $0.isEmpty ? nil : $0) })
            trackMenu(.secondarySubtitles, tracks: session.tracks.subtitles, selection: Binding(
                get: { session.secondarySubtitleID ?? "" },
                set: { _ = session.selectSecondarySubtitle(id: $0.isEmpty ? nil : $0) }
            ), onOff: { turnSubtitlesOff(.secondary) }, onSelect: { _ = session.selectSecondarySubtitle(id: $0.isEmpty ? nil : $0) })
            if session.secondarySubtitleID != nil && !session.secondarySubtitleRendered {
                Text(settings.text(.secondaryNotRendered))
                    .font(BuehneFont.regular(12))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var header: some View {
        HStack {
            Text(settings.text(.settings))
                .font(BuehneFont.bold(18))
            Spacer()
            Button(settings.text(.done), action: onClose)
                .buttonStyle(.plain)
                .font(BuehneFont.bold(14))
                .padding(.vertical, 8)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel(settings.text(.done))
                .help(settings.text(.done))
        }
        .padding(.horizontal, BuehneLayout.cardPadding)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var aspectOptions: [(String, String)] {
        [("fit", settings.text(.fit)), ("4:3", "4:3"), ("16:9", "16:9"),
         ("16:10", "16:10"), ("21:9", "21:9"), ("5:4", "5:4"), ("1:1", "1:1")]
    }

    private func section<Content: View>(_ icon: BuehneGlyph, label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BuehneIcon(icon, size: 16)
                .foregroundStyle(.primary)
                .frame(width: 24, height: 24)
                .dockHover()
                .accessibilityLabel(label)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggleRow(_ key: L10nKey, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 16) {
            BuehneIconLabel(key: key, text: settings.text(key))
            Spacer(minLength: 0)
            Toggle(settings.text(key), isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color(nsColor: .systemBlue))
        }
        .frame(minHeight: BuehneLayout.rowHeight)
    }

    private func sliderRow(_ key: L10nKey, value: Binding<Double>, range: ClosedRange<Double>, percent: Bool, editable: Bool = false, step: Double? = nil, reset: (() -> Void)? = nil) -> some View {
        HStack(spacing: 12) {
            BuehneIconLabel(key: key, text: settings.text(key))
                .frame(width: 128, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if let reset {
                Button("1×", action: reset)
                    .buttonStyle(.plain)
                    .font(BuehneFont.regular(12))
                    .accessibilityLabel("1×")
            }
            Group {
                Slider(value: Binding(
                    get: { value.wrappedValue },
                    set: { raw in
                        if let step { value.wrappedValue = (raw / step).rounded() * step } else { value.wrappedValue = raw }
                    }
                ), in: range)
                .tint(Color(nsColor: .systemBlue))
            }
                .accessibilityLabel(settings.text(key))
            if editable {
                TextField(settings.text(key), value: Binding(
                    get: { value.wrappedValue },
                    set: { if $0.isFinite { value.wrappedValue = min(range.upperBound, max(range.lowerBound, $0)) } }
                ), format: .number.precision(.fractionLength(2)))
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 56)
                    .accessibilityLabel(settings.text(key))
            } else {
                Text(percent ? GlassAppearance.percentLabel(value.wrappedValue) : String(format: "%.2f", value.wrappedValue))
                    .font(BuehneFont.regular(12))
                    .monospacedDigit()
                    .frame(width: 56, alignment: .trailing)
            }
        }
        .frame(minHeight: BuehneLayout.rowHeight)
    }

    private func menuRow(_ key: L10nKey, selection: Binding<String>, options: [(String, String)]) -> some View {
        HStack(spacing: 16) {
            BuehneIconLabel(key: key, text: settings.text(key))
            Spacer(minLength: 0)
            Picker(settings.text(key), selection: selection) {
                ForEach(options, id: \.0) { option in
                    Text(option.1).tag(option.0)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(isLight ? Color.black : Color.white)
            .foregroundStyle(isLight ? Color.black : Color.white)
            .fixedSize()
            .frame(width: 150, alignment: .trailing)
        }
        .frame(minHeight: BuehneLayout.rowHeight)
    }

    private var rotationRow: some View {
        HStack(spacing: 16) {
            BuehneIconLabel(key: .rotation, text: settings.text(.rotation))
            Spacer(minLength: 0)
            Picker(settings.text(.rotation), selection: $settings.rotation) {
                Text("0°").tag(0)
                Text("90°").tag(90)
                Text("180°").tag(180)
                Text("270°").tag(270)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(isLight ? Color.black : Color.white)
            .foregroundStyle(isLight ? Color.black : Color.white)
            .fixedSize()
            .frame(width: 150, alignment: .trailing)
        }
        .frame(minHeight: BuehneLayout.rowHeight)
    }

    private func addIconFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if !settings.iconFolders.contains(url.path) { settings.iconFolders.append(url.path) }
    }

    private func turnSubtitlesOff(_ which: SubtitleRow) {
        let primaryOn = session.tracks.subtitles.contains { $0.selected }
        let secondaryOn = session.secondarySubtitleID != nil
        let next = SubtitleOffRule.afterOff(primaryOn: primaryOn, secondaryOn: secondaryOn, which: which)
        if !next.primary { session.selectSubtitle(id: nil) }
        if !next.secondary { _ = session.selectSecondarySubtitle(id: nil) }
    }

    private func trackMenu(_ key: L10nKey, tracks: [MediaTrack], selection: Binding<String>, onOff: @escaping @MainActor () -> Void = {}, onSelect: @escaping @MainActor (String) -> Void = { _ in }) -> some View {
        HStack(spacing: 8) {
            BuehneIconLabel(key: key, text: settings.text(key))
            Spacer(minLength: 0)
            Picker(settings.text(key), selection: Binding(get: { selection.wrappedValue }, set: { id in
                selection.wrappedValue = id
                onSelect(id)
            })) {
                Text(settings.text(.none)).tag("")
                ForEach(tracks) { track in
                    Text(track.name).tag(track.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(isLight ? Color.black : Color.white)
            .foregroundStyle(isLight ? Color.black : Color.white)
            .frame(maxWidth: 140)
            Button(settings.text(.none), action: onOff)
                .buttonStyle(.plain)
                .font(BuehneFont.regular(11))
                .dockHover()
                .accessibilityLabel(settings.text(.none))
        }
        .frame(minHeight: BuehneLayout.rowHeight)
    }
}
