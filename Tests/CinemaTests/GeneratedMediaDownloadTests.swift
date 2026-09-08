import Foundation
import XCTest
@testable import Cinema

final class GeneratedMediaDownloadTests: XCTestCase {
    func testErrorPageIsNotAcceptedAsGeneratedMedia() {
        let response = HTTPURLResponse(url: URL(string: "https://example.com/clip.mp4")!,
                                       statusCode: 403, httpVersion: nil, headerFields: nil)!
        XCTAssertThrowsError(try GeneratedMediaDownload.validated(Data("Expired".utf8), response: response))
    }

    func testSuccessfulNonemptyDownloadIsPreserved() throws {
        let response = HTTPURLResponse(url: URL(string: "https://example.com/clip.mp4")!,
                                       statusCode: 200, httpVersion: nil, headerFields: nil)!
        let data = Data([1, 2, 3])
        XCTAssertEqual(try GeneratedMediaDownload.validated(data, response: response), data)
        XCTAssertThrowsError(try GeneratedMediaDownload.validated(Data(), response: response))
    }
}
