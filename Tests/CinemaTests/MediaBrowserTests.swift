import XCTest
@testable import Cinema

final class MediaBrowserTests: XCTestCase {
    func testGenerationHistorySurvivesRoundTripAndCutDeletion() throws {
        let cut = StoryboardCut(cutNumber: 1, imageFileName: "Images/history.png")
        var project = StoryboardProject(cuts: [cut])
        let record = GeneratedImage(cutID: cut.id, title: "First", imageFileName: "Images/history.png", prompt: "Original prompt", context: "Original settings", provider: "openAI", model: "image-model", aspectRatio: 1.5)
        project.generatedImages = [record]
        let decoded = try JSONDecoder().decode(StoryboardProject.self, from: JSONEncoder().encode(project))
        XCTAssertEqual(decoded.generatedImages, [record])
        var document = StoryboardDocument(project: decoded, imageData: [record.imageFileName: Data([1, 2])])
        document.deleteCuts(withIDs: [cut.id])
        XCTAssertEqual(document.imageData[record.imageFileName], Data([1, 2]))
        XCTAssertEqual(document.project.generatedImages, [record])
    }

    func testLegacyProjectHasEmptyHistory() throws {
        let data = try JSONEncoder().encode(StoryboardProject())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "generatedImages")
        let decoded = try JSONDecoder().decode(StoryboardProject.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(decoded.generatedImages.isEmpty)
    }

    func testDirectoryListingSortsFoldersFirstAndExcludesHiddenFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Z folder"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data().write(to: root.appendingPathComponent("A.txt"))
        try Data().write(to: root.appendingPathComponent(".hidden"))
        let entries = try BrowserFile.contents(of: root)
        XCTAssertEqual(entries.map { $0.url.lastPathComponent }, ["Z folder", "A.txt"])
        XCTAssertTrue(entries[0].isDirectory)
    }
}
