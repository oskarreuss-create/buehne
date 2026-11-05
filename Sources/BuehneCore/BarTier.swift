import Foundation

/// How much of the control island fits. The bar sheds parts as its width shrinks.
public enum BarTier: Equatable, Sendable {
    case full      // times, seek line, all buttons
    case compact   // no times
    case minimal   // volume, play/pause, expand

    public static func forWidth(_ width: Double) -> BarTier {
        if width >= 360 { return .full }
        if width >= 230 { return .compact }
        return .minimal
    }
}
