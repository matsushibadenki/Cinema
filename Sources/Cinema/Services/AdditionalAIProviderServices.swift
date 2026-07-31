import Foundation

struct OpenAICompatibleImageService {
    enum ServiceError: LocalizedError {
        case missingAPIKey(String)
        case invalidURL(String)
        case requestFailed(String)
        case imageNotFound(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey(let provider):
                return "\(provider) APIキーが設定されていません。設定画面で入力してください。"
            case .invalidURL(let provider):
                return "\(provider) APIのURLを作成できませんでした。"
            case .requestFailed(let message):
                return message
            case .imageNotFound(let provider):
                return "\(provider) のレスポンス内に画像データが見つかりませんでした。"
            }
        }
    }

    var providerName: String
    var apiKey: String
    var model: String
    var baseURL: String

    func generateStoryboardImage(
        drawingPrompt: String,
        cutPrompt: String,
        aspectRatio: CGFloat
    ) async throws -> Data {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.missingAPIKey(providerName)
        }

        guard let url = URL(string: "\(baseURL)/images/generations") else {
            throw ServiceError.invalidURL(providerName)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(OpenAICompatibleImageRequest(
            model: model,
            prompt: composedPrompt(
                drawingPrompt: drawingPrompt,
                cutPrompt: cutPrompt,
                aspectRatio: aspectRatio
            ),
            size: imageSize(for: aspectRatio),
            n: 1,
            responseFormat: "b64_json"
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "\(providerName) image request failed."
            throw ServiceError.requestFailed(message)
        }

        let decoded = try JSONDecoder().decode(OpenAICompatibleImageResponse.self, from: data)
        guard let imageBase64 = decoded.data.first?.b64JSON,
              let image = Data(base64Encoded: imageBase64) else {
            throw ServiceError.imageNotFound(providerName)
        }

        return image
    }

    private func composedPrompt(drawingPrompt: String, cutPrompt: String, aspectRatio: CGFloat) -> String {
        [
            "Create a production-ready cinematic frame or storyboard image.",
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
}

struct DeepInfraCatalogService {
    enum ServiceError: LocalizedError {
        case invalidURL
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "DeepInfraのモデル一覧URLを作成できませんでした。"
            case .requestFailed(let message):
                return message
            }
        }
    }

    static func fetchImageModels() async throws -> [String] {
        try await fetchModels(filter: { model in
            let type = model.type.lowercased()
            let reported = model.reportedType.lowercased()
            return type.contains("text-to-image") || reported.contains("text-to-image") || reported.contains("image-generation")
        })
    }

    static func fetchVideoModels() async throws -> [String] {
        try await fetchModels(filter: { model in
            let type = model.type.lowercased()
            let reported = model.reportedType.lowercased()
            return type.contains("text-to-video") || reported.contains("text-to-video") || reported.contains("video-generation")
        })
    }

    private static func fetchModels(filter: @escaping (DeepInfraModel) -> Bool) async throws -> [String] {
        guard let url = URL(string: "https://api.deepinfra.com/models/list") else {
            throw ServiceError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "DeepInfra models request failed."
            throw ServiceError.requestFailed(message)
        }

        let decoded = try JSONDecoder().decode([DeepInfraModel].self, from: data)
        return decoded
            .filter { !$0.modelName.isEmpty && filter($0) }
            .map(\.modelName)
            .sorted()
    }
}

struct DeepInfraVideoService {
    enum ServiceError: LocalizedError {
        case missingAPIKey
        case invalidURL
        case requestFailed(String)
        case missingVideoURL

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "DeepInfra APIキーが設定されていません。設定画面で入力してください。"
            case .invalidURL:
                return "DeepInfra Video APIのURLを作成できませんでした。"
            case .requestFailed(let message):
                return message
            case .missingVideoURL:
                return "DeepInfraのレスポンス内に動画URLが見つかりませんでした。"
            }
        }
    }

    var apiKey: String
    var model: String

    func generateSceneVideo(prompt: String) async throws -> Data {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.missingAPIKey
        }

        guard let encodedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.deepinfra.com/v1/inference/\(encodedModel)") else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["prompt": prompt])

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "DeepInfra video request failed."
            throw ServiceError.requestFailed(message)
        }

        let decoded = try JSONDecoder().decode(DeepInfraVideoResponse.self, from: data)
        guard let videoURLString = decoded.video, let videoURL = URL(string: videoURLString) else {
            throw ServiceError.missingVideoURL
        }

        let (videoData, _) = try await URLSession.shared.data(from: videoURL)
        return videoData
    }
}

