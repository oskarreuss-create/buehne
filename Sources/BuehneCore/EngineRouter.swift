import Foundation

public enum EngineKind: String, Sendable, Equatable {
    case avFoundation
    case libmpv
}

public struct EngineRoute: Sendable, Equatable {
    public var kind: EngineKind
    public var reason: String

    public init(kind: EngineKind, reason: String) {
        self.kind = kind
        self.reason = reason
    }
}

/// The only place that chooses AVFoundation or libmpv.
/// Native containers go to AVFoundation. Everything else, including an unknown extension, goes to libmpv.
public enum EngineRouter {
    public static let avFoundationExtensions: Set<String> = ["mp4", "m4v", "mov"]

    public static func route(_ url: URL) -> EngineRoute {
        let ext = url.pathExtension.lowercased()
        if avFoundationExtensions.contains(ext) {
            return EngineRoute(kind: .avFoundation, reason: "native container .\(ext)")
        }
        if ext.isEmpty {
            return EngineRoute(kind: .libmpv, reason: "no extension")
        }
        return EngineRoute(kind: .libmpv, reason: "non-native container .\(ext)")
    }
}

public enum RateRange {
    public static let minimum = 0.5
    public static let maximum = 4.0
    public static let step = 0.5

    public static func clamp(_ value: Double) -> Double {
        min(maximum, max(minimum, value))
    }

    public static func stepped(_ value: Double) -> Double {
        let clamped = clamp(value)
        let steps = (clamped / step).rounded()
        return clamp(steps * step)
    }
}
