import AppKit
import BuehneCore
import BuehneEngine
import BuehneUI
import SwiftUI

@main
enum BuehneSelfCheckMain {
    static func main() {
        if CommandLine.arguments.contains("--input") {
            let report = InputProbe.report()
            print(report)
            exit(report.contains("FAIL") ? 1 : 0)
        }
        if CommandLine.arguments.contains("--context-menu") {
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)
            DispatchQueue.main.async {
                let report = ContextMenuProbe.report()
                print(report)
                exit(report.contains("FAIL") ? 1 : 0)
            }
            app.run()
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        Task { @MainActor in
            await SelfCheck.run()
        }
        app.run()
    }
}

@MainActor
enum SelfCheck {
    static func run() async {
        if CommandLine.arguments.contains("--apply-lag") {
            await applyLag()
            return
        }
        guard let url = OpenContract.mediaURL(from: CommandLine.arguments) else {
            fputs("usage: BuehneSelfCheck <file.mp4>\n", stderr)
            exit(2)
        }
        let germanSettings = L10n.text(.settings, language: "de")
        if germanSettings != "Einstellungen" {
            fputs("catalog miss settings.de=\(germanSettings)\n", stderr)
            exit(1)
        }
        if BuehneTheme.preferredScheme("auto") != nil || BuehneTheme.contentWhite(isLight: false, activity: .inactive) != 0.08 {
            fputs("theme tokens drifted\n", stderr)
            exit(1)
        }
        let session = PlayerSession(store: MemoryPositionStore())
        session.setVolume(0)
        let defaults = UserDefaults(suiteName: "buehne.selfcheck.\(UUID().uuidString)") ?? .standard
        let settings = BuehneSettings(defaults: defaults)
        let root = PlayerRootView(session: session, settings: settings, launchURL: url, keepOffscreen: true)
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(x: 0, y: 0, width: 960, height: 540)
        let window = NSWindow(
            contentRect: NSRect(x: -32000, y: -32000, width: 960, height: 540),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = OpenContract.displayName
        window.contentView = host
        window.isReleasedWhenClosed = false
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.setFrameOrigin(NSPoint(x: -32000, y: -32000))
        window.orderFrontRegardless()

        let pixels = BuehneChromeProof.controlBarOpaquePixels()
        let longFile = url.lastPathComponent.contains("2160p")
        let deadline = Date().addingTimeInterval(longFile ? 90 : 20)
        var probeStart: (Date, Int, Int, Double)?
        while Date() < deadline {
            session.refresh()
            let snap = session.snapshot
            if snap.phase == .failed {
                print("BUEHNE_PLAYBACK_FAIL error=\(snap.error ?? "unknown") signal=\(session.hdrReport)")
                exit(1)
            }
            if probeStart == nil, snap.phase == .playing, snap.currentTime > 0.2, session.presentedFrames > 0 {
                probeStart = (Date(), session.presentedFrames, dropCount(session.playbackProbe()), cpuSeconds())
            }
            let opened = window.contentView === host
            let expected = EngineRouter.route(url).kind
            let wallReady = probeStart.map { Date().timeIntervalSince($0.0) >= 10 } ?? false
            let ready = longFile ? (snap.currentTime >= 10 && wallReady) : snap.currentTime > 0.05
            if opened, snap.phase == .playing, ready, snap.engine == expected {
                if pixels < 20000 {
                    fputs("control bar did not draw (\(pixels) pixels)\n", stderr)
                    exit(1)
                }
                settings.theme = "light"
                let lightOK = settings.preferredScheme == .light
                settings.theme = "dark"
                let darkOK = settings.preferredScheme == .dark
                if !lightOK || !darkOK {
                    fputs("theme probe failed light=\(lightOK) dark=\(darkOK)\n", stderr)
                    exit(1)
                }
                let signal = session.hdrReport
                if longFile {
                    let hdr = url.lastPathComponent.contains("HDR")
                    let gammaOK = hdr ? (signal.contains("gamma=pq") || signal.contains("gamma=hlg") || signal.contains("gamma=arib-std-b67")) : !signal.contains("gamma=pq")
                    let metalOK = signal.contains("rgba16Float") && signal.contains("edr=1") && signal.contains("ExtendedLinearDisplayP3")
                    if !gammaOK || !metalOK {
                        fputs("signal mismatch hdr=\(hdr) metal=\(metalOK) \(signal)\n", stderr)
                        exit(1)
                    }
                }
                let probe = session.playbackProbe()
                let fpsLine = fpsLine(start: probeStart, probe: probe)
                window.alphaValue = 0
                window.setFrameOrigin(NSPoint(x: -32000, y: -32000))
                try? await Task.sleep(for: .milliseconds(200))
                let shot = screenshot(window, name: url.deletingPathExtension().lastPathComponent)
                let headroom = NSScreen.main?.maximumExtendedDynamicRangeColorComponentValue ?? 0
                print("BUEHNE_WINDOW_ORDERED=1")
                print("BUEHNE_WINDOW_VISIBLE=\(window.isVisible ? 1 : 0)")
                print("BUEHNE_WINDOW_ALPHA=\(window.alphaValue)")
                print("BUEHNE_WINDOW_ORIGIN=\(Int(window.frame.origin.x)),\(Int(window.frame.origin.y))")
                print("BUEHNE_CONTROL_BAR_PIXELS=\(pixels)")
                print("BUEHNE_THEME_LIGHT=1")
                print("BUEHNE_THEME_DARK=1")
                print("BUEHNE_HEADROOM=\(headroom)")
                print("BUEHNE_SIGNAL \(signal)")
                print("BUEHNE_FPS \(fpsLine) \(probe)")
                print("BUEHNE_SCREENSHOT=\(shot)")
                print("BUEHNE_PLAYBACK_OK time=\(snap.currentTime) engine=\(snap.engine?.rawValue ?? "none") size=\(Int(snap.videoSize.width))x\(Int(snap.videoSize.height))")
                probeTracks(session, url: url)
                let hwOK = probe.contains("hwdec=videotoolbox") && !probe.contains("copy")
                if longFile, let fps = fpsValue(fpsLine), fps < 23.9 || dropDelta(fpsLine) > 5 || !hwOK {
                    fputs("fps gate failed \(fpsLine) \(probe)\n", stderr)
                    exit(1)
}
                exit(0)
            }
            try? await Task.sleep(for: .milliseconds(longFile ? 1 : 100))
        }
        let snap = session.snapshot
        print("BUEHNE_PLAYBACK_FAIL timeout phase=\(snap.phase.rawValue) time=\(snap.currentTime) error=\(snap.error ?? "")")
        exit(1)
    }

    private static func screenshot(_ window: NSWindow, name: String) -> String {
        let safe = name.replacingOccurrences(of: " ", with: "-")
        let path = "build/buehne-proof-\(safe).png"
        let dir = URL(fileURLWithPath: "build", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let view = window.contentView else { return "missing-view" }
        let rect = view.bounds
        guard let rep = view.bitmapImageRepForCachingDisplay(in: rect) else { return "missing-rep" }
        view.cacheDisplay(in: rect, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return "missing-png" }
        let url = URL(fileURLWithPath: path)
        try? data.write(to: url)
        return "\(path) bytes=\(data.count)"
    }
    private static func cpuSeconds() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        let user = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000
        let system = Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
        return user + system
    }

    private static func dropCount(_ probe: String) -> Int {
        guard let part = probe.split(separator: " ").first(where: { $0.hasPrefix("dropped=") }) else { return 0 }
        return Int(part.dropFirst("dropped=".count)) ?? 0
    }

    private static func fpsLine(start: (Date, Int, Int, Double)?, probe: String) -> String {
        guard let start else { return "fps=0 frames=0 wall=0 cpu=0 dropDelta=0" }
        let wall = max(0.001, Date().timeIntervalSince(start.0))
        let frames = max(0, presentedNow(probe) - start.1)
        let fps = Double(frames) / wall
        let cpu = (cpuSeconds() - start.3) / wall * 100
        let drops = max(0, dropCount(probe) - start.2)
        return String(format: "fps=%.2f frames=%d wall=%.2f cpu=%.0f dropDelta=%d", fps, frames, wall, cpu, drops)
    }

    private static func presentedNow(_ probe: String) -> Int {
        guard let part = probe.split(separator: " ").first(where: { $0.hasPrefix("presented=") }) else { return 0 }
        return Int(part.dropFirst("presented=".count)) ?? 0
    }

    private static func fpsValue(_ line: String) -> Double? {
        guard let part = line.split(separator: " ").first(where: { $0.hasPrefix("fps=") }) else { return nil }
        return Double(part.dropFirst("fps=".count))
    }
    private static func probeTracks(_ session: PlayerSession, url: URL) {
        session.refresh()
        let listed = session.tracks
        let audio = listed.audio.map { "\($0.id):\($0.name):sel=\($0.selected ? 1 : 0)" }.joined(separator: ",")
        let subs = listed.subtitles.map { "\($0.id):\($0.name):sel=\($0.selected ? 1 : 0)" }.joined(separator: ",")
        print("BUEHNE_TRACKS audio=\(listed.audio.count) sub=\(listed.subtitles.count) \(audio) | \(subs)")
        print("BUEHNE_SUB_VIS \(session.engineProperty("sub-visibility")) osd=\(session.engineProperty("osd-level"))")
        if listed.audio.count >= 2 {
            let other = listed.audio.first { !$0.selected } ?? listed.audio[1]
            session.selectAudio(id: other.id)
            session.refresh()
            print("BUEHNE_AUDIO aid=\(session.engineProperty("aid")) selected=\(session.tracks.audio.first { $0.selected }?.id ?? "none")")
        } else if let only = listed.audio.first {
            session.selectAudio(id: only.id)
            print("BUEHNE_AUDIO aid=\(session.engineProperty("aid")) selected=\(only.id)")
        } else {
            print("BUEHNE_AUDIO none")
        }
        if let sub = listed.subtitles.first(where: { !$0.selected }) ?? listed.subtitles.first {
            session.selectSubtitle(id: sub.id)
            session.refresh()
            print("BUEHNE_SUB_ON sid=\(session.engineProperty("sid"))")
            session.selectSubtitle(id: nil)
            session.refresh()
            print("BUEHNE_SUB_OFF sid=\(session.engineProperty("sid"))")
        } else {
            print("BUEHNE_SUB_NONE")
        }
        if url.lastPathComponent.contains("HDR"), listed.audio.isEmpty {
            fputs("track list empty\n", stderr)
            exit(1)
        }
    }

    private static func dropDelta(_ line: String) -> Int {
        guard let part = line.split(separator: " ").first(where: { $0.hasPrefix("dropDelta=") }) else { return 0 }
        return Int(part.dropFirst("dropDelta=".count)) ?? 0
    }
    static func applyLag() async {
        var files = [URL(fileURLWithPath: "/tmp/buehne-selfcheck.mp4")]
        if FileManager.default.fileExists(atPath: "/tmp/buehne-selfcheck.mkv") {
            files.append(URL(fileURLWithPath: "/tmp/buehne-selfcheck.mkv"))
        }
        var probed = 0
        for url in files where FileManager.default.fileExists(atPath: url.path) {
            let session = PlayerSession(store: MemoryPositionStore())
            await session.open(url: url)
            for _ in 0..<100 {
                if session.snapshot.engine != nil, session.snapshot.phase != .opening { break }
                try? await Task.sleep(for: .milliseconds(20))
            }
            if session.snapshot.phase == .failed || session.snapshot.engine == nil {
                fputs("BUEHNE_APPLY_FAIL open \(url.lastPathComponent) \(session.snapshot.error ?? session.snapshot.phase.rawValue)", stderr)
                exit(1)
            }
            if session.snapshot.phase != .playing { session.togglePlay() }
            var lastVolume = 0.0
            for index in 0..<50 {
                lastVolume = Double(index) / 100.0
                session.setVolume(lastVolume)
            }
            var lastRate = 1.0
            for index in 0..<50 {
                lastRate = RateRange.clamp(0.5 + Double(index) * 0.07)
                session.setPreferredRate(lastRate)
            }
            let expectedVolume = lastVolume
            let expectedRate = lastRate
            let engine = session.snapshot.engine?.rawValue ?? "none"
            let matched: Bool = await withCheckedContinuation { continuation in
                DispatchQueue.main.async {
                    let volume = session.readAppliedVolume()
                    let rate = session.readAppliedRate()
                    let ok = abs(volume - expectedVolume) < 0.03 && abs(rate - expectedRate) < 0.05
                    print("BUEHNE_APPLY engine=\(engine) volume=\(volume) expectedVolume=\(expectedVolume) rate=\(rate) expectedRate=\(expectedRate) ok=\(ok ? 1 : 0)")
                    continuation.resume(returning: ok)
                }
            }
            if !matched {
                fputs("BUEHNE_APPLY_FAIL \(engine)", stderr)
                exit(1)
            }
            probed += 1
        }
        if probed == 0 {
            fputs("BUEHNE_APPLY_FAIL no sample", stderr)
            exit(1)
        }
        print("BUEHNE_APPLY_OK")
        exit(0)
    }

}