struct NovitaImageService {
    enum ServiceError: LocalizedError {
        case missingAPIKey
        case invalidURL
        case requestFailed(String)
        case taskNotFound
        case imageNotFound
        case timedOut

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Novita APIキーが設定されていません。設定画面で入力してください。"
            case .invalidURL:
                return "Novita Image APIのURLを作成できませんでした。"
            case .requestFailed(let message):
                return message
            case .taskNotFound:
                return "Novitaの画像生成タスクIDが見つかりませんでした。"
            case .imageNotFound:
                return "Novitaのレスポンス内に画像URLが見つかりませんでした。"
            case .timedOut:
                return "Novitaの画像生成がタイムアウトしました。しばらくしてから再度お試しください。"
            }
        }
    }

    var apiKey: String
    var model: String

    func generateStoryboardImage(
        drawingPrompt: String,
        cutPrompt: String,
        aspectRatio: CGFloat
    ) async throws -> Data {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.missingAPIKey
        }

        guard let url = URL(string: "https://api.novita.ai/v3/async/txt2img") else {
            throw ServiceError.invalidURL
        }

        let size = imageSize(for: aspectRatio)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(NovitaImageRequest(
            extra: .init(responseImageType: "png"),
            request: .init(
                modelName: model,
                prompt: composedPrompt(
                    drawingPrompt: drawingPrompt,
                    cutPrompt: cutPrompt,
                    aspectRatio: aspectRatio
                ),
                width: size.width,
                height: size.height,
                imageNum: 1,
                steps: 28,
                guidanceScale: 7.5,
                samplerName: "Euler a",
                negativePrompt: "text, caption, watermark, logo",
                seed: -1
            )
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Novita image request failed."
            throw ServiceError.requestFailed(message)
        }

        let created = try JSONDecoder().decode(NovitaAsyncTaskCreated.self, from: data)
        guard !created.taskID.isEmpty else {
            throw ServiceError.taskNotFound
        }

        let result = try await pollTaskResult(taskID: created.taskID)
        let candidates = result.imageURLs
        guard let imageURLString = candidates.first, let imageURL = URL(string: imageURLString) else {
            throw ServiceError.imageNotFound
        }

        let (imageData, _) = try await URLSession.shared.data(from: imageURL)
        return imageData
    }

    private func pollTaskResult(taskID: String) async throws -> NovitaTaskResult {
        guard let url = URL(string: "https://api.novita.ai/v3/async/task-result?task_id=\(taskID)") else {
            throw ServiceError.invalidURL
        }

        for _ in 0..<60 {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                let message = String(data: data, encoding: .utf8) ?? "Novita task result request failed."
                throw ServiceError.requestFailed(message)
            }

            let result = try JSONDecoder().decode(NovitaTaskResult.self, from: data)
            switch result.task?.status {
            case "TASK_STATUS_SUCCEED":
                return result
            case "TASK_STATUS_FAILED":
                throw ServiceError.requestFailed(result.task?.reason ?? "Novita image generation failed.")
            default:
                try await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }

        throw ServiceError.timedOut
    }

    private func composedPrompt(drawingPrompt: String, cutPrompt: String, aspectRatio: CGFloat) -> String {
        [
            drawingPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
            cutPrompt,
            "Aspect ratio: \(String(format: "%.2f:1", Double(aspectRatio)))"
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }

    private func imageSize(for aspectRatio: CGFloat) -> (width: Int, height: Int) {
        aspectRatio >= 1 ? (1536, 1024) : (1024, 1536)
    }
}

