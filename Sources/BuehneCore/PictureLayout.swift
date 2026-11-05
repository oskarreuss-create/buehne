import Foundation

/// How a coded frame is shown. Aspect forces the display ratio, crop center-cuts
/// to a ratio, and a quarter turn swaps the axes. The fitted box is never skewed:
/// its width/height is the display aspect, and it stays centered.
public struct PicturePlacement: Equatable, Sendable {
    public var sourceWidth: Double
    public var sourceHeight: Double
    public var contentWidth: Double
    public var contentHeight: Double
    public var boxWidth: Double
    public var boxHeight: Double
    public var rotation: Int
    /// True when the source should be center-cropped rather than letterboxed.
    public var cropToFill: Bool

    public var displayAspect: Double { boxHeight > 0 ? boxWidth / boxHeight : 0 }
}

public enum PictureLayout {
    public static func ratio(_ name: String) -> Double? {
        switch name {
        case "4:3": 4.0 / 3.0
        case "16:9": 16.0 / 9.0
        case "16:10": 16.0 / 10.0
        case "21:9": 21.0 / 9.0
        case "5:4": 5.0 / 4.0
        case "1:1": 1
        default: nil
        }
    }

    public static func normalizedRotation(_ degrees: Int) -> Int {
        switch ((degrees % 360) + 360) % 360 {
        case 90: 90
        case 180: 180
        case 270: 270
        default: 0
        }
    }

    public static func displayAspect(codedWidth: Double, codedHeight: Double, aspect: String, crop: String, rotation: Int) -> Double {
        let native = codedWidth > 1 && codedHeight > 1 ? codedWidth / codedHeight : 16.0 / 9.0
        let cropped = ratio(crop) ?? native
        let forced = ratio(aspect) ?? cropped
        return normalizedRotation(rotation) % 180 == 0 ? forced : 1 / forced
    }

    /// Centered crop in source pixels. Nil means no crop.
    public static func cropRect(codedWidth: Double, codedHeight: Double, crop: String) -> (x: Int, y: Int, width: Int, height: Int)? {
        guard let target = ratio(crop), codedWidth > 1, codedHeight > 1 else { return nil }
        let native = codedWidth / codedHeight
        if native > target {
            let width = max(2, (codedHeight * target).rounded())
            let x = max(0, ((codedWidth - width) / 2).rounded())
            return (Int(x), 0, Int(width), Int(codedHeight))
        }
        let height = max(2, (codedWidth / target).rounded())
        let y = max(0, ((codedHeight - height) / 2).rounded())
        return (0, Int(y), Int(codedWidth), Int(height))
    }

    public static func mpvAspectOverride(_ aspect: String) -> String {
        ratio(aspect) == nil ? "no" : aspect
    }

    public static func mpvCrop(codedWidth: Double, codedHeight: Double, crop: String) -> String {
        guard let rect = cropRect(codedWidth: codedWidth, codedHeight: codedHeight, crop: crop) else { return "" }
        return "\(rect.width)x\(rect.height)+\(rect.x)+\(rect.y)"
    }

    public static func mpvRotate(_ degrees: Int) -> String {
        String(normalizedRotation(degrees))
    }

    public static func placement(
        windowWidth: Double,
        windowHeight: Double,
        codedWidth: Double,
        codedHeight: Double,
        aspect: String,
        crop: String,
        rotation: Int,
        fill: Bool
    ) -> PicturePlacement {
        let turn = normalizedRotation(rotation)
        let native = codedWidth > 1 && codedHeight > 1 ? codedWidth / codedHeight : 16.0 / 9.0
        let cropped = ratio(crop) ?? native
        let forced = ratio(aspect) ?? cropped
        let shown = turn % 180 == 0 ? forced : 1 / forced
        let box = fitted(windowWidth: windowWidth, windowHeight: windowHeight, displayAspect: fill && ratio(aspect) == nil && ratio(crop) == nil ? native : shown)
        let quarter = turn == 90 || turn == 270
        let contentW = quarter ? box.height : box.width
        let contentH = quarter ? box.width : box.height
        let sourceAspect = cropped
        let sourceW = contentW
        let sourceH = sourceW / sourceAspect
        let fittedSourceH = min(sourceH, contentH)
        let fittedSourceW = fittedSourceH * sourceAspect
        return PicturePlacement(
            sourceWidth: max(1, fittedSourceW),
            sourceHeight: max(1, fittedSourceH),
            contentWidth: max(1, contentW),
            contentHeight: max(1, contentH),
            boxWidth: box.width,
            boxHeight: box.height,
            rotation: turn,
            cropToFill: ratio(crop) != nil || (fill && ratio(aspect) == nil)
        )
    }

    public static func fitted(windowWidth: Double, windowHeight: Double, displayAspect: Double) -> (width: Double, height: Double) {
        let aspect = max(displayAspect, 0.01)
        let windowW = max(windowWidth, 1)
        let windowH = max(windowHeight, 1)
        var width = windowW
        var height = width / aspect
        if height > windowH {
            height = windowH
            width = height * aspect
        }
        return (width, height)
    }
}
