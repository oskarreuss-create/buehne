import AppKit
import BuehneCore
import BuehneEngine
import CoreServices
import Foundation

public enum FileIconResult: Equatable {
    case decorated
    case skipped(String)
    case failed(String)
}

/// Applies, removes, and watches branded Finder icons. The scan never runs on the main thread.
public enum FileIconApply {
    public static let enabledKey = "buehne.brandedFileIcons"
    public static let foldersKey = "buehne.iconFolders"

    public static func enabled(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: enabledKey) == nil { return true }
        return defaults.bool(forKey: enabledKey)
    }

    public static func folders(defaults: UserDefaults = .standard, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        if let stored = defaults.stringArray(forKey: foldersKey) {
            return stored.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath, isDirectory: true) }
        }
        return FileIconPolicy.defaultFolders(home: home)
    }

    public static func decorate(url: URL, defaults: UserDefaults = .standard, cache: FileIconCache = .shared, respectSetting: Bool = true) -> FileIconResult {
        let ext = url.pathExtension
        let readable = FileManager.default.isReadableFile(atPath: url.path)
        let dataless = isDataless(url)
        let current = token(for: url)
        if let reason = FileIconPolicy.decide(
            extension: ext,
            readable: readable,
            dataless: dataless,
            enabled: respectSetting ? enabled(defaults: defaults) : true,
            cachedToken: cache.token(for: url.path),
            currentToken: current
        ) {
            return .skipped(reason)
        }
        guard let frame = try? VideoFrameGrab.cgImage(for: url),
              let image = FileIconRenderer.nsImage(frame: frame, extension: ext) else {
            return .failed("frame")
        }
        let ok = NSWorkspace.shared.setIcon(image, forFile: url.path, options: [])
        guard ok else { return .failed("setIcon") }
        cache.store(path: url.path, token: token(for: url))
        return .decorated
    }

    public static func remove(url: URL, cache: FileIconCache = .shared) -> Bool {
        let ok = NSWorkspace.shared.setIcon(nil, forFile: url.path, options: [])
        cache.remove(path: url.path)
        return ok
    }

    public static func removeAll(cache: FileIconCache = .shared) {
        for path in cache.paths() {
            _ = NSWorkspace.shared.setIcon(nil, forFile: path, options: [])
        }
        cache.removeAll()
    }

    public static func decorateAndPrint(path: String) -> Int32 {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            var failed = 0
            if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for case let file as URL in enumerator {
                    switch decorate(url: file) {
                    case .failed: failed += 1
                    default: break
                    }
                }
            }
            print("BUEHNE_DECORATE dir=1 failed=\(failed)")
            return failed == 0 ? 0 : 2
        }
        let result = decorate(url: url)
        switch result {
        case .decorated:
            print("BUEHNE_DECORATE ok=1 path=\(url.path)")
            return 0
        case .skipped(let reason):
            print("BUEHNE_DECORATE ok=0 skipped=\(reason)")
            return reason == "disabled" ? 0 : 2
        case .failed(let reason):
            fputs("BUEHNE_DECORATE ok=0 failed=\(reason)\n", stderr)
            return 2
        }
    }

    static func isDataless(_ url: URL) -> Bool {
        let keys: Set<URLResourceKey> = [.ubiquitousItemDownloadingStatusKey, .fileSizeKey, .totalFileAllocatedSizeKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return false }
        let notDownloaded = values.ubiquitousItemDownloadingStatus == .notDownloaded
        return FileIconPolicy.isDataless(
            downloadingStatusNotDownloaded: notDownloaded,
            allocatedBytes: values.totalFileAllocatedSize,
            logicalBytes: values.fileSize.map { Int($0) }
        )
    }

    static func token(for url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let mtime = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
        let size = Int(values?.fileSize ?? 0)
        return FileIconPolicy.cacheToken(mtime: mtime, size: size)
    }
}

public final class FileIconCache: @unchecked Sendable {
    public static let shared = FileIconCache()
    private let url: URL
    private let lock = NSLock()
    private var entries: [String: String]

    public init(url: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = base.appendingPathComponent("Buehne", isDirectory: true)
        self.url = url ?? folder.appendingPathComponent(FileIconPolicy.cacheName)
        entries = (try? JSONDecoder().decode([String: String].self, from: Data(contentsOf: self.url))) ?? [:]
    }

    public func token(for path: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return entries[path]
    }

    public func store(path: String, token: String) {
        lock.lock()
        entries[path] = token
        let snapshot = entries
        lock.unlock()
        write(snapshot)
    }

    public func remove(path: String) {
        lock.lock()
        entries.removeValue(forKey: path)
        let snapshot = entries
        lock.unlock()
        write(snapshot)
    }

    public func paths() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return Array(entries.keys)
    }

    public func removeAll() {
        lock.lock()
        entries = [:]
        lock.unlock()
        write([:])
    }

    private func write(_ snapshot: [String: String]) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

/// FSEvents on the chosen folders, four decorations at a time, off the main thread.
public final class FileIconService: @unchecked Sendable {
    public static let shared = FileIconService()
    private let work = DispatchQueue(label: "ch.oskarreus.buehne.fileicons", attributes: .concurrent)
    private let gate = DispatchSemaphore(value: FileIconPolicy.concurrency)
    private var stream: FSEventStreamRef?
    private let box = WatchBox()

    public func startIfEnabled() {
        guard !Self.runningTests else { return }
        guard FileIconApply.enabled() else { return }
        let folders = FileIconApply.folders().map(\.path)
        scan(folders)
        watch(folders)
    }

    public func restart() {
        stop()
        startIfEnabled()
    }

    public func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }

    public func removeAll() {
        work.async { FileIconApply.removeAll() }
    }

    private func scan(_ folders: [String]) {
        for folder in folders {
            guard FileManager.default.fileExists(atPath: folder) else { continue }
            guard let enumerator = FileManager.default.enumerator(
                at: URL(fileURLWithPath: folder, isDirectory: true),
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            for case let file as URL in enumerator {
                enqueue(file)
            }
        }
    }

    private func watch(_ folders: [String]) {
        let existing = folders.filter { FileManager.default.fileExists(atPath: $0) }
        guard !existing.isEmpty else { return }
        box.onPath = { [weak self] path in self?.enqueue(URL(fileURLWithPath: path)) }
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(box).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        guard let stream = FSEventStreamCreate(
            nil,
            { _, info, count, paths, _, _ in
                guard let info else { return }
                let box = Unmanaged<WatchBox>.fromOpaque(info).takeUnretainedValue()
                let list = unsafeBitCast(paths, to: NSArray.self)
                for index in 0..<count {
                    if let path = list[index] as? String { box.onPath(path) }
                }
            },
            &context,
            existing as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            flags
        ) else { return }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, work)
        FSEventStreamStart(stream)
    }

    private func enqueue(_ url: URL) {
        work.async { [gate] in
            gate.wait()
            defer { gate.signal() }
            _ = FileIconApply.decorate(url: url)
        }
    }

    private static var runningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

private final class WatchBox: @unchecked Sendable {
    var onPath: (String) -> Void = { _ in }
}
