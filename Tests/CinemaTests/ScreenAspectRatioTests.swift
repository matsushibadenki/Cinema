import XCTest
@testable import Cinema

final class ScreenAspectRatioTests: XCTestCase {
    func testCustomRatioUsesEnteredDimensions() {
        XCTAssertEqual(
            ScreenAspectRatio.custom.ratio(customWidth: 2048, customHeight: 858),
            CGFloat(2048) / CGFloat(858),
            accuracy: 0.0001
        )
    }

    func testCustomRatioClampsInvalidDimensions() {
        XCTAssertEqual(
            ScreenAspectRatio.custom.ratio(customWidth: 0, customHeight: 0),
            1
        )
    }
}
