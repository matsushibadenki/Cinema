import Foundation
import XCTest
@testable import Cinema

final class StoryboardDocumentTests: XCTestCase {
    func testDeletingBlockHeadingPreservesMetadataOnFirstSurvivor() {
        let heading = StoryboardCut(cutNumber: 1, subtitle: "Station", scriptHeading: "EXT", sceneName: "Night")
        let next = StoryboardCut(cutNumber: 2)
        var document = StoryboardDocument(project: StoryboardProject(cuts: [heading, next]))
        document.deleteCuts(withIDs: [heading.id])
        XCTAssertEqual(document.project.cuts.first?.id, next.id)
        XCTAssertEqual(document.project.cuts.first?.subtitle, "Station")
        XCTAssertEqual(document.project.cuts.first?.scriptHeading, "EXT")
        XCTAssertEqual(document.project.cuts.first?.sceneName, "Night")
        XCTAssertEqual(document.project.cuts.first?.cutNumber, 1)
    }

    func testDeletingEntireBlockDoesNotOverwriteNextBlock() {
        let removed = StoryboardCut(cutNumber: 1, subtitle: "Station")
        let next = StoryboardCut(cutNumber: 2, subtitle: "Home")
        var document = StoryboardDocument(project: StoryboardProject(cuts: [removed, next]))
        document.deleteCuts(withIDs: [removed.id])
        XCTAssertEqual(document.project.cuts.first?.subtitle, "Home")
    }

    func testDeletingPagePreservesEachSurvivingBlockAndSharedImage() {
        let first = StoryboardCut(cutNumber: 1, imageFileName: "Images/shared.png", subtitle: "A")
        let second = StoryboardCut(cutNumber: 2, subtitle: "B")
        let third = StoryboardCut(cutNumber: 3, imageFileName: "Images/shared.png")
        var document = StoryboardDocument(
            project: StoryboardProject(cuts: [first, second, third]),
            imageData: ["Images/shared.png": Data([1])]
        )
        document.deleteCuts(withIDs: [first.id, second.id])
        XCTAssertEqual(document.project.cuts.first?.subtitle, "B")
        XCTAssertNotNil(document.imageData["Images/shared.png"])
    }

    func testDeletingLastCutCreatesAnEditableCutAndRemovesUnusedImage() {
        let cut = StoryboardCut(cutNumber: 1, imageFileName: "Images/unused.png")
        var document = StoryboardDocument(
            project: StoryboardProject(cuts: [cut]),
            imageData: ["Images/unused.png": Data([1])]
        )
        document.deleteCuts(withIDs: [cut.id])
        XCTAssertEqual(document.project.cuts.count, 1)
        XCTAssertNotEqual(document.project.cuts[0].id, cut.id)
        XCTAssertNil(document.imageData["Images/unused.png"])
    }

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
