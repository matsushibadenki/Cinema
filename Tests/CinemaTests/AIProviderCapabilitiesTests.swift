import XCTest
@testable import Cinema

final class AIProviderCapabilitiesTests: XCTestCase {
    func testOpenAIDurationNeverProducesUnsupportedSixSeconds() {
        let capabilities = AIProviderCapabilities.video(provider: .openAI, hasReferenceImages: false)

        XCTAssertEqual(capabilities.normalizedDuration(5.8), 4)
        XCTAssertEqual(capabilities.normalizedDuration(6.2), 8)
        XCTAssertEqual(capabilities.normalizedDuration(11), 12)
    }

    func testGeminiReferenceGenerationIsAlwaysEightSeconds() {
        let capabilities = AIProviderCapabilities.video(provider: .gemini, hasReferenceImages: true)

        XCTAssertEqual(capabilities.supportedVideoDurations, [8])
        XCTAssertEqual(capabilities.normalizedDuration(4), 8)
    }

    func testProviderReferenceLimits() {
        XCTAssertEqual(
            AIProviderCapabilities.video(provider: .openAI, hasReferenceImages: true).maximumReferenceImages,
            1
        )
        XCTAssertEqual(
            AIProviderCapabilities.video(provider: .gemini, hasReferenceImages: true).maximumReferenceImages,
            3
        )
    }
}
