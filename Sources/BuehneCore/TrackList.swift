import Foundation

/// Parses an mpv `track-list` JSON array. Video entries are ignored.
public enum TrackListParser {
    public static func parse(_ json: String) -> MediaTracks {
        guard let data = json.data(using: .utf8),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return .empty
        }
        var audio: [MediaTrack] = []
        var subtitles: [MediaTrack] = []
        for row in rows {
            let type = text(row["type"])
            let kind: TrackKind
            switch type {
            case "audio": kind = .audio
            case "sub", "subtitle": kind = .subtitle
            default: continue
            }
            let mpvID = intValue(row["id"])
            guard mpvID > 0 else { continue }
            let lang = text(row["lang"])
            let title = text(row["title"])
            let codec = text(row["codec"])
            let track = MediaTrack(
                id: (kind == .audio ? "a" : "s") + String(mpvID),
                name: displayName(title: title, lang: lang, codec: codec, mpvID: mpvID),
                kind: kind,
                lang: lang,
                title: title,
                codec: codec,
                selected: flag(row["selected"]),
                mpvID: mpvID
            )
            if kind == .audio { audio.append(track) } else { subtitles.append(track) }
        }
        return MediaTracks(audio: audio, subtitles: subtitles)
    }

    /// `nil` or an empty id becomes mpv's `no`. `a2` and `s3` become the numeric id.
    public static func propertyValue(for id: String?) -> String {
        guard let id, !id.isEmpty else { return "no" }
        let digits = id.filter(\.isNumber)
        return digits.isEmpty ? "no" : digits
    }

    private static func displayName(title: String, lang: String, codec: String, mpvID: Int) -> String {
        let head: String
        if !title.isEmpty, !lang.isEmpty { head = "\(title) (\(lang))" }
        else if !title.isEmpty { head = title }
        else if !lang.isEmpty { head = lang }
        else { head = "Track \(mpvID)" }
        return codec.isEmpty ? head : "\(head) · \(codec)"
    }

    private static func text(_ value: Any?) -> String {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return ""
    }

    private static func intValue(_ value: Any?) -> Int {
        if let number = value as? NSNumber { return number.intValue }
        if let text = value as? String { return Int(text) ?? 0 }
        return 0
    }

    private static func flag(_ value: Any?) -> Bool {
        if let flag = value as? Bool { return flag }
        if let number = value as? NSNumber { return number.intValue != 0 }
        if let text = value as? String { return text == "yes" || text == "true" || text == "1" }
        return false
    }
}
