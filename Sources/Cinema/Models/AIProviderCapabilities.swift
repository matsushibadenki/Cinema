import Foundation

struct AIProviderCapabilities {
    let supportedVideoDurations: [Int]
    let maximumReferenceImages: Int

    func normalizedDuration(_ requested: Double) -> Int {
        supportedVideoDurations.min {
            abs(Double($0) - requested) < abs(Double($1) - requested)
        } ?? supportedVideoDurations[0]
    }

    static func video(provider: AIVideoGenerationProvider, hasReferenceImages: Bool) -> AIProviderCapabilities {
        switch provider {
        case .openAI:
            return AIProviderCapabilities(
                supportedVideoDurations: [4, 8, 12],
                maximumReferenceImages: 1
            )
        case .gemini:
            return AIProviderCapabilities(
                supportedVideoDurations: hasReferenceImages ? [8] : [4, 6, 8],
                maximumReferenceImages: 3
            )
        }
    }
}
