import Foundation
import XCTest
@testable import Cinema

final class VideoGenerationRecoveryTests: XCTestCase {
    private var root: URL!
    private var documentURL: URL { root.appendingPathComponent("Film.cinemaboard") }

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("CinemaRecoveryTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    private func start(_ project: StoryboardProject) throws -> VideoGenerationRun {
        try VideoGenerationRecovery.begin(projectID: project.id, sceneID: XCTUnwrap(project.cuts[0].sceneID), title: "Room", cuts: project.cuts, provider: "test", model: "test-model", documentURL: documentURL)
    }

    func testCompletedClipRecoveredAfterFailureAndUnsavedDocumentExit() throws {
        let original = StoryboardProject(cuts: [StoryboardCut(cutNumber: 1, subtitle: "Room"), StoryboardCut(cutNumber: 2)])
        let savedDocument = try JSONEncoder().encode(original)
        let run = try start(original)
        let clip = try VideoGenerationRecovery.checkpoint(Data([1, 2, 3]), cutID: original.cuts[0].id, run: run, documentURL: documentURL)
        // The second provider request fails and the app exits before autosave.
        var reopened = try JSONDecoder().decode(StoryboardProject.self, from: savedDocument)
        let report = VideoGenerationRecovery.scan(projectID: reopened.id, documentURL: documentURL)
        XCTAssertEqual(report.unreadableRunCount, 0)
        XCTAssertEqual(report.runs.count, 1)
        XCTAssertFalse(report.runs[0].canAssemble)
        XCTAssertEqual(VideoGenerationRecovery.restore(report, into: &reopened), 1)
        XCTAssertEqual(reopened.generatedCutVideos[0].id, clip.id)
        XCTAssertEqual(VideoGenerationRecovery.restore(report, into: &reopened), 0)
    }

    func testCheckpointIsIdempotentAndRejectsEmptyClips() throws {
        let project = StoryboardProject(cuts: [StoryboardCut(cutNumber: 1)])
        let run = try start(project)
        XCTAssertThrowsError(try VideoGenerationRecovery.checkpoint(Data(), cutID: project.cuts[0].id, run: run, documentURL: documentURL))
        let first = try VideoGenerationRecovery.checkpoint(Data([1]), cutID: project.cuts[0].id, run: run, documentURL: documentURL)
        let second = try VideoGenerationRecovery.checkpoint(Data([2]), cutID: project.cuts[0].id, run: run, documentURL: documentURL)
        XCTAssertEqual(first.id, second.id)
        let url = try XCTUnwrap(GeneratedVideoStorageService.fileURL(for: first.videoFileName, documentURL: documentURL))
        XCTAssertEqual(try Data(contentsOf: url), Data([1]))
    }

    func testIncompleteRunCannotProduceCombinedScene() throws {
        let project = StoryboardProject(cuts: [StoryboardCut(cutNumber: 1), StoryboardCut(cutNumber: 2)])
        let run = try start(project)
        _ = try VideoGenerationRecovery.checkpoint(Data([1]), cutID: project.cuts[0].id, run: run, documentURL: documentURL)
        XCTAssertThrowsError(try VideoGenerationRecovery.finish(Data([2]), run: run, documentURL: documentURL))
        XCTAssertNil(VideoGenerationRecovery.scan(projectID: project.id, documentURL: documentURL).runs.first?.sceneVideo)
    }

