import XCTest
@testable import Cinema

final class PerformanceBundleTests: XCTestCase {
    private func fixture(_ folder: URL) throws -> (StoryboardDocument, PerformanceBundleReceipt) {
        let line = DialogueLine(speaker: "Alice", dialogue: "Hello")
        var document = StoryboardDocument(project: StoryboardProject(cuts: [StoryboardCut(cutNumber: 1, dialogueLines: [line])]))
        let cut = document.project.cuts[0]
        let asset = PerformanceAudioAsset(name: "Voice", fileName: "Audio/voice.wav", duration: PerformanceTime(ticks: 96000))
        document.audioData[asset.fileName] = Data([1, 2, 3])
        document.project.performancePlan.audioAssets = [asset]
        document.project.performancePlan.cues = [PerformanceCue(sceneID: try XCTUnwrap(cut.sceneID), cutID: cut.id, dialogueID: line.id, audioAssetID: asset.id, end: PerformanceTime(ticks: 48000))]
        let (url, receipt) = try PerformanceBundleService.export(document: document, sceneID: try XCTUnwrap(cut.sceneID), to: folder)
        let exported = try JSONDecoder().decode(PerformanceSceneBundle.self, from: Data(contentsOf: url.appendingPathComponent("manifest.json")))
        XCTAssertEqual(exported.cuts, document.project.cuts)
        XCTAssertEqual(try Data(contentsOf: url.appendingPathComponent(exported.performance.plan.audioAssets[0].fileName)), Data([1, 2, 3]))
        document.project.performanceBundleReceipts = [receipt]
        XCTAssertEqual(try JSONDecoder().decode(StoryboardProject.self, from: JSONEncoder().encode(document.project)), document.project)
        return (document, receipt)
    }
    private func writeResult(_ receipt: PerformanceBundleReceipt, at folder: URL, outputs: [PerformanceResultOutput]? = nil) throws {
        let alignment = AudioAlignmentFile(audioAssetID: try XCTUnwrap(receipt.cues[0].audioAssetID), segments: [])
        let result = PerformanceResultBundle(sourceBundleID: receipt.bundleID, projectID: receipt.projectID, sceneID: receipt.sceneID, runner: "fixture", modelRevision: "1", outputs: outputs ?? [PerformanceResultOutput(dialogueID: receipt.cues[0].dialogueID, alignment: alignment)])
        try JSONEncoder().encode(result).write(to: folder.appendingPathComponent("manifest.json"))
    }
    func testAlignmentResultPreservesOriginalAndRejectsDuplicate() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var (document, receipt) = try fixture(folder)
        try writeResult(receipt, at: folder)
        let count = try await PerformanceBundleService.importResult(at: folder, into: &document)
        XCTAssertEqual(count, 1)
        XCTAssertEqual(document.project.performancePlan.audioAssets.count, 2)
        XCTAssertEqual(document.project.performancePlan.audioAssets[0].id, receipt.cues[0].audioAssetID)
        XCTAssertNotEqual(document.project.performancePlan.cues[0].audioAssetID, receipt.cues[0].audioAssetID)
        let imported = document.project
        do { _ = try await PerformanceBundleService.importResult(at: folder, into: &document); XCTFail() } catch { }
        XCTAssertEqual(document.project, imported)
    }
    func testChangedDialogueAndAudioRejectWithoutMutation() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let (source, receipt) = try fixture(folder)
        try writeResult(receipt, at: folder)
        for changeAudio in [false, true] {
            var document = source
            if changeAudio { document.audioData["Audio/voice.wav"] = Data([9]) }
            else { document.project.cuts[0].dialogueLines[0].dialogue = "Changed" }
            let before = document.project
            do { _ = try await PerformanceBundleService.importResult(at: folder, into: &document); XCTFail() } catch { }
            XCTAssertEqual(document.project, before)
        }
    }
    func testBackgroundAssetsExportAndChangesRejectResults() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var (document, oldReceipt) = try fixture(folder)
        let bed = PerformanceAudioAsset(name: "Bed", fileName: "Audio/bed.wav", duration: PerformanceTime(ticks: 96000))
        document.audioData[bed.fileName] = Data([4, 5])
        document.project.performancePlan.audioAssets.append(bed)
        document.project.performancePlan.audioClips = [PerformanceAudioClip(sceneID: oldReceipt.sceneID, audioAssetID: bed.id, lane: .ambience, end: PerformanceTime(ticks: 48000))]
        let (url, receipt) = try PerformanceBundleService.export(document: document, sceneID: oldReceipt.sceneID, to: folder)
        let manifest = try JSONDecoder().decode(PerformanceSceneBundle.self, from: Data(contentsOf: url.appendingPathComponent("manifest.json")))
        XCTAssertEqual(manifest.performance.plan.audioClips.count, 1)
        XCTAssertEqual(manifest.performance.plan.audioAssets.count, 2)
        document.project.performanceBundleReceipts.append(receipt)
        try writeResult(receipt, at: folder)
        document.audioData[bed.fileName] = Data([9])
        let before = document.project
        do { _ = try await PerformanceBundleService.importResult(at: folder, into: &document); XCTFail() } catch { }
        XCTAssertEqual(document.project, before)
    }

    func testLaneStateSnapshotRejectsStaleResult() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var (document, oldReceipt) = try fixture(folder)
        document.project.performancePlan.laneStates = [PerformanceLaneState(sceneID: oldReceipt.sceneID, lane: .dialogue, isSolo: true)]
        let (url, receipt) = try PerformanceBundleService.export(document: document, sceneID: oldReceipt.sceneID, to: folder)
        let manifest = try JSONDecoder().decode(PerformanceSceneBundle.self, from: Data(contentsOf: url.appendingPathComponent("manifest.json")))
        XCTAssertEqual(manifest.performance.plan.laneStates, receipt.laneStates)
        document.project.performanceBundleReceipts.append(receipt)
        try writeResult(receipt, at: folder)
        document.project.performancePlan.laneStates[0].isMuted = true
        let before = document.project
        do { _ = try await PerformanceBundleService.importResult(at: folder, into: &document); XCTFail() } catch PerformanceBundleService.BundleError.stale { }
        XCTAssertEqual(document.project, before)
    }

    func testUnsafePathsAndInvalidVideoDoNotCommit() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var (document, receipt) = try fixture(folder)
        XCTAssertThrowsError(try PerformanceBundleService.safeURL("../outside", root: folder))
        let link = folder.appendingPathComponent("escape")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: folder.deletingLastPathComponent())
        XCTAssertThrowsError(try PerformanceBundleService.safeURL("escape/outside", root: folder))
        try Data([1]).write(to: folder.appendingPathComponent("bad.mp4"))
        try writeResult(receipt, at: folder, outputs: [PerformanceResultOutput(dialogueID: receipt.cues[0].dialogueID, videoPath: "bad.mp4")])
        let before = document.project
        do { _ = try await PerformanceBundleService.importResult(at: folder, into: &document); XCTFail() } catch { }
        XCTAssertEqual(document.project, before)
        XCTAssertTrue(document.videoData.isEmpty)
    }
}
