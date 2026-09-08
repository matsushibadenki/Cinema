import Foundation
import XCTest
@testable import Cinema

final class CinemaResultBundleImporterTests: XCTestCase {
    func testImportsImageAndPreservesRunnerProvenance() throws {
        let cut = StoryboardCut(cutNumber: 1, situation: "A room")
        var document = StoryboardDocument(project: StoryboardProject(title: "Film", cuts: [cut]))
        let root = try makeBundle()
        defer { try? FileManager.default.removeItem(at: root) }
        let imageURL = root.appendingPathComponent("outputs/frame.png")
        try FileManager.default.createDirectory(at: imageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: imageURL)
        let sourceID = UUID()
        try writeManifest(
            CinemaResultBundleManifest(
                format: CinemaResultBundleManifest.format,
                schemaVersion: CinemaResultBundleManifest.schemaVersion,
                sourceBundleID: sourceID,
                sourceProjectTitle: "Film",
                sceneTitle: "Room",
                sceneKey: "room-id",
                runner: "Test Runner",
                modelRevision: "model@abc123",
                effectiveParameters: ["seed": "42"],
                warnings: ["runner warning"],
                generatedAt: Date(timeIntervalSince1970: 100),
                outputs: [CinemaResultOutput(cutID: cut.id, mediaType: .image, path: "outputs/frame.png", warnings: [])]
            ),
            to: root
        )

        let summary = try CinemaResultBundleImporter.importBundle(at: root, into: &document, documentURL: nil)

        XCTAssertEqual(summary.imageCount, 1)
        let storedPath = try XCTUnwrap(document.project.cuts.first?.imageFileName)
        XCTAssertEqual(document.imageData[storedPath], Data([1, 2, 3]))
        XCTAssertEqual(document.project.importedGenerationResults.first?.sourceBundleID, sourceID)
        XCTAssertEqual(document.project.importedGenerationResults.first?.effectiveParameters["seed"], "42")
        XCTAssertThrowsError(try CinemaResultBundleImporter.importBundle(at: root, into: &document, documentURL: nil))
    }

    func testImportsVideoBesideSavedDocument() throws {
        let cut = StoryboardCut(cutNumber: 1, situation: "A room")
        var document = StoryboardDocument(project: StoryboardProject(title: "Film", cuts: [cut]))
        let root = try makeBundle()
        let documentRoot = FileManager.default.temporaryDirectory.appendingPathComponent("CinemaResultDocument-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: documentRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: documentRoot)
        }
        let videoURL = root.appendingPathComponent("outputs/clip.mp4")
        try FileManager.default.createDirectory(at: videoURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([4, 5, 6]).write(to: videoURL)
        try writeManifest(manifest(cutID: cut.id, mediaType: .video, path: "outputs/clip.mp4"), to: root)

        let summary = try CinemaResultBundleImporter.importBundle(
            at: root,
            into: &document,
            documentURL: documentRoot.appendingPathComponent("Film.cinemaboard")
        )

        XCTAssertEqual(summary.videoCount, 1)
        let path = try XCTUnwrap(document.project.generatedCutVideos.first?.videoFileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: documentRoot.appendingPathComponent("movies/\(path)").path))
    }

    func testRejectsUnknownCutAndPathTraversalWithoutMutatingDocument() throws {
        var document = StoryboardDocument(project: StoryboardProject(title: "Film", cuts: [StoryboardCut(cutNumber: 1)]))
        let original = document
        let root = try makeBundle()
        defer { try? FileManager.default.removeItem(at: root) }

        try writeManifest(manifest(cutID: UUID(), mediaType: .image, path: "../secret"), to: root)
        XCTAssertThrowsError(try CinemaResultBundleImporter.importBundle(at: root, into: &document, documentURL: nil))
        XCTAssertEqual(document.project, original.project)
        XCTAssertEqual(document.imageData, original.imageData)
    }

    private func manifest(cutID: UUID, mediaType: CinemaResultOutput.MediaType, path: String) -> CinemaResultBundleManifest {
        CinemaResultBundleManifest(
            format: CinemaResultBundleManifest.format,
            schemaVersion: CinemaResultBundleManifest.schemaVersion,
            sourceBundleID: UUID(),
            sourceProjectTitle: "Film",
            sceneTitle: "Room",
            sceneKey: "room-id",
            runner: "Test Runner",
            modelRevision: "revision",
            effectiveParameters: [:],
            warnings: [],
            generatedAt: Date(timeIntervalSince1970: 100),
            outputs: [CinemaResultOutput(cutID: cutID, mediaType: mediaType, path: path, warnings: [])]
        )
    }

    private func makeBundle() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("CinemaResultBundle-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeManifest(_ manifest: CinemaResultBundleManifest, to root: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: root.appendingPathComponent("manifest.json"))
    }
}
