import Foundation
import XCTest
@testable import Cinema

final class CinemaSceneBundleValidatorTests: XCTestCase {
    func testValidSceneIsReadyForExport() {
        let reference = ReferenceImage(name: "Wardrobe", imageFileName: "wardrobe.png")
        let cut = StoryboardCut(
            cutNumber: 1,
            situation: "A person enters the room.",
            duration: "5",
            imageFileName: "cut.png",
            referenceImageIDs: [reference.id]
        )
        let state = SceneState(
            sceneKey: "Room",
            title: "Room",
            environmentState: SceneStateCategory(title: "Environment", summary: "A quiet room at night.")
        )

        let report = CinemaSceneBundleValidator.validate(
            sceneTitle: "Room",
            sceneState: state,
            cuts: [cut],
            references: [reference],
            imageData: ["cut.png": Data([0]), "wardrobe.png": Data([1])],
            language: AppLanguage.english.rawValue
        )

        XCTAssertTrue(report.canExport)
        XCTAssertEqual(report.errorCount, 0)
        XCTAssertEqual(report.warningCount, 0)
        XCTAssertEqual(report.cutCount, 1)
        XCTAssertEqual(report.referenceCount, 1)
        XCTAssertEqual(report.storyboardImageCount, 1)
    }

    func testEmptyCutBlocksExportAndMissingMetadataProducesWarnings() {
        let cut = StoryboardCut(cutNumber: 3, duration: "not-a-number", imageFileName: "missing.png")

        let report = CinemaSceneBundleValidator.validate(
            sceneTitle: "Empty",
            sceneState: nil,
            cuts: [cut],
            references: [],
            imageData: [:],
            language: AppLanguage.japanese.rawValue
        )

        XCTAssertFalse(report.canExport)
        XCTAssertEqual(report.errorCount, 1)
        XCTAssertEqual(report.warningCount, 3)
        XCTAssertTrue(report.items.contains { $0.message.contains("Cut 3") })
    }

    func testMissingReferenceWarningIsDeduplicatedAcrossCuts() {
        let reference = ReferenceImage(name: "Shared", imageFileName: "missing.png")
        let cuts = [1, 2].map {
            StoryboardCut(
                cutNumber: $0,
                situation: "Cut \($0)",
                duration: "3",
                referenceImageIDs: [reference.id]
            )
        }

        let report = CinemaSceneBundleValidator.validate(
            sceneTitle: "Shared Reference",
            sceneState: SceneState(
                sceneKey: "Shared Reference",
                environmentState: SceneStateCategory(title: "Environment", summary: "Studio")
            ),
            cuts: cuts,
            references: [reference],
            imageData: [:],
            language: AppLanguage.english.rawValue
        )

        XCTAssertEqual(report.warningCount, 1)
    }

    func testDisabledReferenceIsExcludedFromValidation() {
        let reference = ReferenceImage(name: "Disabled", imageFileName: "missing.png")
        let cut = StoryboardCut(
            cutNumber: 1,
            situation: "A valid cut.",
            duration: "3",
            referenceImageIDs: [reference.id],
            disabledReferenceImageIDs: [reference.id]
        )

        let report = CinemaSceneBundleValidator.validate(
            sceneTitle: "Disabled Reference",
            sceneState: SceneState(
                sceneKey: "Disabled Reference",
                environmentState: SceneStateCategory(title: "Environment", summary: "Studio")
            ),
            cuts: [cut],
            references: [reference],
            imageData: [:],
            language: AppLanguage.english.rawValue
        )

        XCTAssertEqual(report.referenceCount, 0)
        XCTAssertFalse(report.items.contains { $0.id.contains("reference") })
    }
}
