import Foundation
import XCTest
@testable import Cinema

final class StoryboardDocumentTests: XCTestCase {
    func testReadDataRecursesIntoReferenceDirectoryWithoutReadingItAsAFile() {
        let expectedData = Data("reference-image".utf8)
        let referenceFile = FileWrapper(regularFileWithContents: expectedData)
        let referencesDirectory = FileWrapper(directoryWithFileWrappers: ["image.png": referenceFile])
        let imagesDirectory = FileWrapper(directoryWithFileWrappers: ["References": referencesDirectory])

        let result = StoryboardDocument.readData(from: imagesDirectory, prefix: "Images")

        XCTAssertEqual(result, ["Images/References/image.png": expectedData])
    }

    func testReadDataIgnoresUnsupportedFileWrapperTypes() {
        let symbolicLink = FileWrapper(symbolicLinkWithDestinationURL: URL(fileURLWithPath: "/tmp/image.png"))
        let imagesDirectory = FileWrapper(directoryWithFileWrappers: ["image.png": symbolicLink])

        XCTAssertTrue(StoryboardDocument.readData(from: imagesDirectory, prefix: "Images").isEmpty)
    }
}
