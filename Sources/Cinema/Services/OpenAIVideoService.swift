import Foundation

struct OpenAIVideoService {
    enum ServiceError: LocalizedError {
        case missingAPIKey
        case invalidURL
        case requestFailed(String)
        case jobNotFound
        case videoNotReady

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "OpenAI APIキーが設定されていません。設定画面で入力してください。"
            case .invalidURL:
                return "OpenAI Video APIのURLを作成できませんでした。"
            case .requestFailed(let message):
                return message
            case .jobNotFound:
                return "動画生成ジョブのIDが見つかりませんでした。"
            case .videoNotReady:
                return "動画生成がタイムアウトしました。しばらくしてからもう一度お試しください。"
            }
        }
    }

    var apiKey: String
    var model: String

    func generateSceneVideo(
        prompt: String,
        durationSeconds: Int,
        aspectRatio: String,
        inputReference: OpenAIVideoReferenceImage?
    ) async throws -> Data {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.missingAPIKey
        }

        guard let url = URL(string: "https://api.openai.com/v1/videos") else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let size = videoSize(for: aspectRatio)
        if let inputReference {
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = multipartBody(
                boundary: boundary,
                fields: [
                    "model": model,
                    "prompt": prompt,
                    "seconds": "\(durationSeconds)",
                    "size": size
                ],
                file: inputReference
            )
        } else {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(OpenAIVideoRequest(
                model: model,
                prompt: prompt,
                seconds: "\(durationSeconds)",
                size: size
            ))
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw ServiceError.requestFailed(String(data: data, encoding: .utf8) ?? "OpenAI Video API request failed.")
        }

        let job = try JSONDecoder().decode(OpenAIVideoJob.self, from: data)
        guard !job.id.isEmpty else {
            throw ServiceError.jobNotFound
        }

        let completed = try await pollVideoJob(id: job.id)
        guard completed.status == "completed" else {
            throw ServiceError.requestFailed(completed.error?.message ?? "OpenAI video generation failed.")
        }

        return try await downloadVideo(id: job.id)
    }

    private func pollVideoJob(id: String) async throws -> OpenAIVideoJob {
        guard let url = URL(string: "https://api.openai.com/v1/videos/\(id)") else {
            throw ServiceError.invalidURL
        }

        for _ in 0..<45 {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                throw ServiceError.requestFailed(String(data: data, encoding: .utf8) ?? "OpenAI video polling failed.")
            }

            let job = try JSONDecoder().decode(OpenAIVideoJob.self, from: data)
            if job.status == "completed" || job.status == "failed" || job.status == "cancelled" {
                return job
            }

            try await Task.sleep(nanoseconds: 10_000_000_000)
        }

        throw ServiceError.videoNotReady
    }

    private func downloadVideo(id: String) async throws -> Data {
        guard let url = URL(string: "https://api.openai.com/v1/videos/\(id)/content") else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw ServiceError.requestFailed(String(data: data, encoding: .utf8) ?? "OpenAI video download failed.")
        }

        return data
    }

    private func videoSize(for aspectRatio: String) -> String {
        aspectRatio == "9:16" ? "720x1280" : "1280x720"
    }

    private func multipartBody(boundary: String, fields: [String: String], file: OpenAIVideoReferenceImage) -> Data {
        var body = Data()
        for (name, value) in fields {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.appendString("\(value)\r\n")
        }

        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"input_reference\"; filename=\"\(file.fileName)\"\r\n")
        body.appendString("Content-Type: \(file.mimeType)\r\n\r\n")
        body.append(file.data)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")
        return body
    }
}

struct OpenAIVideoReferenceImage {
    var fileName: String
    var mimeType: String
    var data: Data
}

private struct OpenAIVideoRequest: Encodable {
    var model: String
    var prompt: String
    var seconds: String
    var size: String
}

private struct OpenAIVideoJob: Decodable {
    var id: String
    var status: String?
    var error: OpenAIVideoError?
}

private struct OpenAIVideoError: Decodable {
    var message: String?
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
