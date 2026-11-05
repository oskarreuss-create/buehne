import BuehneCore
import Testing

@Test func aspectOverrideChangesTheDisplayRatio() {
    let native = PictureLayout.displayAspect(codedWidth: 1920, codedHeight: 1080, aspect: "fit", crop: "none", rotation: 0)
    #expect(abs(native - 16.0 / 9.0) < 0.001)
    let forced = PictureLayout.displayAspect(codedWidth: 1920, codedHeight: 1080, aspect: "4:3", crop: "none", rotation: 0)
    #expect(abs(forced - 4.0 / 3.0) < 0.001)
    #expect(PictureLayout.mpvAspectOverride("16:9") == "16:9")
    #expect(PictureLayout.mpvAspectOverride("fit") == "no")
}

@Test func cropIsACenteredSourceRect() {
    let square = PictureLayout.cropRect(codedWidth: 1920, codedHeight: 1080, crop: "1:1")
    #expect(square?.width == 1080)
    #expect(square?.height == 1080)
    #expect(square?.x == 420)
    #expect(square?.y == 0)
    #expect(PictureLayout.mpvCrop(codedWidth: 1920, codedHeight: 1080, crop: "1:1") == "1080x1080+420+0")
    #expect(PictureLayout.cropRect(codedWidth: 1920, codedHeight: 1080, crop: "none") == nil)
    #expect(PictureLayout.mpvCrop(codedWidth: 1920, codedHeight: 1080, crop: "none") == "")
}

@Test func rotationSwapsAspectAndStaysCenteredWithoutSkew() {
    #expect(PictureLayout.normalizedRotation(90) == 90)
    #expect(PictureLayout.normalizedRotation(-90) == 270)
    #expect(PictureLayout.mpvRotate(180) == "180")
    let turned = PictureLayout.displayAspect(codedWidth: 1920, codedHeight: 1080, aspect: "fit", crop: "none", rotation: 90)
    #expect(abs(turned - 9.0 / 16.0) < 0.001)
    let place = PictureLayout.placement(
        windowWidth: 800, windowHeight: 450,
        codedWidth: 1920, codedHeight: 1080,
        aspect: "fit", crop: "none", rotation: 90, fill: false
    )
    #expect(place.rotation == 90)
    #expect(abs(place.displayAspect - 9.0 / 16.0) < 0.01)
    #expect(abs(place.boxWidth / place.boxHeight - place.displayAspect) < 0.01)
    #expect(place.boxHeight <= 450)
    #expect(place.boxWidth <= 800)
    #expect(place.contentWidth == place.boxHeight)
    #expect(place.contentHeight == place.boxWidth)
}

@Test func openingWindowIsSmallAndVideoCapsAtSixtyPercent() {
    #expect(WindowGeometry.emptyWidth == 440)
    #expect(WindowGeometry.emptyHeight == 174)
    let fitted = WindowGeometry.openingSize(videoWidth: 4000, videoHeight: 2000, screenWidth: 1440, screenHeight: 900)
    #expect(fitted?.width == 864)
    #expect(fitted?.height == 432)
    #expect((fitted?.width ?? 0) <= 1440 * 0.60 + 0.01)
    #expect((fitted?.height ?? 0) <= 900 * 0.60 + 0.01)
}

@Test func speedSliderStepsByHalfFromHalfToFour() {
    #expect(RateRange.maximum == 4)
    #expect(RateRange.step == 0.5)
    #expect(RateRange.stepped(0.1) == 0.5)
    #expect(RateRange.stepped(1.2) == 1.0)
    #expect(RateRange.stepped(1.3) == 1.5)
    #expect(RateRange.stepped(4.4) == 4)
    #expect(RateRange.stepped(1) == 1)
}
