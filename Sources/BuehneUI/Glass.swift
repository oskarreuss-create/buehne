import SwiftUI

struct GlassPanel<Content: View>: View {
    var radius: CGFloat = 24
    var opacity: Double
    var isLight: Bool
    var interactive: Bool = false
    var menu: Bool = false
    @Environment(\.controlActiveState) private var controlActiveState
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let activity: WindowActivity = controlActiveState == .inactive ? .inactive : .active
        let backing = GlassAppearance.sharedBacking(opacity)
        let surface = Color(white: BuehneTheme.contentWhite(isLight: isLight, activity: activity))
        let glass = (interactive && !menu) ? Glass.regular.interactive() : Glass.regular
        return content()
            .background {
                ZStack {
                    if opacity < 99 {
                        shape
                            .fill(.clear)
                            .glassEffect(glass, in: .rect(cornerRadius: radius))
                            .opacity(min(1, max(0, (100 - opacity) / 50)))
                    }
                    shape
                        .fill(surface.opacity(backing))
                }
                .allowsHitTesting(false)
            }
            .foregroundStyle(isLight ? Color.black : Color.white)
            .environment(\.colorScheme, isLight ? .light : .dark)
    }
}

struct BuehneMark: View {
    var side: CGFloat = 92

    var body: some View {
        ZStack {
            MarkSilhouette()
                .fill(Color.black)
            MarkSweep()
                .fill(BuehneColor.markRed)
            Image(systemName: "play.fill")
                .font(.system(size: side * 0.34))
                .foregroundStyle(.white)
                .offset(x: side * 0.015, y: side * 0.015)
            SwissCross()
                .fill(Color.white)
                .frame(width: side * 0.14, height: side * 0.14)
                .offset(x: side * 0.35, y: side * 0.25)
        }
        .frame(width: side, height: side * 0.76)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("BÜHNE")
    }
}

/// Swept silhouette from reference 11, rather than a generic app-icon tile.
private struct MarkSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 0.30))
            p.addCurve(to: CGPoint(x: 0.59, y: 0.04), control1: CGPoint(x: 0.01, y: -0.04), control2: CGPoint(x: 0.18, y: -0.02))
            p.addCurve(to: CGPoint(x: 0, y: 0.30), control1: CGPoint(x: 0.30, y: 0.04), control2: CGPoint(x: 0.10, y: 0.13))
            p.closeSubpath()
            p.move(to: CGPoint(x: 0.01, y: 0.53))
            p.addCurve(to: CGPoint(x: 0.81, y: 0.07), control1: CGPoint(x: 0.01, y: 0.16), control2: CGPoint(x: 0.47, y: 0.07))
            p.addCurve(to: CGPoint(x: 1, y: 0.40), control1: CGPoint(x: 1, y: 0.07), control2: CGPoint(x: 1, y: 0.19))
            p.addCurve(to: CGPoint(x: 0.29, y: 0.72), control1: CGPoint(x: 0.68, y: 0.44), control2: CGPoint(x: 0.70, y: 0.65))
            p.addCurve(to: CGPoint(x: 0.01, y: 0.53), control1: CGPoint(x: 0.04, y: 0.80), control2: CGPoint(x: 0.01, y: 0.72))
            p.closeSubpath()
        }.applying(CGAffineTransform(scaleX: rect.width, y: rect.height / 0.76))
    }
}

private struct MarkSweep: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0.25, y: 0.76))
            p.addCurve(to: CGPoint(x: 1, y: 0.44), control1: CGPoint(x: 0.70, y: 0.70), control2: CGPoint(x: 0.68, y: 0.49))
            p.addLine(to: CGPoint(x: 1, y: 0.59))
            p.addCurve(to: CGPoint(x: 0.84, y: 0.76), control1: CGPoint(x: 1, y: 0.72), control2: CGPoint(x: 0.96, y: 0.76))
            p.closeSubpath()
        }.applying(CGAffineTransform(scaleX: rect.width, y: rect.height / 0.76))
    }
}

private struct SwissCross: Shape {
    func path(in rect: CGRect) -> Path {
        let arm = min(rect.width, rect.height) / 3
        var path = Path()
        path.addRect(CGRect(x: rect.midX - arm / 2, y: rect.minY, width: arm, height: rect.height))
        path.addRect(CGRect(x: rect.minX, y: rect.midY - arm / 2, width: rect.width, height: arm))
        return path
    }
}
