import Foundation
import XCTest
@testable import Cinema

final class GeneratedVideoStorageServiceTests: XCTestCase {
    func testStoredPathCannotEscapeMoviesDirectory() {
        let documentURL = URL(fileURLWithPath: "/tmp/Film.cinemaboard")
        XCTAssertNil(GeneratedVideoStorageService.fileURL(for: "../secret.mp4", documentURL: documentURL))
        XCTAssertNil(GeneratedVideoStorageService.fileURL(for: "/tmp/secret.mp4", documentURL: documentURL))
        XCTAssertEqual(
            GeneratedVideoStorageService.fileURL(for: "scene/clip.mp4", documentURL: documentURL)?.path,
            "/tmp/movies/scene/clip.mp4"
        )
    }

    func testPersistWritesSceneAndCutVersions() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CinemaVideoStorage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let cut = StoryboardCut(cutNumber: 1)

        let result = try GeneratedVideoStorageService.persist(
            sceneTitle: "Room/Night",
            cuts: [cut],
            clips: [Data([1])],
            combinedVideoData: Data([2]),
            generatedAt: Date(timeIntervalSince1970: 0),
            documentURL: root.appendingPathComponent("Film.cinemaboard")
        )

        XCTAssertEqual(result.cutVideos.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("movies/\(result.sceneVideoPath)").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("movies/\(result.cutVideos[0].videoFileName)").path))
    }
}
