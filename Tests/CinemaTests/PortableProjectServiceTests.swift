import XCTest
@testable import Cinema

final class PortableProjectServiceTests: XCTestCase {
    func testExternalVideosBecomeIndependentEmbeddedDocument() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let movies = root.appendingPathComponent("movies")
        try FileManager.default.createDirectory(at: movies, withIntermediateDirectories: true)
        let bytes = Data([1, 2, 3, 4])
        try bytes.write(to: movies.appendingPathComponent("clip.mp4"))
        let cut = StoryboardCut(cutNumber: 1)
        let source = StoryboardDocument(project: StoryboardProject(
            sceneVideos: [SceneVideo(title: "Scene", videoFileName: "clip.mp4")],
            generatedCutVideos: [GeneratedCutVideo(sceneTitle: "Scene", cutID: cut.id, videoFileName: "clip.mp4")], cuts: [cut]))
        let copy = try PortableProjectService.prepare(source, documentURL: root.appendingPathComponent("original.cinemaboard"))
        XCTAssertNotEqual(copy.project.id, source.project.id)
        XCTAssertEqual(copy.project.cuts, source.project.cuts)
        XCTAssertEqual(source.project.sceneVideos[0].videoFileName, "clip.mp4")
        XCTAssertEqual(copy.videoData.count, 1)
        XCTAssertEqual(copy.project.sceneVideos[0].videoFileName, copy.project.generatedCutVideos[0].videoFileName)
        let destination = root.appendingPathComponent("copy.cinemaboard")
        try copy.packageWrapper().write(to: destination, options: .atomic, originalContentsURL: nil)
        try FileManager.default.removeItem(at: movies)
        let wrapper = try FileWrapper(url: destination)
        let decoded = try JSONDecoder().decode(StoryboardProject.self, from: XCTUnwrap(wrapper.fileWrappers?["storyboard.json"]?.regularFileContents))
        let embedded = StoryboardDocument.readData(from: try XCTUnwrap(wrapper.fileWrappers?["Videos"]), prefix: "Videos")
        XCTAssertEqual(embedded[decoded.sceneVideos[0].videoFileName], bytes)
    }

    func testMissingVideoFailsWithoutChangingSource() throws {
        let source = StoryboardDocument(project: StoryboardProject(sceneVideos: [SceneVideo(title: "Scene", videoFileName: "missing.mp4")]))
        XCTAssertThrowsError(try PortableProjectService.prepare(source, documentURL: nil))
        XCTAssertTrue(source.videoData.isEmpty)
    }

    func testEmbeddedVideosNeedNoOriginalLocation() throws {
        let source = StoryboardDocument(project: StoryboardProject(sceneVideos: [SceneVideo(title: "Scene", videoFileName: "Videos/old.mp4")]), videoData: ["Videos/old.mp4": Data([9])])
        let copy = try PortableProjectService.prepare(source, documentURL: nil)
        XCTAssertEqual(copy.videoData[copy.project.sceneVideos[0].videoFileName], Data([9]))
    }

    func testCompletedClipNotYetSavedInDocumentIsIncluded() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("original.cinemaboard")
        let cut = StoryboardCut(cutNumber: 1)
        let source = StoryboardDocument(project: StoryboardProject(cuts: [cut]))
        let run = try VideoGenerationRecovery.begin(projectID: source.project.id, sceneID: try XCTUnwrap(source.project.cuts[0].sceneID), title: "Scene", cuts: source.project.cuts, provider: "test", model: "test", documentURL: url)
        let saved = try VideoGenerationRecovery.checkpoint(Data([7]), cutID: cut.id, run: run, documentURL: url)
        let copy = try PortableProjectService.prepare(source, documentURL: url)
        XCTAssertTrue(source.project.generatedCutVideos.isEmpty)
        XCTAssertEqual(copy.project.generatedCutVideos.first?.id, saved.id)
        XCTAssertEqual(copy.videoData[try XCTUnwrap(copy.project.generatedCutVideos.first?.videoFileName)], Data([7]))
    }

    func testSymlinkOutsideMoviesIsRejected() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("movies"), withIntermediateDirectories: true)
        let outside = root.appendingPathComponent("outside.mp4")
        try Data([1]).write(to: outside)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("movies/link.mp4"), withDestinationURL: outside)
        let source = StoryboardDocument(project: StoryboardProject(sceneVideos: [SceneVideo(title: "Scene", videoFileName: "link.mp4")]))
        XCTAssertThrowsError(try PortableProjectService.prepare(source, documentURL: root.appendingPathComponent("original.cinemaboard")))
    }
}
