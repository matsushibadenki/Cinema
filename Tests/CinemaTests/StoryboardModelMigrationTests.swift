import XCTest
@testable import Cinema

final class StoryboardModelMigrationTests: XCTestCase {
    func testProjectContextWithoutProductionDirectiveDecodesWithEmptyDefault() throws {
        let data = Data("""
        {
          "storySummary": "A reunion",
          "visualBible": "Naturalistic",
          "continuityNotes": "Keep wardrobe",
          "reusableCharacterIDs": [],
          "reusableObjectIDs": [],
          "defaultFilmProfileID": "",
          "defaultFilmRecipeID": "",
          "defaultCreativePresetID": "",
          "defaultSeed": ""
        }
        """.utf8)

        let context = try JSONDecoder().decode(ProjectContext.self, from: data)

        XCTAssertEqual(context.productionDirective, "")
        XCTAssertEqual(context.storySummary, "A reunion")
    }

    func testProjectProductionDirectiveCreatesHighPriorityPrompt() {
        let context = ProjectContext(productionDirective: "A quiet neo-noir with the same two leads throughout.")

        XCTAssertTrue(context.promptText.contains("PROJECT-WIDE PRODUCTION DIRECTIVE"))
        XCTAssertTrue(context.promptText.contains("same two leads"))
    }

    func testCutWithoutAIShotSettingsDecodesWithDefaults() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "cutNumber": 1,
          "situation": "Interior",
          "action": "",
          "dialogueLines": [],
          "duration": "4",
          "generationPrompt": "",
          "textSplitRatio": 0.34,
          "dialogueSpeakerRatio": 0.28,
          "subtitle": "",
          "scriptHeading": "",
          "sceneName": "",
          "referenceImageIDs": []
        }
        """

        let cut = try JSONDecoder().decode(StoryboardCut.self, from: Data(json.utf8))

        XCTAssertEqual(cut.aiShotSettings, AIShotSettings())
    }
}
