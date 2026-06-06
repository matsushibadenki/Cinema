import XCTest
@testable import Cinema

final class StoryboardModelMigrationTests: XCTestCase {
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
