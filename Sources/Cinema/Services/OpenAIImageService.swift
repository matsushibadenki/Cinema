// file:///Users/Shared/Program/Xcode/Cinema/Sources/Cinema/Services/OpenAIImageService.swift
// OpenAIImageService.swift
// OpenAI DALL-E APIを利用してテキストプロンプトからコンテ画像を生成するサービス

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
        drawingPrompt: String,
        cutPrompt: String,
        aspectRatio: CGFloat,
        referenceImages: [OpenAIImageReference]
    ) async throws -> Data {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.missingAPIKey
        }

        let usesReferences = !referenceImages.isEmpty
        guard let url = URL(string: usesReferences
            ? "https://api.openai.com/v1/images/edits"
            : "https://api.openai.com/v1/images/generations") else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let prompt = composedPrompt(
            drawingPrompt: drawingPrompt,
            cutPrompt: cutPrompt,
            aspectRatio: aspectRatio
        )
        if usesReferences {
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = multipartBody(
                boundary: boundary,
                fields: [
                    "model": model,
                    "prompt": prompt,
                    "size": imageSize(for: aspectRatio),
                    "quality": "high"
                ],
                images: Array(referenceImages.prefix(5))
            )
        } else {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(OpenAIImageRequest(
                model: model,
                prompt: prompt,
                size: imageSize(for: aspectRatio),
                quality: "high",
                n: 1
            ))
        }

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

    private func composedPrompt(drawingPrompt: String, cutPrompt: String, aspectRatio: CGFloat) -> String {
        let basePrompt = """
        Create a production-ready cinematic frame or storyboard image based on the written situation and dialogue.
        The drawing settings are authoritative for visual medium, style, color, lighting, camera, and texture.
        Show clear character placement, location, mood, and action. Do not render any text, captions, speech bubbles, or UI elements inside the image.
        """

        return [
            "Base image direction:",
            basePrompt,
            "",
            "Drawing settings:",
            drawingPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
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

    private func multipartBody(
        boundary: String,
        fields: [String: String],
        images: [OpenAIImageReference]
    ) -> Data {
        var body = Data()
        for (name, value) in fields {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.appendString("\(value)\r\n")
        }
        for (index, image) in images.enumerated() {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"image[]\"; filename=\"reference-\(index).\(image.fileExtension)\"\r\n")
            body.appendString("Content-Type: \(image.mimeType)\r\n\r\n")
            body.append(image.data)
            body.appendString("\r\n")
        }
        body.appendString("--\(boundary)--\r\n")
        return body
    }

    static func fetchAvailableModels(apiKey: String) async throws -> [String] {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "OpenAI API models request failed."
            throw ServiceError.requestFailed(message)
        }

        let decoded = try JSONDecoder().decode(OpenAIModelListResponse.self, from: data)
        return (decoded.data ?? []).map { $0.id }
    }
}


private struct OpenAIImageRequest: Encodable {
    var model: String
    var prompt: String
    var size: String
    var quality: String
    var n: Int
}

struct OpenAIImageReference {
    var mimeType: String
    var data: Data

    var fileExtension: String {
        switch mimeType {
        case "image/jpeg": return "jpg"
        case "image/webp": return "webp"
        default: return "png"
        }
    }
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

private struct OpenAIModelListResponse: Decodable {
    struct Model: Decodable {
        let id: String
    }
    let data: [Model]?
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
