import SwiftUI

/// Optical 24-point grid, solid template foreground. No font/vibrancy dependency.
/// Visible silhouettes are transcribed from references 14–18; redacted controls
/// retain semantic window glyphs rather than guessing at the hidden artwork.
enum BuehneGlyph: String, CaseIterable {
    case volume, muted, backward, forward, play, pause, floating, exitFloating
    case pictureInPicture, settings, layout, video, audio, subtitles, liquidGlass
    case theme, messages, menu, sidebar, fillWindow, lockAspect, aspect, crop, rotation, speed
    case primarySubtitles, secondarySubtitles

    var usesEvenOdd: Bool {
        self == .layout || self == .subtitles || self == .primarySubtitles || self == .secondarySubtitles
    }

    func path(in rect: CGRect = CGRect(x: 0, y: 0, width: 24, height: 24)) -> Path {
        var p = Path()
        func polygon(_ points: [(CGFloat, CGFloat)]) {
            guard let first = points.first else { return }
            p.move(to: CGPoint(x: first.0, y: first.1))
            for point in points.dropFirst() { p.addLine(to: CGPoint(x: point.0, y: point.1)) }
            p.closeSubpath()
        }
        func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat = 1) {
            p.addRoundedRect(in: CGRect(x: x, y: y, width: w, height: h), cornerSize: CGSize(width: r, height: r))
        }
        func stroke(_ points: [(CGFloat, CGFloat)], _ width: CGFloat = 1.8) {
            var line = Path()
            guard let first = points.first else { return }
            line.move(to: CGPoint(x: first.0, y: first.1))
            for point in points.dropFirst() { line.addLine(to: CGPoint(x: point.0, y: point.1)) }
            p.addPath(line.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)))
        }
        func outline(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat = 2, _ width: CGFloat = 1.8) {
            let line = Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
            p.addPath(line.strokedPath(StrokeStyle(lineWidth: width, lineJoin: .round)))
        }
        func triangle(_ x: CGFloat) {
            p.move(to: CGPoint(x: x + 9.3, y: 4.3))
            p.addQuadCurve(to: CGPoint(x: x + 11, y: 5.2), control: CGPoint(x: x + 11, y: 3.1))
            p.addLine(to: CGPoint(x: x + 11, y: 18.8))
            p.addQuadCurve(to: CGPoint(x: x + 9.3, y: 19.7), control: CGPoint(x: x + 11, y: 20.9))
            p.addLine(to: CGPoint(x: x + 0.8, y: 13.2))
            p.addQuadCurve(to: CGPoint(x: x + 0.8, y: 10.8), control: CGPoint(x: x - 0.8, y: 12))
            p.closeSubpath()
        }
        switch self {
        case .play:
            p.move(to: CGPoint(x: 5, y: 2.8))
            p.addQuadCurve(to: CGPoint(x: 7, y: 2.8), control: CGPoint(x: 5, y: 1.8))
            p.addLine(to: CGPoint(x: 22, y: 10.8))
            p.addQuadCurve(to: CGPoint(x: 22, y: 13.2), control: CGPoint(x: 24, y: 12))
            p.addLine(to: CGPoint(x: 7, y: 21.2))
            p.addQuadCurve(to: CGPoint(x: 5, y: 20.2), control: CGPoint(x: 5, y: 22.2))
            p.closeSubpath()
        case .pause:
            box(5, 3, 5, 18, 1); box(14, 3, 5, 18, 1)
        case .backward, .forward:
            triangle(0.5); triangle(12)
            if self == .forward { p = p.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 24, ty: 0)) }
        case .volume, .muted:
            polygon([(2,9),(6,9),(11,5),(12,5),(12,19),(11,19),(6,15),(2,15)])
            if self == .muted {
                stroke([(16,9),(22,15)]); stroke([(22,9),(16,15)])
            } else {
                for (x, inset) in [(CGFloat(14), CGFloat(8)), (17,5), (20,2)] {
                    var arc = Path()
                    arc.move(to: CGPoint(x: x, y: inset))
                    arc.addCurve(to: CGPoint(x: x, y: 24 - inset), control1: CGPoint(x: x + 3, y: inset + 2), control2: CGPoint(x: x + 3, y: 22 - inset))
                    p.addPath(arc.strokedPath(StrokeStyle(lineWidth: 1.6, lineCap: .round)))
                }
            }
        case .pictureInPicture:
            outline(2, 4, 17, 13, 2, 1.7)
            stroke([(6,8),(10,12)], 1.5); stroke([(7,12),(10,12),(10,9)], 1.5)
            // Filled front screen is deliberately separate from the rear outline.
            box(11, 12, 12, 9, 1.6)
        case .floating, .exitFloating:
            outline(2, 4, 20, 16, 2, 1.7)
            if self == .floating {
                stroke([(5,7),(9,7),(9,11)], 1.6); stroke([(19,17),(15,17),(15,13)], 1.6)
                stroke([(5,7),(10,12)], 1.6); stroke([(19,17),(14,12)], 1.6)
            } else {
                stroke([(9,7),(5,7),(5,11)], 1.6); stroke([(15,17),(19,17),(19,13)], 1.6)
                stroke([(5,7),(10,12)], 1.6); stroke([(19,17),(14,12)], 1.6)
            }
        case .settings:
            // Eight rounded radial teeth and the reference's open central ring.
            var edge = Path()
            for i in 0..<64 {
                let angle = CGFloat(i) * .pi / 32 - .pi / 2
                let phase = i % 8
                let radius: CGFloat = (phase == 0 || phase == 1 || phase == 7) ? 10 : 8.1
                let point = CGPoint(x: 12 + cos(angle) * radius, y: 12 + sin(angle) * radius)
                if i == 0 { edge.move(to: point) } else { edge.addLine(to: point) }
            }
            edge.closeSubpath()
            p.addPath(edge.strokedPath(StrokeStyle(lineWidth: 1.5, lineJoin: .round)))
            p.addPath(Path(ellipseIn: CGRect(x: 8.2, y: 8.2, width: 7.6, height: 7.6)).strokedPath(StrokeStyle(lineWidth: 1.6)))
        case .layout:
            box(6.5, 2, 10, 8, 1)
            box(6.5, 10.8, 10, 2.1, 0.5)
            p.move(to: CGPoint(x: 9, y: 13.6)); p.addLine(to: CGPoint(x: 14, y: 13.6))
            p.addLine(to: CGPoint(x: 14, y: 20.3))
            p.addQuadCurve(to: CGPoint(x: 9, y: 20.3), control: CGPoint(x: 11.5, y: 25))
            p.closeSubpath()
            p.addEllipse(in: CGRect(x: 10.4, y: 19.1, width: 2.2, height: 2.2))
            p = p.applying(CGAffineTransform(translationX: -12, y: -12).concatenating(CGAffineTransform(rotationAngle: .pi / 4)).concatenating(CGAffineTransform(translationX: 12, y: 12)))
        case .video:
            outline(2, 4, 20, 16, 2, 2)
            polygon([(3,17),(9,10),(13,14),(16,11),(21,17),(21,19),(3,19)])
            p.addEllipse(in: CGRect(x: 15.2, y: 6.8, width: 3.2, height: 3.2))
        case .audio:
            for (x,h) in [(2,6),(5,13),(8,20),(11,12),(14,16),(17,8),(20,12)] {
                // At 16pt these starts land on whole pixels, retaining solid ink.
                box(CGFloat(x) - 0.5, CGFloat(12) - CGFloat(h)/2, 2, CGFloat(h), 0.9)
            }
        case .subtitles:
            box(1.5, 3.5, 21, 15, 3)
            polygon([(6,18.5),(6,22),(11,18.5)])
            // Even/odd counters create caption marks, never background-colored ink.
            box(5, 7.5, 5, 1.5, 0.4); box(11.5, 7.5, 7, 1.5, 0.4)
            box(5, 11, 8, 1.5, 0.4); box(14.5, 11, 4, 1.5, 0.4)
        case .liquidGlass:
            outline(2, 3, 16, 13, 3, 1.7)
            outline(7, 8, 15, 13, 6, 1.7)
        case .theme:
            p.addPath(Path(ellipseIn: CGRect(x: 3, y: 3, width: 18, height: 18)).strokedPath(StrokeStyle(lineWidth: 1.8)))
            p.move(to: CGPoint(x: 12, y: 3)); p.addArc(center: CGPoint(x: 12, y: 12), radius: 9, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true); p.closeSubpath()
        case .messages, .menu, .sidebar:
            outline(2.5, 4, 19, 16, 2, 1.7)
            if self == .messages { box(5.5, 7, 4, 3, 0.5) }
            if self == .menu { stroke([(6,16.5),(18,16.5)], 1.6) }
            if self == .sidebar { stroke([(15.5,5),(15.5,19)], 1.5); stroke([(18,8),(19,8)], 1); stroke([(18,11),(19,11)], 1); stroke([(18,14),(19,14)], 1) }
        case .fillWindow:
            outline(2, 4, 20, 16, 2, 1.7)
            stroke([(8,8),(6,8),(6,10)], 1.5); stroke([(16,16),(18,16),(18,14)], 1.5)
            stroke([(6,8),(10,12)], 1.5); stroke([(18,16),(14,12)], 1.5)
            stroke([(16,8),(18,8),(18,10)], 1.5); stroke([(8,16),(6,16),(6,14)], 1.5)
        case .lockAspect:
            outline(2, 4, 20, 16, 2, 1.7); box(9, 11, 6, 6, 1)
            outline(10, 7, 4, 6, 2, 1.5)
        case .aspect:
            outline(2, 4, 20, 16, 2, 1.7); stroke([(3,9),(16,9),(16,19)], 1.6)
            stroke([(11,9),(11,19)], 1.4)
        case .crop:
            stroke([(7,2),(7,17),(22,17)], 1.8); stroke([(2,7),(17,7),(17,22)], 1.8)
        case .rotation:
            outline(3, 7, 13, 14, 2, 1.7)
            var arc = Path(); arc.move(to: CGPoint(x: 12, y: 3))
            arc.addCurve(to: CGPoint(x: 21, y: 9), control1: CGPoint(x: 18, y: 1), control2: CGPoint(x: 22, y: 4))
            p.addPath(arc.strokedPath(StrokeStyle(lineWidth: 1.6, lineCap: .round)))
            stroke([(18,7),(21,9),(23,6)], 1.6)
        case .speed:
            stroke([(4,6),(10,12),(4,18)], 2); stroke([(12,6),(18,12),(12,18)], 2)
        case .primarySubtitles, .secondarySubtitles:
            box(3, 3, 18, 18, 2)
            if self == .primarySubtitles {
                polygon([(10,7),(13,7),(13,17),(11,17),(11,10),(9,11),(9,9)])
            } else {
                var two = Path(); two.move(to: CGPoint(x: 9, y: 9))
                two.addCurve(to: CGPoint(x: 15, y: 10), control1: CGPoint(x: 10, y: 6), control2: CGPoint(x: 16, y: 7))
                two.addLine(to: CGPoint(x: 9, y: 16)); two.addLine(to: CGPoint(x: 15, y: 16))
                p.addPath(two.strokedPath(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)))
            }
        }
        let scale = min(rect.width, rect.height) / 24
        return p.applying(CGAffineTransform(scaleX: scale, y: scale).concatenating(
            CGAffineTransform(translationX: rect.midX - 12 * scale, y: rect.midY - 12 * scale)))
    }
}

struct BuehneIcon: View {
    var glyph: BuehneGlyph
    var size: CGFloat = 20

    init(_ glyph: BuehneGlyph, size: CGFloat = 20) { self.glyph = glyph; self.size = size }

    var body: some View {
        BuehneGlyphShape(glyph: glyph)
            .fill(style: FillStyle(eoFill: glyph.usesEvenOdd))
            .frame(width: size, height: size)
    }
}

private struct BuehneGlyphShape: Shape {
    var glyph: BuehneGlyph
    func path(in rect: CGRect) -> Path { glyph.path(in: rect) }
}
