import Foundation
import XCTest
@testable import Cinema

final class SceneIdentityTests: XCTestCase {
    func testSameNameBlocksMigrateToDistinctStableIdentities() throws {
        let first = StoryboardCut(cutNumber: 1, situation: "First", subtitle: "Room")
        let second = StoryboardCut(cutNumber: 2, situation: "Second", subtitle: "Room")
        let state = SceneState(sceneKey: "Room", title: "Room",
                               environmentState: SceneStateCategory(title: "Environment", summary: "Warm light"))
        let project = StoryboardProject(sceneStates: [state], cuts: [first, second])
        let scenes = project.scenes(language: "en")
        XCTAssertEqual(scenes.count, 2)
        XCTAssertNotEqual(scenes[0].id, scenes[1].id)
        XCTAssertEqual(project.sceneStates.count, 2)
        for scene in scenes {
            XCTAssertEqual(project.sceneState(for: scene.id)?.environmentState.summary, "Warm light")
        }
        let reopened = try JSONDecoder().decode(StoryboardProject.self, from: JSONEncoder().encode(project))
        XCTAssertEqual(reopened, project)
    }

    func testRenameKeepsStateAndVideoHistory() throws {
        let cut = StoryboardCut(cutNumber: 1, subtitle: "Room")
        var project = StoryboardProject(
            sceneVideos: [SceneVideo(title: "Room", videoFileName: "room.mp4")],
            generatedCutVideos: [GeneratedCutVideo(sceneTitle: "Room", cutID: cut.id, videoFileName: "cut.mp4")],
            sceneStates: [SceneState(sceneKey: "Room", title: "Room")], cuts: [cut])
        let sceneID = try XCTUnwrap(project.cuts[0].sceneID)
        project.cuts[0].subtitle = "Renamed"
        project.normalizeSceneIdentities()
        XCTAssertEqual(project.cuts[0].sceneID, sceneID)
        XCTAssertEqual(project.sceneState(for: sceneID)?.title, "Renamed")
        XCTAssertEqual(project.sceneVideos[0].sceneID, sceneID)
        XCTAssertEqual(project.sceneVideos[0].title, "Renamed")
        XCTAssertEqual(project.generatedCutVideos[0].sceneID, sceneID)
        XCTAssertEqual(project.generatedCutVideos[0].videoFileName, "cut.mp4")
    }

    func testDeletingHeadingPreservesIdentityAndState() throws {
        var document = StoryboardDocument(project: StoryboardProject(
            sceneStates: [SceneState(sceneKey: "Room", title: "Room")],
            cuts: [StoryboardCut(cutNumber: 1, subtitle: "Room"), StoryboardCut(cutNumber: 2)]))
        let id = try XCTUnwrap(document.project.cuts[0].sceneID)
        document.deleteCuts(withIDs: [document.project.cuts[0].id])
        XCTAssertEqual(document.project.cuts[0].sceneID, id)
        XCTAssertNotNil(document.project.sceneState(for: id))
    }

    func testInsertingHeadingSplitsBlockWithoutStealingOriginalState() {
        var project = StoryboardProject(cuts: [StoryboardCut(cutNumber: 1, subtitle: "Room"), StoryboardCut(cutNumber: 2)])
        let original = project.cuts[0].sceneID
        project.cuts[1].subtitle = "Room"
        project.normalizeSceneIdentities()
        XCTAssertEqual(project.cuts[0].sceneID, original)
        XCTAssertNotEqual(project.cuts[1].sceneID, original)
        let snapshot = project
        project.normalizeSceneIdentities()
        XCTAssertEqual(project, snapshot)
    }

    func testMovingFirstCutWithinBlockRetainsScene() {
        var project = StoryboardProject(cuts: [StoryboardCut(cutNumber: 1, subtitle: "A"), StoryboardCut(cutNumber: 2), StoryboardCut(cutNumber: 3, subtitle: "B")])
        let sceneID = project.cuts[0].sceneID
        let moved = project.cuts[0].id
        project.moveCut(moved, relativeTo: project.cuts[1].id, after: true)
        XCTAssertEqual(project.cuts[0].subtitle, "A")
        XCTAssertEqual(project.cuts[0].sceneID, sceneID)
        XCTAssertEqual(project.cuts[1].id, moved)
        XCTAssertEqual(project.cuts[1].sceneID, sceneID)
        XCTAssertEqual(project.scenes(language: "en").count, 2)
    }

    func testMovingFirstCutAcrossBlocksPreservesBothHeadings() {
        var project = StoryboardProject(cuts: [StoryboardCut(cutNumber: 1, subtitle: "A"), StoryboardCut(cutNumber: 2), StoryboardCut(cutNumber: 3, subtitle: "B")])
        let firstScene = project.cuts[0].sceneID
        let secondScene = project.cuts[2].sceneID
        let moved = project.cuts[0].id
        project.moveCut(moved, relativeTo: project.cuts[2].id, after: false)
        XCTAssertEqual(project.cuts[0].subtitle, "A")
        XCTAssertEqual(project.cuts[0].sceneID, firstScene)
        XCTAssertEqual(project.cuts[1].subtitle, "B")
        XCTAssertEqual(project.cuts[1].sceneID, secondScene)
        XCTAssertEqual(project.cuts[1].id, moved)
        XCTAssertEqual(project.scenes(language: "en").count, 2)
    }

    func testLegacyDecodeIsDeterministicBeforeFirstSave() throws {
        let project = StoryboardProject(cuts: [StoryboardCut(cutNumber: 1), StoryboardCut(cutNumber: 2)])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(project)) as? [String: Any])
        json.removeValue(forKey: "id")
        var cuts = try XCTUnwrap(json["cuts"] as? [[String: Any]])
        for index in cuts.indices { cuts[index].removeValue(forKey: "sceneID") }
        json["cuts"] = cuts
        let data = try JSONSerialization.data(withJSONObject: json)
        let first = try JSONDecoder().decode(StoryboardProject.self, from: data)
        let second = try JSONDecoder().decode(StoryboardProject.self, from: data)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.cuts.map(\.sceneID), second.cuts.map(\.sceneID))
    }

    func testAmbiguousLegacyCombinedVideoIsRetainedWithoutGuessing() {
        let video = SceneVideo(title: "Room", videoFileName: "legacy.mp4")
        let project = StoryboardProject(sceneVideos: [video], cuts: [StoryboardCut(cutNumber: 1, subtitle: "Room"), StoryboardCut(cutNumber: 2, subtitle: "Room")])
        XCTAssertNil(project.sceneVideos[0].sceneID)
        XCTAssertEqual(project.sceneVideos[0].videoFileName, "legacy.mp4")
    }

    func testDefaultBlockStateSurvivesLanguageChanges() {
        let project = StoryboardProject(sceneStates: [SceneState(sceneKey: CinemaStrings.blockName(1, language: "en"), title: "")], cuts: [StoryboardCut(cutNumber: 1)])
        XCTAssertEqual(project.scenes(language: "ja")[0].id, project.scenes(language: "zh-Hans")[0].id)
        XCTAssertEqual(project.sceneStates[0].sceneID, project.cuts[0].sceneID)
    }
}
