import Foundation

enum ScreenAspectRatio: String, CaseIterable, Identifiable {
    case television169 = "television169"
    case shortVideo916 = "shortVideo916"
    case cinema185 = "cinema185"
    case cinemascope239 = "cinemascope239"
    case academy43 = "academy43"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .television169:
            return "テレビ 16:9"
        case .shortVideo916:
            return "ショート動画 9:16"
        case .cinema185:
            return "映画 1.85:1"
        case .cinemascope239:
            return "シネスコ 2.39:1"
        case .academy43:
            return "アカデミー 4:3"
        }
    }

    var detail: String {
        switch self {
        case .television169:
            return "HDTV / 配信向け"
        case .shortVideo916:
            return "縦型ショート動画"
        case .cinema185:
            return "ビスタサイズ"
        case .cinemascope239:
            return "ワイドスクリーン"
        case .academy43:
            return "クラシック"
        }
    }

    var ratio: CGFloat {
        switch self {
        case .television169:
            return 16 / 9
        case .shortVideo916:
            return 9 / 16
        case .cinema185:
            return 1.85
        case .cinemascope239:
            return 2.39
        case .academy43:
            return 4 / 3
        }
    }

    static func value(for rawValue: String) -> ScreenAspectRatio {
        ScreenAspectRatio(rawValue: rawValue) ?? .television169
    }
}
