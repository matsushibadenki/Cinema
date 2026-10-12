import XCTest
@testable import Cinema

final class ProjectMediaRelocationTests: XCTestCase {
    @MainActor func testRealVideoRelocationAndReopenedProject() async throws {
        let fixturePath = ProcessInfo.processInfo.environment["CINEMA_RELOCATION_UI_FIXTURE"]
        let root = fixturePath.map { URL(fileURLWithPath: $0) } ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { if fixturePath == nil { try? FileManager.default.removeItem(at: root) } }
        let source = root.appendingPathComponent("original/Relocation QA.cinemaboard")
        let destination = root.appendingPathComponent("copied/Relocation QA.cinemaboard")
        let media = source.deletingLastPathComponent().appendingPathComponent("movies/scene.mp4")
        try FileManager.default.createDirectory(at: media.deletingLastPathComponent(), withIntermediateDirectories: true)
        try await LocalVideoFixture.write(to: media)
        var project = StoryboardProject(cuts: [StoryboardCut(cutNumber: 1, subtitle: "Relocation QA")])
        var video = SceneVideo(title: "Relocation QA", videoFileName: "scene.mp4"); video.sceneID = project.cuts[0].sceneID
        project.sceneVideos = [video]
        let document = StoryboardDocument(project: project)
        try document.packageWrapper().write(to: source, options: .atomic, originalContentsURL: nil)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try document.packageWrapper().write(to: destination, options: .atomic, originalContentsURL: nil)
        try ProjectMediaRelocation.copyMedia(for: document, from: source, to: destination)
        let reopened = try StoryboardDocument(package: FileWrapper(url: destination, options: .immediate))
        let playback = PerformancePreviewPlayer()
        defer { playback.invalidate() }
        try await playback.prepare(project: reopened.project, sceneID: try XCTUnwrap(video.sceneID), audioData: [:], documentURL: destination, includeVideo: true)
        XCTAssertEqual(playback.duration, 1, accuracy: 0.01)
        XCTAssertTrue(FileManager.default.contentsEqual(atPath: media.path, andPath: destination.deletingLastPathComponent().appendingPathComponent("movies/scene.mp4").path))
    }

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
