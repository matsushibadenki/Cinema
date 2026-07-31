import Foundation

enum AIImageGenerationProvider: String, CaseIterable, Identifiable {
    case gemini
    case openAI = "openai"
    case deepInfra = "deepinfra"
    case novita
    case hyperbolic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gemini:
            return "Gemini"
        case .openAI:
            return "OpenAI"
        case .deepInfra:
            return "DeepInfra"
        case .novita:
            return "Novita"
        case .hyperbolic:
            return "Hyperbolic"
        }
    }

    static func value(for rawValue: String) -> AIImageGenerationProvider {
        AIImageGenerationProvider(rawValue: rawValue) ?? .gemini
    }
}

enum AIVideoGenerationProvider: String, CaseIterable, Identifiable {
    case gemini
    case openAI = "openai"
    case deepInfra = "deepinfra"
    case novita

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gemini:
            return "Gemini / Veo"
        case .openAI:
            return "OpenAI / Sora"
        case .deepInfra:
            return "DeepInfra"
        case .novita:
            return "Novita"
        }
    }

    static func value(for rawValue: String) -> AIVideoGenerationProvider {
        AIVideoGenerationProvider(rawValue: rawValue) ?? .gemini
    }
}
