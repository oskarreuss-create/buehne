import SwiftUI

private struct BarScaleKey: EnvironmentKey {
    static let defaultValue = 1.0
}

extension EnvironmentValues {
    var buehneBarScale: Double {
        get { self[BarScaleKey.self] }
        set { self[BarScaleKey.self] = newValue }
    }
}