    func testAssemblyFailurePreservesAllClipsAndCanRetryWithoutGeneration() async throws {
        var project = StoryboardProject(cuts: [StoryboardCut(cutNumber: 1), StoryboardCut(cutNumber: 2)])
        let run = try start(project)
        for (index, cut) in project.cuts.enumerated() {
            _ = try VideoGenerationRecovery.checkpoint(Data([UInt8(index)]), cutID: cut.id, run: run, documentURL: documentURL)
        }
        let recovered = try XCTUnwrap(VideoGenerationRecovery.scan(projectID: project.id, documentURL: documentURL).runs.first)
        do {
            _ = try await VideoGenerationRecovery.assemble(recovered, documentURL: documentURL) { _ in throw CocoaError(.fileWriteUnknown) }
            XCTFail("Assembly should fail")
        } catch {}
        let retry = try XCTUnwrap(VideoGenerationRecovery.scan(projectID: project.id, documentURL: documentURL).runs.first)
        XCTAssertTrue(retry.canAssemble)
        let scene = try await VideoGenerationRecovery.assemble(retry, documentURL: documentURL) { clips in
            XCTAssertEqual(clips, [Data([0]), Data([1])])
            return Data([5, 6])
        }
        let report = VideoGenerationRecovery.scan(projectID: project.id, documentURL: documentURL)
        VideoGenerationRecovery.restore(report, into: &project)
        XCTAssertEqual(project.sceneVideos[0].id, scene.id)
        XCTAssertEqual(project.generatedCutVideos.count, 2)
    }

    func testCancelledAssemblyLeavesCompletedClipsRecoverable() async throws {
        let project = StoryboardProject(cuts: [StoryboardCut(cutNumber: 1)])
        let run = try start(project)
        _ = try VideoGenerationRecovery.checkpoint(Data([1]), cutID: project.cuts[0].id, run: run, documentURL: documentURL)
        let recovered = try XCTUnwrap(VideoGenerationRecovery.scan(projectID: project.id, documentURL: documentURL).runs.first)
        let url = documentURL
        let task = Task {
            try await VideoGenerationRecovery.assemble(recovered, documentURL: url) { _ in
                throw CancellationError()
            }
        }
        do { _ = try await task.value; XCTFail("Should cancel") } catch is CancellationError {} catch { XCTFail("\(error)") }
        XCTAssertEqual(VideoGenerationRecovery.scan(projectID: project.id, documentURL: url).runs[0].clips.count, 1)
    }

    func testRecoveryDoesNotResurrectDeletedCutsOrCrossProjects() throws {
        var project = StoryboardProject(cuts: [StoryboardCut(cutNumber: 1), StoryboardCut(cutNumber: 2)])
        let run = try start(project)
        _ = try VideoGenerationRecovery.checkpoint(Data([1]), cutID: project.cuts[0].id, run: run, documentURL: documentURL)
        let report = VideoGenerationRecovery.scan(projectID: project.id, documentURL: documentURL)
        project.cuts.removeFirst()
        XCTAssertEqual(VideoGenerationRecovery.restore(report, into: &project), 0)
        var other = StoryboardProject(cuts: project.cuts)
        XCTAssertEqual(VideoGenerationRecovery.restore(report, into: &other), 0)
        XCTAssertTrue(VideoGenerationRecovery.scan(projectID: other.id, documentURL: documentURL).runs.isEmpty)
    }

    func testCorruptClipDoesNotHideOtherCompletedClips() throws {
        let project = StoryboardProject(cuts: [StoryboardCut(cutNumber: 1), StoryboardCut(cutNumber: 2)])
        let run = try start(project)
        let first = try VideoGenerationRecovery.checkpoint(Data([1]), cutID: project.cuts[0].id, run: run, documentURL: documentURL)
        _ = try VideoGenerationRecovery.checkpoint(Data([2]), cutID: project.cuts[1].id, run: run, documentURL: documentURL)
        let url = try XCTUnwrap(GeneratedVideoStorageService.fileURL(for: first.videoFileName, documentURL: documentURL))
        try Data().write(to: url)
        let report = VideoGenerationRecovery.scan(projectID: project.id, documentURL: documentURL)
        XCTAssertEqual(report.unreadableRunCount, 1)
        XCTAssertEqual(report.runs[0].clips.map(\.cutID), [project.cuts[1].id])
        XCTAssertFalse(report.runs[0].canAssemble)
    }
}
