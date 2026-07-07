import SwiftUI

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var symbolName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max"
        case .dark:
            return "moon.stars"
        }
    }

    var helpText: String {
        switch self {
        case .system:
            return "外観を自動にする"
        case .light:
            return "ライトモードにする"
        case .dark:
            return "ダークモードにする"
        }
    }
}
