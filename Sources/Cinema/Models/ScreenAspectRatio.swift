import Foundation

enum ScreenAspectRatio: String, CaseIterable, Identifiable {
    case television169 = "television169"
    case shortVideo916 = "shortVideo916"
    case cinema185 = "cinema185"
    case cinemascope239 = "cinemascope239"
    case academy43 = "academy43"

    var id: String { rawValue }

    var label: String {
        label(language: AppLanguage.japanese.rawValue)
    }

    func label(language rawLanguage: String) -> String {
        let language = AppLanguage.value(for: rawLanguage)
        switch self {
        case .television169:
            switch language {
            case .japanese: return "テレビ 16:9"
            case .english: return "Television 16:9"
            case .simplifiedChinese: return "电视 16:9"
            }
        case .shortVideo916:
            switch language {
            case .japanese: return "ショート動画 9:16"
            case .english: return "Short Video 9:16"
            case .simplifiedChinese: return "短视频 9:16"
            }
        case .cinema185:
            switch language {
            case .japanese: return "映画 1.85:1"
            case .english: return "Cinema 1.85:1"
            case .simplifiedChinese: return "电影 1.85:1"
            }
        case .cinemascope239:
            switch language {
            case .japanese: return "シネスコ 2.39:1"
            case .english: return "CinemaScope 2.39:1"
            case .simplifiedChinese: return "宽银幕 2.39:1"
            }
        case .academy43:
            switch language {
            case .japanese: return "アカデミー 4:3"
            case .english: return "Academy 4:3"
            case .simplifiedChinese: return "学院 4:3"
            }
        }
    }

    var detail: String {
        detail(language: AppLanguage.japanese.rawValue)
    }

    func detail(language rawLanguage: String) -> String {
        let language = AppLanguage.value(for: rawLanguage)
        switch self {
        case .television169:
            switch language {
            case .japanese: return "HDTV / 配信向け"
            case .english: return "HDTV / Streaming"
            case .simplifiedChinese: return "HDTV / 流媒体"
            }
        case .shortVideo916:
            switch language {
            case .japanese: return "縦型ショート動画"
            case .english: return "Vertical short video"
            case .simplifiedChinese: return "竖屏短视频"
            }
        case .cinema185:
            switch language {
            case .japanese: return "ビスタサイズ"
            case .english: return "Vista size"
            case .simplifiedChinese: return "Vista 画幅"
            }
        case .cinemascope239:
            switch language {
            case .japanese: return "ワイドスクリーン"
            case .english: return "Widescreen"
            case .simplifiedChinese: return "宽银幕"
            }
        case .academy43:
            switch language {
            case .japanese: return "クラシック"
            case .english: return "Classic"
            case .simplifiedChinese: return "经典"
            }
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
