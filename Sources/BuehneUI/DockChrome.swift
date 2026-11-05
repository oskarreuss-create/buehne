import BuehneCore
import SwiftUI

struct DockHover: ViewModifier {
    var scale: CGFloat = 1.2
    @State private var hovering = false

    @Environment(\.buehneBarScale) private var barScale

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering ? BarScale.hoverMagnification(scale: barScale, baseline: Double(scale)) : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.68), value: hovering)
            .onHover { hovering = $0 }
    }
}

extension View {
    func dockHover(scale: CGFloat = 1.2) -> some View {
        modifier(DockHover(scale: scale))
    }
}

/// Progress line that thickens under the pointer, with a larger thumb that follows the cursor.
struct LensSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var tint: Color
    var onEditingChanged: (Bool) -> Void
    @Environment(\.buehneBarScale) private var barScale
    @State private var pointer: CGFloat?
    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let span = max(range.upperBound - range.lowerBound, 0.001)
            let fraction = min(1, max(0, (value - range.lowerBound) / span))
            let playX = fraction * width
            Canvas { context, size in
                let cursor = pointer
                var x = CGFloat(0)
                while x <= size.width {
                    let dist = cursor.map { abs(x - $0) } ?? 80
                    let lift = cursor == nil ? 0 : max(0, 1 - dist / (42 * barScale))
                    let height = (2 + lift * 7) * barScale
                    let rect = CGRect(x: x, y: (size.height - height) / 2, width: 1.4, height: height)
                    let played = x <= playX
                    context.fill(Path(rect), with: .color(tint.opacity(played ? 0.95 : 0.32)))
                    x += 1
                }
                let radius: CGFloat = (cursor == nil ? 3.5 : 8) * barScale
                let center = cursor ?? playX
                let thumb = CGRect(x: center - radius, y: size.height / 2 - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: thumb), with: .color(tint))
            }
            .overlay(alignment: .topLeading) {
                if let cursor = pointer {
                    let target = range.lowerBound + Double(min(max(cursor / width, 0), 1)) * span
                    Text(BuehneTime.format(target))
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.black.opacity(0.82)))
                        .offset(x: min(max(cursor - 26, 0), max(0, width - 52)), y: -30)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let x = min(max(gesture.location.x, 0), width)
                        pointer = x
                        value = range.lowerBound + (x / width) * span
                        onEditingChanged(true)
                    }
                    .onEnded { _ in
                        onEditingChanged(false)
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    pointer = min(max(location.x, 0), width)
                case .ended:
                    pointer = nil
                }
            }
        }
        .frame(height: max(24, 24 * barScale))
    }
}
