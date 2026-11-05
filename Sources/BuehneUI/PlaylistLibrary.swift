import BuehneCore
import Foundation

struct PlaylistItem: Identifiable, Hashable, Sendable {
    var url: URL
    var id: String { url.path }
    var name: String { url.deletingPathExtension().lastPathComponent }
}

enum PlaylistLibrary {
    /// Videos from the chosen folders, two levels deep, sorted by name. Runs off the main thread.
    static func scan(folders: [String]) -> [PlaylistItem] {
        var items: [PlaylistItem] = []
        let manager = FileManager.default
        for path in folders {
            let root = URL(fileURLWithPath: path, isDirectory: true)
            guard let enumerator = manager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            for case let url as URL in enumerator {
                if enumerator.level > 3 { enumerator.skipDescendants(); continue }
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir { continue }
                if PlaylistPolicy.isVideo(extension: url.pathExtension) {
                    items.append(PlaylistItem(url: url))
                }
            }
        }
        return items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

@MainActor
final class PlaylistStore: ObservableObject {
    static let shared = PlaylistStore()
    @Published private(set) var items: [PlaylistItem] = []

    func refresh(folders: [String]) async {
        let found = await Task.detached { PlaylistLibrary.scan(folders: folders) }.value
        items = found
    }
}
