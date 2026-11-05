import BuehneCore
import Testing

private let sample = """
[{"id":1,"type":"video","lang":"","title":"","codec":"hevc","selected":true},{"id":1,"type":"audio","lang":"eng","title":"English","codec":"eac3","selected":true},{"id":2,"type":"audio","lang":"deu","title":"","codec":"aac","selected":false},{"id":3,"type":"sub","lang":"eng","title":"SDH","codec":"ass","selected":false},{"id":4,"type":"sub","lang":"rus","title":"","codec":"subrip","selected":true}]
"""

@Test func trackListParsesAudioAndSubtitles() {
    let tracks = TrackListParser.parse(sample)
    #expect(tracks.audio.count == 2)
    #expect(tracks.subtitles.count == 2)
    #expect(tracks.audio[0].id == "a1")
    #expect(tracks.audio[0].selected)
    #expect(tracks.audio[0].lang == "eng")
    #expect(tracks.audio[0].codec == "eac3")
    #expect(tracks.audio[0].name.contains("English"))
    #expect(tracks.audio[1].id == "a2")
    #expect(!tracks.audio[1].selected)
    #expect(tracks.subtitles[0].id == "s3")
    #expect(tracks.subtitles[0].codec == "ass")
    #expect(!tracks.subtitles[0].selected)
    #expect(tracks.subtitles[1].selected)
    #expect(tracks.subtitles[1].mpvID == 4)
}

@Test func trackListPropertyValueUsesNoForEmpty() {
    #expect(TrackListParser.propertyValue(for: nil) == "no")
    #expect(TrackListParser.propertyValue(for: "") == "no")
    #expect(TrackListParser.propertyValue(for: "s3") == "3")
    #expect(TrackListParser.propertyValue(for: "a12") == "12")
    #expect(TrackListParser.parse("not json").audio.isEmpty)
}