struct NovitaVideoService {
    enum ServiceError: LocalizedError {
        case missingAPIKey
        case invalidURL
        case requestFailed(String)
        case taskNotFound
        case videoNotFound
        case timedOut

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Novita APIキーが設定されていません。設定画面で入力してください。"
            case .invalidURL:
                return "Novita Video APIのURLを作成できませんでした。"
            case .requestFailed(let message):
                return message
            case .taskNotFound:
                return "Novitaの動画生成タスクIDが見つかりませんでした。"
            case .videoNotFound:
                return "Novitaのレスポンス内に動画URLが見つかりませんでした。"
            case .timedOut:
                return "Novitaの動画生成がタイムアウトしました。しばらくしてから再度お試しください。"
            }
        }
    }

    var apiKey: String
    var model: String

    func generateSceneVideo(
        prompt: String,
        durationSeconds: Int,
        aspectRatio: String
    ) async throws -> Data {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.missingAPIKey
        }

        guard let url = URL(string: "https://api.novita.ai/v3/async/txt2video") else {
            throw ServiceError.invalidURL
        }

        let size = videoSize(for: aspectRatio)
        let frames = frames(for: durationSeconds)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(NovitaVideoRequest(
            modelName: model,
            height: size.height,
            width: size.width,
            steps: 20,
            prompts: [.init(frames: frames, prompt: prompt)],
            negativePrompt: "text, caption, watermark, logo",
            guidanceScale: 6.5,
            seed: -1
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Novita video request failed."
            throw ServiceError.requestFailed(message)
        }

        let created = try JSONDecoder().decode(NovitaAsyncTaskCreated.self, from: data)
        guard !created.taskID.isEmpty else {
            throw ServiceError.taskNotFound
        }

        let result = try await pollTaskResult(taskID: created.taskID)
        guard let videoURLString = result.videoURLs.first,
              let videoURL = URL(string: videoURLString) else {
            throw ServiceError.videoNotFound
        }

        let (videoData, _) = try await URLSession.shared.data(from: videoURL)
        return videoData
    }

    private func pollTaskResult(taskID: String) async throws -> NovitaTaskResult {
        guard let url = URL(string: "https://api.novita.ai/v3/async/task-result?task_id=\(taskID)") else {
            throw ServiceError.invalidURL
        }

        for _ in 0..<90 {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
                let message = String(data: data, encoding: .utf8) ?? "Novita task result request failed."
                throw ServiceError.requestFailed(message)
            }

            let result = try JSONDecoder().decode(NovitaTaskResult.self, from: data)
            switch result.task?.status {
            case "TASK_STATUS_SUCCEED":
                return result
            case "TASK_STATUS_FAILED":
                throw ServiceError.requestFailed(result.task?.reason ?? "Novita video generation failed.")
            default:
                try await Task.sleep(nanoseconds: 6_000_000_000)
            }
        }

        throw ServiceError.timedOut
    }

    private func videoSize(for aspectRatio: String) -> (width: Int, height: Int) {
        aspectRatio == "9:16" ? (576, 1024) : (1024, 576)
    }

    private func frames(for durationSeconds: Int) -> Int {
        switch durationSeconds {
        case 8...: return 64
        case 6...: return 48
        default: return 32
        }
    }
}

struct HyperbolicImageService {
    enum ServiceError: LocalizedError {
        case missingAPIKey
        case invalidURL
        case requestFailed(String)
        case imageNotFound

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Hyperbolic APIキーが設定されていません。設定画面で入力してください。"
            case .invalidURL:
                return "Hyperbolic Image APIのURLを作成できませんでした。"
            case .requestFailed(let message):
                return message
            case .imageNotFound:
                return "Hyperbolicのレスポンス内に画像データが見つかりませんでした。"
            }
        }
    }

    var apiKey: String
    var model: String

    func generateStoryboardImage(
        drawingPrompt: String,
        cutPrompt: String,
        aspectRatio: CGFloat
    ) async throws -> Data {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.missingAPIKey
        }

        guard let url = URL(string: "https://api.hyperbolic.xyz/v1/image/generation") else {
            throw ServiceError.invalidURL
        }

        let size = imageSize(for: aspectRatio)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(HyperbolicImageRequest(
            modelName: model,
            prompt: [
                drawingPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
                cutPrompt
            ]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n"),
            height: size.height,
            width: size.width,
            backend: "auto"
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Hyperbolic image request failed."
            throw ServiceError.requestFailed(message)
        }

        let decoded = try JSONDecoder().decode(HyperbolicImageResponse.self, from: data)
        guard let imageBase64 = decoded.images.first?.image,
              let image = Data(base64Encoded: imageBase64) else {
            throw ServiceError.imageNotFound
        }

        return image
    }

    private func imageSize(for aspectRatio: CGFloat) -> (width: Int, height: Int) {
        aspectRatio >= 1 ? (1536, 1024) : (1024, 1536)
    }
}

