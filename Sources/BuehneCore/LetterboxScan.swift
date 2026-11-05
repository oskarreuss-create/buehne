import Foundation

public struct PictureBounds: Sendable, Equatable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct LetterboxDecision: Sendable, Equatable {
    public var bounds: PictureBounds
    /// Almost no lit pixels. Callers must ignore the frame and keep the coded size.
    public var nearlyDark: Bool

    public init(bounds: PictureBounds, nearlyDark: Bool) {
        self.bounds = bounds
        self.nearlyDark = nearlyDark
    }
}

/// Edge scan. A bar is a run of rows or columns that are flat black across the whole edge.
/// A crop below half the frame on either axis is refused. A nearly black frame is not a crop.
public enum LetterboxScan {
    public static let minimumVotes = 3
    private static let blackLevel = 8

    public static func bounds(
        width: Int,
        height: Int,
        bytesPerRow: Int,
        pixels: UnsafePointer<UInt8>,
        threshold: Int = 18
    ) -> PictureBounds {
        decide(width: width, height: height, bytesPerRow: bytesPerRow, pixels: pixels, threshold: threshold).bounds
    }

    public static func decide(
        width: Int,
        height: Int,
        bytesPerRow: Int,
        pixels: UnsafePointer<UInt8>,
        threshold: Int = 18
    ) -> LetterboxDecision {
        let full = PictureBounds(x: 0, y: 0, width: max(width, 0), height: max(height, 0))
        guard width > 2, height > 2, bytesPerRow >= width * 4 else {
            return LetterboxDecision(bounds: full, nearlyDark: false)
        }
        func level(_ x: Int, _ y: Int) -> Int {
            let p = pixels + y * bytesPerRow + x * 4
            return max(Int(p[0]), max(Int(p[1]), Int(p[2])))
        }
        func lineIsBar(_ samples: Int, _ at: (Int) -> Int) -> Bool {
            var low = 255
            var high = 0
            var i = 0
            while i < samples {
                let value = at(i)
                low = min(low, value)
                high = max(high, value)
                if high > blackLevel || high - low > 2 { return false }
                i += 1
            }
            return high <= blackLevel
        }
        if nearlyDark(width: width, height: height, level: level, threshold: threshold) {
            return LetterboxDecision(bounds: full, nearlyDark: true)
        }
        var top = 0
        while top < height / 2, lineIsBar(width, { level($0, top) }) { top += 1 }
        var bottom = height - 1
        while bottom > top, lineIsBar(width, { level($0, bottom) }) { bottom -= 1 }
        var left = 0
        while left < width / 2, lineIsBar(height, { level(left, $0) }) { left += 1 }
        var right = width - 1
        while right > left, lineIsBar(height, { level(right, $0) }) { right -= 1 }
        func rowMax(_ y: Int) -> Int {
            var peak = 0
            var x = 0
            while x < width {
                peak = max(peak, level(x, y))
                x += 1
            }
            return peak
        }
        func columnMax(_ x: Int) -> Int {
            var peak = 0
            var y = 0
            while y < height {
                peak = max(peak, level(x, y))
                y += 1
            }
            return peak
        }
        var fringe = 0
        while fringe < 2, top < bottom, rowMax(top) <= 40, rowMax(top + 1) > 40 {
            top += 1
            fringe += 1
        }
        fringe = 0
        while fringe < 2, bottom > top, rowMax(bottom) <= 40, rowMax(bottom - 1) > 40 {
            bottom -= 1
            fringe += 1
        }
        fringe = 0
        while fringe < 2, left < right, columnMax(left) <= 40, columnMax(left + 1) > 40 {
            left += 1
            fringe += 1
        }
        fringe = 0
        while fringe < 2, right > left, columnMax(right) <= 40, columnMax(right - 1) > 40 {
            right -= 1
            fringe += 1
        }
        let cropped = PictureBounds(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
        if cropped.width * 2 < width || cropped.height * 2 < height {
            return LetterboxDecision(bounds: full, nearlyDark: false)
        }
        return LetterboxDecision(bounds: cropped, nearlyDark: false)
    }

    /// Nil until three usable frames agree. A sliver below half the frame is never a vote.
    public static func agreed(_ votes: [PictureBounds], width: Int, height: Int) -> PictureBounds? {
        let usable = votes.filter { $0.width * 2 >= width && $0.height * 2 >= height && $0.width > 0 && $0.height > 0 }
        guard usable.count >= minimumVotes else { return nil }
        let recent = usable.suffix(minimumVotes)
        guard let first = recent.first else { return nil }
        let same = recent.allSatisfy {
            abs($0.x - first.x) <= 2 && abs($0.y - first.y) <= 2
                && abs($0.width - first.width) <= 4 && abs($0.height - first.height) <= 4
        }
        return same ? first : nil
    }

    private static func nearlyDark(
        width: Int,
        height: Int,
        level: (Int, Int) -> Int,
        threshold: Int
    ) -> Bool {
        let stepX = max(1, width / 40)
        let stepY = max(1, height / 40)
        var lit = 0
        var seen = 0
        var y = 0
        while y < height {
            var x = 0
            while x < width {
                if level(x, y) > max(threshold, 24) { lit += 1 }
                seen += 1
                x += stepX
            }
            y += stepY
        }
        return seen == 0 || lit * 12 < seen
    }
}
