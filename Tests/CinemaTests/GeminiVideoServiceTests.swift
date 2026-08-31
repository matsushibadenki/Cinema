import Foundation
import XCTest
@testable import Cinema

final class GeminiVideoServiceTests: XCTestCase {
    func testRequestBodyUsesVeoReferenceImageSchema() throws {
        let body = try GeminiVideoService.requestBody(
            prompt: "rainy station",
            durationSeconds: 4,
            aspectRatio: "16:9",
            referenceImages: [
                GeminiReferenceImage(mimeType: "image/png", data: Data([0x01, 0x02]))
            ],
            negativePrompt: "text"
        )

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let instances = try XCTUnwrap(json["instances"] as? [[String: Any]])
        let instance = try XCTUnwrap(instances.first)
        let references = try XCTUnwrap(instance["referenceImages"] as? [[String: Any]])
        let reference = try XCTUnwrap(references.first)
        let image = try XCTUnwrap(reference["image"] as? [String: Any])
        let parameters = try XCTUnwrap(json["parameters"] as? [String: Any])

        XCTAssertEqual(image["bytesBase64Encoded"] as? String, "AQI=")
        XCTAssertEqual(image["mimeType"] as? String, "image/png")
        XCTAssertNil(image["inlineData"])
        XCTAssertEqual(parameters["durationSeconds"] as? Int, 4)
        XCTAssertEqual(parameters["sampleCount"] as? Int, 1)
        XCTAssertNil(parameters["numberOfVideos"])
        XCTAssertNil(parameters["seed"])
    }
}
