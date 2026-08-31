import XCTest
@testable import Cinema

final class AIPromptBuilderTests: XCTestCase {
    func testEmptyCutDoesNotBecomeGeneratableFromDefaultContinuityValue() {
        let cut = StoryboardCut(cutNumber: 1)

        XCTAssertTrue(AIPromptBuilder.cutPrompt(for: cut).isEmpty)
    }

    func testCutPromptIncludesStructuredShotSettings() {
        let cut = StoryboardCut(
            cutNumber: 2,
            situation: "A woman waits on a station platform.",
            action: "She looks toward the arriving train.",
            aiShotSettings: AIShotSettings(
                shotSize: "medium close-up",
                cameraMovement: "slow dolly in",
                startState: "facing screen right",
                endState: "turning toward camera",
                transition: "match on action",
                negativePrompt: "no identity drift"
            )
        )

        let prompt = AIPromptBuilder.cutPrompt(for: cut)

        XCTAssertTrue(prompt.contains("medium close-up"))
        XCTAssertTrue(prompt.contains("slow dolly in"))
        XCTAssertTrue(prompt.contains("match on action"))
        XCTAssertTrue(prompt.contains("no identity drift"))
    }

    func testPreviousCutEndingStateIsPassedToNextCut() {
        let previous = StoryboardCut(
            cutNumber: 1,
            action: "He raises the cup.",
            aiShotSettings: AIShotSettings(
                endState: "cup beside his mouth",
                transition: "continue the hand movement"
            )
        )
        let current = StoryboardCut(cutNumber: 2, situation: "Reverse angle.")

        let prompt = AIPromptBuilder.cutPrompt(for: current, previousCut: previous)

        XCTAssertTrue(prompt.contains("cup beside his mouth"))
        XCTAssertTrue(prompt.contains("continue the hand movement"))
        XCTAssertTrue(prompt.contains("SAME-SCENE CONTINUITY CONTRACT"))
        XCTAssertTrue(prompt.contains("color temperature"))
        XCTAssertTrue(prompt.contains("higher priority than the creative preset"))
    }

    func testFirstCutResetsVisualInheritance() {
        let cut = StoryboardCut(cutNumber: 1, situation: "Morning in a new apartment.")

        let prompt = AIPromptBuilder.cutPrompt(for: cut)

        XCTAssertTrue(prompt.contains("NEW-SCENE RESET CONTRACT"))
        XCTAssertTrue(prompt.contains("Do not inherit lighting"))
    }

    func testExplicitShotDeltaDefinesAllowedContinuityChanges() {
        let previous = StoryboardCut(cutNumber: 1, situation: "Night platform.")
        let current = StoryboardCut(
            cutNumber: 2,
            situation: "Reverse angle.",
            shotDelta: ShotDelta(
                lightingChanges: [DrawingSettingsField(key: "Key light", value: "unchanged warm station lamp")],
                continuityRequirements: ["Keep the same white balance"]
            )
        )

        let prompt = AIPromptBuilder.cutPrompt(for: current, previousCut: previous)

        XCTAssertTrue(prompt.contains("unchanged warm station lamp"))
        XCTAssertTrue(prompt.contains("Keep the same white balance"))
    }
}
