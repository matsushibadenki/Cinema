import Foundation

struct GeminiVideoService {
    enum ServiceError: LocalizedError {
        case missingAPIKey
        case invalidURL
        case requestFailed(String)
        case operationNotFound
        case videoNotFound

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Gemini APIキーが設定されていません。設定画面で入力してください。"
            case .invalidURL:
                return "Veo APIのURLを作成できませんでした。"
            case .requestFailed(let message):
                return message
            case .operationNotFound:
                return "動画生成ジョブの操作IDが見つかりませんでした。"
            case .videoNotFound:
                return "生成結果内に動画URIが見つかりませんでした。"
            }
        }
    }

    var apiKey: String
    var model: String

    func generateSceneVideo(
        prompt: String,
        durationSeconds: Int,
        aspectRatio: String,
        referenceImages: [GeminiReferenceImage]
    ) async throws -> Data {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.missingAPIKey
        }

        let encodedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
        guard let startURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):predictLongRunning") else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: startURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(GeminiVideoRequest(
            instances: [
                GeminiVideoInstance(
                    prompt: prompt,
                    referenceImages: Array(referenceImages.prefix(3)).map {
                        GeminiVideoReferenceImage(
                            image: GeminiVideoImage(inlineData: GeminiInlineData(mimeType: $0.mimeType, data: $0.data.base64EncodedString())),
                            referenceType: "asset"
                        )
                    }
                )
            ],
            parameters: GeminiVideoParameters(
                aspectRatio: aspectRatio,
                durationSeconds: "\(durationSeconds)",
                numberOfVideos: 1,
                resolution: "720p"
            )
        ))

        let (operationData, operationResponse) = try await URLSession.shared.data(for: request)
        if let httpResponse = operationResponse as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw ServiceError.requestFailed(String(data: operationData, encoding: .utf8) ?? "Veo request failed.")
        }

        let operation = try JSONDecoder().decode(GeminiVideoOperation.self, from: operationData)
        guard let operationName = operation.name, !operationName.isEmpty else {
            throw ServiceError.operationNotFound
        }

        let status = try await pollOperation(name: operationName)
        guard let videoURI = status.response?.generateVideoResponse?.generatedSamples?.first?.video?.uri,
              let url = URL(string: videoURI) else {
            throw ServiceError.videoNotFound
        }

        var downloadRequest = URLRequest(url: url)
        downloadRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        let (videoData, videoResponse) = try await URLSession.shared.data(for: downloadRequest)
        if let httpResponse = videoResponse as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw ServiceError.requestFailed(String(data: videoData, encoding: .utf8) ?? "Video download failed.")
        }

        return videoData
    }

    private func pollOperation(name: String) async throws -> GeminiVideoOperation {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/\(name)") else {
            throw ServiceError.invalidURL
        }

        for _ in 0..<45 {
            var request = URLRequest(url: url)
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                throw ServiceError.requestFailed(String(data: data, encoding: .utf8) ?? "Veo operation polling failed.")
            }

            let operation = try JSONDecoder().decode(GeminiVideoOperation.self, from: data)
            if operation.done == true {
                return operation
            }

            try await Task.sleep(nanoseconds: 10_000_000_000)
        }

        throw ServiceError.requestFailed("動画生成がタイムアウトしました。しばらくしてからもう一度お試しください。")
    }
}

private struct GeminiVideoRequest: Encodable {
    var instances: [GeminiVideoInstance]
    var parameters: GeminiVideoParameters
}

private struct GeminiVideoInstance: Encodable {
    var prompt: String
    var referenceImages: [GeminiVideoReferenceImage]
}

private struct GeminiVideoReferenceImage: Encodable {
    var image: GeminiVideoImage
    var referenceType: String
}

private struct GeminiVideoImage: Encodable {
    var inlineData: GeminiInlineData
}

private struct GeminiVideoParameters: Encodable {
    var aspectRatio: String
    var durationSeconds: String
    var numberOfVideos: Int
    var resolution: String
}

private struct GeminiVideoOperation: Decodable {
    var name: String?
    var done: Bool?
    var response: GeminiVideoOperationResponse?
}

private struct GeminiVideoOperationResponse: Decodable {
    var generateVideoResponse: GeminiGenerateVideoResponse?
}

private struct GeminiGenerateVideoResponse: Decodable {
    var generatedSamples: [GeminiGeneratedVideoSample]?
}

private struct GeminiGeneratedVideoSample: Decodable {
    var video: GeminiGeneratedVideo?
}

private struct GeminiGeneratedVideo: Decodable {
    var uri: String?
}
