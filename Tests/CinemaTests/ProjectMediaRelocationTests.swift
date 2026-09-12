import XCTest
@testable import Cinema

final class ProjectMediaRelocationTests: XCTestCase {
    func testCopyPreservesSourceAndSkipsOtherProjects() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source/project.cinemaboard")
        let target = root.appendingPathComponent("target/project.cinemaboard")
        let movies = source.deletingLastPathComponent().appendingPathComponent("movies")
        try FileManager.default.createDirectory(at: movies, withIntermediateDirectories: true)
        try Data([1]).write(to: movies.appendingPathComponent("clip.mp4"))
        try Data([2]).write(to: movies.appendingPathComponent("unrelated.mp4"))
        let document = StoryboardDocument(project: StoryboardProject(sceneVideos: [SceneVideo(title: "Scene", videoFileName: "clip.mp4")]))
        try ProjectMediaRelocation.copyMedia(for: document, from: source, to: target)
        try ProjectMediaRelocation.copyMedia(for: document, from: source, to: target)
        XCTAssertEqual(try Data(contentsOf: target.deletingLastPathComponent().appendingPathComponent("movies/clip.mp4")), Data([1]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: movies.appendingPathComponent("clip.mp4").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.deletingLastPathComponent().appendingPathComponent("movies/unrelated.mp4").path))
    }

    func testConflictNeverOverwritesDestination() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["source", "target"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent("\(name)/movies"), withIntermediateDirectories: true)
        }
        let sourceFile = root.appendingPathComponent("source/movies/clip.mp4")
        let targetFile = root.appendingPathComponent("target/movies/clip.mp4")
        try Data([1]).write(to: sourceFile)
        try Data([2]).write(to: targetFile)
        let document = StoryboardDocument(project: StoryboardProject(sceneVideos: [SceneVideo(title: "Scene", videoFileName: "clip.mp4")]))
        XCTAssertThrowsError(try ProjectMediaRelocation.copyMedia(for: document, from: root.appendingPathComponent("source/doc.cinemaboard"), to: root.appendingPathComponent("target/doc.cinemaboard")))
        XCTAssertEqual(try Data(contentsOf: targetFile), Data([2]))
    }

    func testJournalAndLaterCompletedClipsFollowRelocation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source/doc.cinemaboard")
        let target = root.appendingPathComponent("target/doc.cinemaboard")
        let document = StoryboardDocument()
        let run = try VideoGenerationRecovery.begin(projectID: document.project.id, sceneID: try XCTUnwrap(document.project.cuts.first?.sceneID), title: "Scene", cuts: document.project.cuts, provider: "test", model: "test", documentURL: source)
        try ProjectMediaRelocation.copyMedia(for: document, from: source, to: target)
        _ = try VideoGenerationRecovery.checkpoint(Data([8]), cutID: document.project.cuts[0].id, run: run, documentURL: source)
        try ProjectMediaRelocation.copyMedia(for: document, from: source, to: target)
        let report = VideoGenerationRecovery.scan(projectID: document.project.id, documentURL: target)
        XCTAssertEqual(report.runs.first?.clips.count, 1)
        XCTAssertEqual(report.unreadableRunCount, 0)
    }
}
