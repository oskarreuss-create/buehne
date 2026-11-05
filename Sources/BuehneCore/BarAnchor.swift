import Foundation

/// Where the floating control island rests. Dragging snaps to the nearest of six spots.
public enum BarAnchor: String, CaseIterable, Sendable {
    case topLeft, topCenter, topRight, bottomLeft, bottomCenter, bottomRight

    public static let storageKey = "buehne.barAnchor"

    /// Anchor centre as a fraction of the free area (0...1 on each axis).
    public var unit: (x: Double, y: Double) {
        switch self {
        case .topLeft: (0, 0)
        case .topCenter: (0.5, 0)
        case .topRight: (1, 0)
        case .bottomLeft: (0, 1)
        case .bottomCenter: (0.5, 1)
        case .bottomRight: (1, 1)
        }
    }

    /// Nearest anchor to a point given as a fraction of the free area.
    public static func nearest(x: Double, y: Double) -> BarAnchor {
        let cx = x.isFinite ? min(1, max(0, x)) : 0.5
        let cy = y.isFinite ? min(1, max(0, y)) : 1
        return allCases.min { a, b in
            dist(a, cx, cy) < dist(b, cx, cy)
        } ?? .bottomCenter
    }

    private static func dist(_ a: BarAnchor, _ x: Double, _ y: Double) -> Double {
        let u = a.unit
        return (u.x - x) * (u.x - x) + (u.y - y) * (u.y - y)
    }
}
