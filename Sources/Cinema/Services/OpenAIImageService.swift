import Foundation

struct OpenAIImageService {
    enum ServiceError: LocalizedError {
        case missingAPIKey
        case invalidURL
        case requestFailed(String)
        case imageNotFound

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "OpenAI APIキーが設定されていません。設定画面で入力してください。"
            case .invalidURL:
                return "OpenAI APIのURLを作成できませんでした。"
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
        aspectRatio: CGFloat
    ) async throws -> Data {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.missingAPIKey
        }

        guard let url = URL(string: "https://api.openai.com/v1/images/generations") else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(OpenAIImageRequest(
            model: model,
            prompt: composedPrompt(
                systemPrompt: systemPrompt,
                documentPrompt: documentPrompt,
                cutPrompt: cutPrompt,
                aspectRatio: aspectRatio
            ),
            size: imageSize(for: aspectRatio),
            n: 1
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "OpenAI API request failed."
            throw ServiceError.requestFailed(message)
        }

        let decoded = try JSONDecoder().decode(OpenAIImageResponse.self, from: data)
        guard let imageBase64 = decoded.data.first?.b64JSON,
              let image = Data(base64Encoded: imageBase64) else {
            throw ServiceError.imageNotFound
        }

        return image
    }

    private func composedPrompt(systemPrompt: String, documentPrompt: String, cutPrompt: String, aspectRatio: CGFloat) -> String {
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
            "Scene content, staging, names, and dialogue:",
            cutPrompt,
            "",
            "Frame aspect ratio:",
            String(format: "%.2f:1", Double(aspectRatio))
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }

    private func imageSize(for aspectRatio: CGFloat) -> String {
        aspectRatio >= 1 ? "1536x1024" : "1024x1536"
    }
}

private struct OpenAIImageRequest: Encodable {
    var model: String
    var prompt: String
    var size: String
    var n: Int
}

private struct OpenAIImageResponse: Decodable {
    var data: [OpenAIImageData]
}

private struct OpenAIImageData: Decodable {
    var b64JSON: String?

    private enum CodingKeys: String, CodingKey {
        case b64JSON = "b64_json"
    }
}
