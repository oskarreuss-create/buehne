import BuehneEngine
import Foundation

// Developer tool: plays a file silently, jumps around and reports how long the main thread was blocked.
// Usage: BuehneSeekBench /path/video.mkv 900 2400 1200 3000
var args = Array(CommandLine.arguments.dropFirst())
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
