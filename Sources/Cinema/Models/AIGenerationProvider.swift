import Foundation

enum AIImageGenerationProvider: String, CaseIterable, Identifiable {
    case gemini
    case openAI = "openai"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gemini:
            return "Gemini"
        case .openAI:
            return "OpenAI"
        }
    }

    static func value(for rawValue: String) -> AIImageGenerationProvider {
        AIImageGenerationProvider(rawValue: rawValue) ?? .gemini
    }
}

enum AIVideoGenerationProvider: String, CaseIterable, Identifiable {
    case gemini
    case openAI = "openai"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gemini:
            return "Gemini / Veo"
        case .openAI:
            return "OpenAI / Sora"
        }
    }

    static func value(for rawValue: String) -> AIVideoGenerationProvider {
        AIVideoGenerationProvider(rawValue: rawValue) ?? .gemini
    }
}
