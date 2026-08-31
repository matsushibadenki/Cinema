import Foundation
import XCTest
@testable import Cinema

final class CinemaSceneBundleExporterTests: XCTestCase {
    func testExportCreatesVersionedPortableBundle() throws {
        let referenceID = UUID(uuidString: "00000000-0000-0000-0000-000000000901")!
        let cutID = UUID(uuidString: "00000000-0000-0000-0000-000000000902")!
        let reference = ReferenceImage(
            id: referenceID,
            name: "Hero wardrobe",
            imageFileName: "hero.webp",
            details: [
                DrawingSettingsSection(
                    title: "Character",
                    fields: [DrawingSettingsField(key: "Wardrobe", value: "blue coat")]
                )
            ]
        )
        let sceneState = SceneState(
            sceneKey: "scene-park",
            title: "Park",
            characterState: SceneStateCategory(title: "Character", summary: "Mika wears a blue coat."),
            persistenceRules: [
                SceneRule(title: "Wardrobe", rule: "Keep the blue coat in every cut.", kind: .persistence)
            ],
            eventGraph: EventGraph(initialStateSummary: "Mika waits beside the fountain.")
        )
        let cut = StoryboardCut(
            id: cutID,
            cutNumber: 1,
            cutName: "Arrival",
            situation: "Mika enters the park.",
            dialogueLines: [DialogueLine(speaker: "Mika", dialogue: "I am here.")],
            duration: "4.5",
            imageFileName: "cut-1.png",
            subtitle: "Block 1",
            scriptHeading: "Sequence A",
            sceneName: "Park",
            referenceImageIDs: [referenceID],
            aiShotSettings: AIShotSettings(shotSize: "medium", seed: 42),
            shotDelta: ShotDelta(
                continuityRequirements: ["Keep the blue coat."],
                cameraObservation: CameraObservation(framingSummary: "Mika centered in frame.")
            )
        )
        let project = StoryboardProject(
            title: "Portable Project",
            projectContext: ProjectContext(defaultFilmProfileID: "film-neutral", defaultSeed: "42"),
            referenceImages: [reference],
            sceneStates: [sceneState],
            cuts: [cut]
        )
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let bundleURL = try CinemaSceneBundleExporter.export(
            project: project,
            sceneTitle: "Park",
            cuts: [cut],
            imageData: ["cut-1.png": Data("storyboard".utf8), "hero.webp": Data("reference".utf8)],
            configuration: configuration(),
            to: root,
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let expectedPaths = [
            "manifest.json",
            "README.txt",
            "prompts/scene.txt",
            "prompts/world-state.txt",
            "prompts/cut-001-image.txt",
            "prompts/cut-001-video.txt",
            "storyboard/cut-001.png",
            "references/\(referenceID.uuidString).webp"
        ]
        for path in expectedPaths {
            XCTAssertTrue(FileManager.default.fileExists(atPath: bundleURL.appendingPathComponent(path).path), path)
        }

        let manifestData = try Data(contentsOf: bundleURL.appendingPathComponent("manifest.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(CinemaSceneBundleManifest.self, from: manifestData)

        XCTAssertEqual(manifest.format, "cinema.scene-bundle")
        XCTAssertEqual(manifest.schemaVersion, "1.0.0")
        XCTAssertEqual(manifest.promptVersion, "cinema.prompt.v1")
        XCTAssertEqual(manifest.scene.state?.sceneKey, "scene-park")
        XCTAssertEqual(manifest.project.context.defaultFilmProfileID, "film-neutral")
        XCTAssertEqual(manifest.cuts.first?.shotSettings.seed, 42)
        XCTAssertEqual(manifest.cuts.first?.referenceIDs, [referenceID])
        XCTAssertEqual(manifest.references.first?.assetPath, "references/\(referenceID.uuidString).webp")
        XCTAssertTrue(manifest.warnings.isEmpty)

        let manifestText = String(decoding: manifestData, as: UTF8.self)
        XCTAssertFalse(manifestText.contains(root.path))
        XCTAssertFalse(manifestText.lowercased().contains("api_key"))
    }

    func testMissingImageDataIsReportedWithoutInvalidAssetPath() throws {
        let reference = ReferenceImage(name: "Missing", imageFileName: "missing.png")
        let cut = StoryboardCut(
            cutNumber: 1,
            situation: "A test frame.",
            imageFileName: "missing-cut.png",
            referenceImageIDs: [reference.id]
        )
        let project = StoryboardProject(referenceImages: [reference], cuts: [cut])
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let bundleURL = try CinemaSceneBundleExporter.export(
            project: project,
            sceneTitle: "Missing Assets",
            cuts: [cut],
            imageData: [:],
            configuration: configuration(),
            to: root
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(
            CinemaSceneBundleManifest.self,
            from: Data(contentsOf: bundleURL.appendingPathComponent("manifest.json"))
        )

        XCTAssertNil(manifest.cuts.first?.storyboardImagePath)
        XCTAssertNil(manifest.references.first?.assetPath)
        XCTAssertEqual(manifest.warnings.count, 2)
    }

    private func configuration() -> CinemaSceneExportConfiguration {
        CinemaSceneExportConfiguration(
            aspectRatio: .cinema185,
            aspectRatioLanguage: AppLanguage.english.rawValue,
            imageProvider: "openai",
            imageModel: "image-model",
            videoProvider: "novita",
            videoModel: "video-model",
            applicationVersion: "0.1.1"
        )
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("CinemaSceneBundleTests-\(UUID().uuidString)", isDirectory: true)
    }
}
