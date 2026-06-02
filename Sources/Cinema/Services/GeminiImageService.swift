import Foundation

struct GeminiImageService {
    enum ServiceError: LocalizedError {
        case missingAPIKey
        case invalidURL
        case requestFailed(String)
        case imageNotFound

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Gemini APIキーが設定されていません。設定画面で入力してください。"
            case .invalidURL:
                return "Gemini APIのURLを作成できませんでした。"
            case .requestFailed(let message):
                return message
            case .imageNotFound:
                return "レスポンス内に画像データが見つかりませんでした。"
            }
        }
    }

    var apiKey: String
    var model: String

    func generateStoryboardImage(
        systemPrompt: String,
        documentPrompt: String,
        cutPrompt: String,
        aspectRatio: CGFloat,
        referenceImages: [GeminiReferenceImage]
    ) async throws -> Data {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.missingAPIKey
        }

        let encodedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):generateContent?key=\(apiKey)") else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let parts = [GeminiPart(text: composedPrompt(
            systemPrompt: systemPrompt,
            documentPrompt: documentPrompt,
            cutPrompt: cutPrompt,
            aspectRatio: aspectRatio,
            hasReferenceImages: !referenceImages.isEmpty
        ))] + referenceImages.map {
            GeminiPart(inlineData: GeminiInlineData(mimeType: $0.mimeType, data: $0.data.base64EncodedString()))
        }

        request.httpBody = try JSONEncoder().encode(GeminiGenerateRequest(
            contents: [
                GeminiContent(parts: parts)
            ],
            generationConfig: GeminiGenerationConfig(responseModalities: ["IMAGE"])
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Gemini API request failed."
            throw ServiceError.requestFailed(message)
        }

        let decoded = try JSONDecoder().decode(GeminiGenerateResponse.self, from: data)
        for candidate in decoded.candidates ?? [] {
            for part in candidate.content.parts {
                if let inlineData = part.inlineData, let image = Data(base64Encoded: inlineData.data) {
                    return image
                }
            }
        }

        throw ServiceError.imageNotFound
    }

    private func composedPrompt(systemPrompt: String, documentPrompt: String, cutPrompt: String, aspectRatio: CGFloat, hasReferenceImages: Bool) -> String {
        let fallbackSystemPrompt = """
        Create a clean monochrome storyboard panel in a hand-drawn pencil style.
        Compose the image as a cinematic scene environment based on the written situation and dialogue.
        Show clear character placement, location, mood, and action. Do not render any text, captions, speech bubbles, or UI elements inside the image.
        """

        return [
            "Global image direction:",
            systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallbackSystemPrompt : systemPrompt,
            "",
            "Document-specific direction:",
            documentPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
            "",
            hasReferenceImages ? "Use the attached reference photos for character, object, costume, location, and visual design consistency. Do not copy text from references." : "",
            "",
            "Scene content, staging, names, and dialogue:",
            cutPrompt,
            "",
            "Frame aspect ratio:",
            String(format: "%.2f:1", Double(aspectRatio))
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }
}

struct GeminiReferenceImage {
    var mimeType: String
    var data: Data
}

private struct GeminiGenerateRequest: Encodable {
    var contents: [GeminiContent]
    var generationConfig: GeminiGenerationConfig
}

private struct GeminiGenerationConfig: Encodable {
    var responseModalities: [String]
}

private struct GeminiContent: Codable {
    var parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    var text: String?
    var inlineData: GeminiInlineData?
}

struct GeminiInlineData: Codable {
    var mimeType: String
    var data: String
}

private struct GeminiGenerateResponse: Decodable {
    var candidates: [GeminiCandidate]?
}

private struct GeminiCandidate: Decodable {
    var content: GeminiContent
}
