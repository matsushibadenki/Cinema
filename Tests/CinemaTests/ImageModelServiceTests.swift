import Foundation
import XCTest
@testable import Cinema

final class ImageModelServiceTests: XCTestCase {
    func testNanoBananaRequestsUseInteractionsAndInline1KImages() throws {
        for model in ["gemini-nano-banana-2.1", "gemini-3.1-flash-lite-image"] {
            let request = try GeminiImageService(apiKey: "test-key", model: model).interactionRequest(
                drawingPrompt: "pencil", cutPrompt: "station", aspectRatio: 1,
                referenceImages: [GeminiReferenceImage(mimeType: "image/png", data: Data([1, 2]))])
            XCTAssertEqual(request.url?.path, "/v1beta/interactions")
            XCTAssertNil(request.url?.query)
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-goog-api-key"), "test-key")
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
            XCTAssertEqual(body["model"] as? String, model)
            XCTAssertEqual(body["store"] as? Bool, false)
            let format = try XCTUnwrap(body["response_format"] as? [String: String])
            XCTAssertEqual(format["image_size"], "1K")
            XCTAssertEqual(format["aspect_ratio"], "1:1")
            let input = try XCTUnwrap(body["input"] as? [[String: String]])
            XCTAssertEqual(input.last?["data"], "AQI=")
            XCTAssertEqual(input.last?["mime_type"], "image/png")
        }
    }

    func testInteractionsReturnsLastGeneratedImageAndExcludesInputs() throws {
        let response = Data(#"{"steps":[{"type":"user_input","content":[{"type":"image","data":"Aw=="}]},{"type":"model_output","content":[{"type":"text","text":"result"},{"type":"image","data":"AQI="},{"type":"image","data":"BA=="}]}]}"#.utf8)
        XCTAssertEqual(try GeminiImageService.interactionImage(from: response), Data([4]))
        XCTAssertThrowsError(try GeminiImageService.interactionImage(from: Data(#"{"steps":[{"type":"user_input","content":[{"type":"image","data":"Aw=="}]}]}"#.utf8)))
    }

    func testGeminiNewModelsRouteToInteractionsAndLegacyKeepsGenerateContent() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ImageTestProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        for model in ["gemini-nano-banana-2.1", "gemini-3.1-flash-lite-image", "gemini-3.1-flash-image"] {
            ImageTestProtocol.handler = { request in
                if model == "gemini-3.1-flash-image" {
                    XCTAssertTrue(request.url!.path.hasSuffix(":generateContent"))
                    return Data(#"{"candidates":[{"content":{"parts":[{"inlineData":{"mimeType":"image/png","data":"AQI="}}]}}]}"#.utf8)
                }
                XCTAssertEqual(request.url?.path, "/v1beta/interactions")
                return Data(#"{"status":"completed","steps":[{"type":"model_output","content":[{"type":"image","data":"AQI="}]}]}"#.utf8)
            }
            let image = try await GeminiImageService(apiKey: "test", model: model, session: session).generateStoryboardImage(
                drawingPrompt: "pencil", cutPrompt: "station", aspectRatio: 1.5, referenceImages: [])
            XCTAssertEqual(image, Data([1, 2]))
        }
    }

    func testOpenAI25GenerationAndReferenceEditing() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ImageTestProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        for model in ["gpt-image-2.5-sunburst", "gpt-image-2.5-flare"] {
            for usesReference in [false, true] {
                ImageTestProtocol.handler = { request in
                    XCTAssertEqual(request.url?.path, usesReference ? "/v1/images/edits" : "/v1/images/generations")
                    let body = try XCTUnwrap(request.httpBody)
                    if usesReference {
                        let text = String(decoding: body, as: UTF8.self)
                        XCTAssertTrue(text.contains(model))
                        XCTAssertTrue(text.contains("image[]"))
                    } else {
                        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                        XCTAssertEqual(json["model"] as? String, model)
                        XCTAssertEqual(json["quality"] as? String, "high")
                        XCTAssertEqual(json["size"] as? String, "1536x1024")
                    }
                    return Data(#"{"data":[{"b64_json":"AQI="}]}"#.utf8)
                }
                let image = try await OpenAIImageService(apiKey: "test", model: model, session: session).generateStoryboardImage(
                    drawingPrompt: "pencil", cutPrompt: "station", aspectRatio: 1.5,
                    referenceImages: usesReference ? [OpenAIImageReference(mimeType: "image/png", data: Data([3]))] : [])
                XCTAssertEqual(image, Data([1, 2]))
            }
        }
    }
}

private final class ImageTestProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> Data)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            var captured = request
            if captured.httpBody == nil, let stream = captured.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var body = Data()
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    body.append(buffer, count: count)
                }
                captured.httpBody = body
            }
            let data = try Self.handler!(captured)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
