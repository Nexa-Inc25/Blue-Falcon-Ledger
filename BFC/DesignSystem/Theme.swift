import SwiftUI

/// Central design tokens. Dark, tough, blue-collar. Never hardcode colors/fonts in views.
enum Theme {
    // MARK: Colors
    /// Near-black base background.
    static let background = Color(red: 0.05, green: 0.06, blue: 0.07)
    /// Slightly lifted surface for cards.
    static let surface = Color(red: 0.11, green: 0.12, blue: 0.14)
    static let surfaceHigh = Color(red: 0.16, green: 0.17, blue: 0.20)
    /// High-contrast primary text.
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.65)
    static let textMuted = Color(white: 0.45)
    /// Hard-hat / safety accent — the brand color.
    static let accent = Color(red: 1.0, green: 0.62, blue: 0.04)
    static let danger = Color(red: 0.92, green: 0.26, blue: 0.21)
    static let good = Color(red: 0.30, green: 0.78, blue: 0.45)
    static let warn = Color(red: 0.98, green: 0.78, blue: 0.20)
    static let border = Color(white: 0.22)

    // MARK: Metrics
    /// Minimum tap target — gloves on.
    static let tapTarget: CGFloat = 56
    static let corner: CGFloat = 14
    static let pad: CGFloat = 16

    // MARK: Fonts (body min 17pt per HIG + spec)
    static func title(_ size: CGFloat = 28) -> Font { .system(size: size, weight: .heavy, design: .default) }
    static func headline(_ size: CGFloat = 20) -> Font { .system(size: size, weight: .bold) }
    static func body(_ size: CGFloat = 17) -> Font { .system(size: size, weight: .semibold) }
    static let mono = Font.system(.body, design: .monospaced).weight(.semibold)
}

extension AnalysisVerdict {
    var color: Color {
        switch self {
        case .looksGood: return Theme.good
        case .minor: return Theme.warn
        case .shorted: return Theme.danger
        case .needsInfo: return Theme.textSecondary
        }
    }

    var systemImage: String {
        switch self {
        case .looksGood: return "checkmark.seal.fill"
        case .minor: return "exclamationmark.triangle.fill"
        case .shorted: return "xmark.octagon.fill"
        case .needsInfo: return "questionmark.circle.fill"
        }
    }
}