private struct OpenAICompatibleImageRequest: Encodable {
    var model: String
    var prompt: String
    var size: String
    var n: Int
    var responseFormat: String

    private enum CodingKeys: String, CodingKey {
        case model, prompt, size, n
        case responseFormat = "response_format"
    }
}

private struct OpenAICompatibleImageResponse: Decodable {
    var data: [OpenAICompatibleImageData]
}

private struct OpenAICompatibleImageData: Decodable {
    var b64JSON: String?

    private enum CodingKeys: String, CodingKey {
        case b64JSON = "b64_json"
    }
}

private struct DeepInfraModel: Decodable {
    var modelName: String
    var type: String
    var reportedType: String

    private enum CodingKeys: String, CodingKey {
        case modelName = "model_name"
        case type
        case reportedType = "reported_type"
    }
}

private struct DeepInfraVideoResponse: Decodable {
    var video: String?
}

private struct NovitaImageRequest: Encodable {
    struct Extra: Encodable {
        var responseImageType: String

        private enum CodingKeys: String, CodingKey {
            case responseImageType = "response_image_type"
        }
    }

    struct RequestBody: Encodable {
        var modelName: String
        var prompt: String
        var width: Int
        var height: Int
        var imageNum: Int
        var steps: Int
        var guidanceScale: Double
        var samplerName: String
        var negativePrompt: String
        var seed: Int

        private enum CodingKeys: String, CodingKey {
            case modelName = "model_name"
            case prompt, width, height, steps, seed
            case imageNum = "image_num"
            case guidanceScale = "guidance_scale"
            case samplerName = "sampler_name"
            case negativePrompt = "negative_prompt"
        }
    }

    var extra: Extra
    var request: RequestBody
}

private struct NovitaVideoRequest: Encodable {
    struct PromptFrame: Encodable {
        var frames: Int
        var prompt: String
    }

    var modelName: String
    var height: Int
    var width: Int
    var steps: Int
    var prompts: [PromptFrame]
    var negativePrompt: String
    var guidanceScale: Double
    var seed: Int

    private enum CodingKeys: String, CodingKey {
        case height, width, steps, prompts, seed
        case modelName = "model_name"
        case negativePrompt = "negative_prompt"
        case guidanceScale = "guidance_scale"
    }
}

private struct NovitaAsyncTaskCreated: Decodable {
    var taskID: String

    private enum CodingKeys: String, CodingKey {
        case taskID = "task_id"
    }
}

private struct NovitaTaskResult: Decodable {
    struct Task: Decodable {
        var status: String?
        var reason: String?
    }

    struct ImageItem: Decodable {
        var imageURL: String?
        var imageFile: String?
        var image: String?

        private enum CodingKeys: String, CodingKey {
            case imageURL = "image_url"
            case imageFile = "image_file"
            case image
        }
    }

    struct VideoItem: Decodable {
        var videoURL: String?

        private enum CodingKeys: String, CodingKey {
            case videoURL = "video_url"
        }
    }

    var task: Task?
    var images: [ImageItem]?
    var imgs: [String]?
    var videos: [VideoItem]?

    var imageURLs: [String] {
        if let imgs, !imgs.isEmpty { return imgs }
        return (images ?? []).compactMap { $0.imageURL ?? $0.imageFile ?? $0.image }
    }

    var videoURLs: [String] {
        (videos ?? []).compactMap(\.videoURL)
    }
}

private struct HyperbolicImageRequest: Encodable {
    var modelName: String
    var prompt: String
    var height: Int
    var width: Int
    var backend: String

    private enum CodingKeys: String, CodingKey {
        case prompt, height, width, backend
        case modelName = "model_name"
    }
}

private struct HyperbolicImageResponse: Decodable {
    struct ImageItem: Decodable {
        var image: String?
    }

    var images: [ImageItem]
}
