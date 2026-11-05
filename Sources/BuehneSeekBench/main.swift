import BuehneEngine
import Foundation

// Developer tool: plays a file silently, jumps around and reports how long the main thread was blocked.
// Usage: BuehneSeekBench /path/video.mkv 900 2400 1200 3000
setbuf(stdout, nil)
var args = Array(CommandLine.arguments.dropFirst())
if args.first == "--switch" {
    // Playlist behaviour: open one film after another, report how long the main thread stood still and when a frame appeared.
    args.removeFirst()
    let session = PlayerSession()
    var last = Date()
    var worst = 0.0
    Task { @MainActor in
        while true {
            worst = max(worst, Date().timeIntervalSince(last))
            last = Date()
            session.refresh()
            try? await Task.sleep(for: .milliseconds(8))
        }
    }
    for round in 0..<2 {
        for path in args {
            worst = 0; last = Date()
            let start = Date()
            let before = Date()
            await session.open(url: URL(fileURLWithPath: path))
            let openTook = Date().timeIntervalSince(before)
            session.setVolume(0)
            var frame = -1.0
            while Date().timeIntervalSince(start) < 6 {
                try await Task.sleep(for: .milliseconds(10))
                if frame < 0, session.presentedFrames > 0, session.snapshot.videoSize.isKnown { frame = Date().timeIntervalSince(start) }
                if frame > 0, Date().timeIntervalSince(start) > frame + 1.5 { break }
            }
            print(String(format: "round %d open=%.0fms firstPicture=%.2fs worstMainStall=%.0fms t=%.1f %@", round, openTook * 1000, frame, worst * 1000, session.snapshot.currentTime, String(path.suffix(28))))
        }
    }
    exit(0)
}
if args.first == "--session" {
    // Whole player logic: jump limit, stop at the end of the downloaded part. Prints what the viewer would get.
    args.removeFirst()
    let session = PlayerSession()
    await session.open(url: URL(fileURLWithPath: args[0]))
    session.setVolume(0)
    let tick = Timer(timeInterval: 0.008, repeats: true) { _ in MainActor.assumeIsolated { session.refresh() } }
    RunLoop.main.add(tick, forMode: .common)
    func report(_ label: String) {
        print(session.snapshot.error ?? "", label, "t=\(Int(session.snapshot.currentTime)) phase=\(session.snapshot.phase) allowed=\(session.streamAllowed.map { String(Int($0)) } ?? "none") notices=\(session.limitNotices) avsync=\(session.engineProperty("avsync"))")
    }
    try await Task.sleep(for: .seconds(4))
    report("opened")
    if args.count > 1, args[1] == "--watch" {
        // Plain viewing: report every jump of the clock that is not the normal forward march.
        let minutes = Double(args.count > 2 ? args[2] : "5") ?? 5
        if args.count > 3, let start = Double(args[3]) { session.seek(to: start); try await Task.sleep(for: .seconds(3)) }
        var last = session.snapshot.currentTime
        var lastAt = Date()
        let end = Date().addingTimeInterval(minutes * 60)
        while Date() < end {
            try await Task.sleep(for: .milliseconds(250))
            let now = session.snapshot.currentTime
            let expected = Date().timeIntervalSince(lastAt)
            if abs((now - last) - expected) > 1.5 { print(String(format: "JUMP %.1f -> %.1f in %.2fs", last, now, expected)) }
            last = now
            lastAt = Date()
        }
        report("end")
        exit(0)
    }
    for raw in args.dropFirst() {
        let wanted = Double(raw) ?? 0
        session.seek(to: wanted >= 0 ? wanted : (session.streamAllowed ?? 0) + wanted)
        if session.snapshot.phase != .playing { session.togglePlay() }
        try await Task.sleep(for: .seconds(3))
        report("  playing \(raw)")
        try await Task.sleep(for: .seconds(9))
        report("seek \(raw)")
    }
    exit(0)
}
guard let path = args.first else { print("usage: BuehneSeekBench file seconds..."); exit(2) }
let targets = args.dropFirst().compactMap(Double.init)
let engine = LibmpvEngine()
try await engine.open(URL(fileURLWithPath: path))
engine.setVolume(0)

var lastTick = Date()
var worstGap = 0.0
var worstCall = 0.0
var lastTracks = Date()
var seekAt: Date?
var seekTarget = 0.0
var framesAtSeek = 0
var firstFrame: Double?
var uiArrived: Double?
var index = 0
var phaseStart = Date()
var warmed = false

@MainActor func prop(_ name: String) -> String { engine.stringProperty(name) }

let timer = Timer(timeInterval: 0.008, repeats: true) { _ in
    MainActor.assumeIsolated {
        let now = Date()
        worstGap = max(worstGap, now.timeIntervalSince(lastTick))
        lastTick = now
        let start = Date()
        engine.render()
        if lastTracks.timeIntervalSinceNow < -0.5 { lastTracks = now; _ = engine.tracks() }
        let snap = engine.snapshot()
        worstCall = max(worstCall, Date().timeIntervalSince(start))
        if !warmed {
            if now.timeIntervalSince(phaseStart) > 5 {
                warmed = true
                print(String(format: "warm: t=%.1f frames=%d worstGap=%.0fms worstCall=%.0fms", snap.currentTime, engine.presentedFrames, worstGap * 1000, worstCall * 1000))
                phaseStart = now
            }
            return
        }
        if let at = seekAt {
            if firstFrame == nil, engine.presentedFrames > framesAtSeek + 2 { firstFrame = now.timeIntervalSince(at) }
            if now.timeIntervalSince(at) > 6 {
                print(String(format: "seek %5.0f -> t=%7.1f newFrame=%@ worstGap=%4.0fms worstCall=%4.0fms avsync=%@ drops=%@ vdrops=%@",
                    seekTarget, snap.currentTime, firstFrame.map { String(format: "%.2fs", $0) } ?? "NONE", worstGap * 1000, worstCall * 1000,
                    prop("avsync"), prop("frame-drop-count"), prop("decoder-frame-drop-count")))
                seekAt = nil
            }
            return
        }
        guard index < targets.count else { engine.close(); exit(0) }
        seekTarget = targets[index]; index += 1
        worstGap = 0; worstCall = 0; firstFrame = nil
        framesAtSeek = engine.presentedFrames
        seekAt = Date()
        engine.seek(to: seekTarget)
    }
}
RunLoop.main.add(timer, forMode: .common)
while true { try await Task.sleep(for: .seconds(3600)) }
