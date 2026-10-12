import XCTest
@testable import Cinema

final class PerformanceTimelineTests: XCTestCase {
    func testLegacyProjectAndPlanRoundTrip() throws {
        var project = StoryboardProject()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(project)) as? [String: Any])
        json.removeValue(forKey: "performancePlan")
        XCTAssertEqual(try JSONDecoder().decode(StoryboardProject.self, from: JSONSerialization.data(withJSONObject: json)).performancePlan, PerformancePlan())
        project.performancePlan.characters = [ProjectCharacter(name: "Alice", voiceID: "fixed-voice")]
        XCTAssertEqual(try JSONDecoder().decode(StoryboardProject.self, from: JSONEncoder().encode(project)), project)
    }

    func testTimingAndIdentitySurviveCutRenumbering() throws {
        let line = DialogueLine(speaker: "Alice", dialogue: "Across the cut")
        let cut = StoryboardCut(cutNumber: 1, dialogueLines: [line])
        var project = StoryboardProject(cuts: [cut])
        let scene = try XCTUnwrap(project.cuts[0].sceneID)
        var start = PerformanceTime(); start.seconds = 1.125
        var end = PerformanceTime(); end.seconds = 8.5
        project.performancePlan.cues = [PerformanceCue(sceneID: scene, cutID: cut.id, dialogueID: line.id, start: start, end: end)]
        project.cuts[0].cutNumber = 42
        XCTAssertTrue(project.performancePlan.issues(in: project).isEmpty)
        XCTAssertEqual(start.ticks, 54000)
        XCTAssertEqual(end.seconds, 8.5)
        XCTAssertTrue(project.performancePlan.prompt(for: project.cuts).contains(line.id.uuidString))
        let export = PerformancePlanExport(project: project)
        XCTAssertEqual(export.dialogue.first?.text, line.dialogue)
    }

    func testMissingReferencesAndInvalidTimingAreReported() throws {
        let line = DialogueLine(dialogue: "Test")
        var project = StoryboardProject(cuts: [StoryboardCut(cutNumber: 1, dialogueLines: [line])])
        let cut = project.cuts[0]
        project.performancePlan.cues = [PerformanceCue(sceneID: try XCTUnwrap(cut.sceneID), cutID: cut.id, dialogueID: line.id, characterID: UUID(), mode: .audioFirst)]
        XCTAssertEqual(project.performancePlan.issues(in: project).count, 3)
        project.cuts.removeAll()
        XCTAssertEqual(project.performancePlan.issues(in: project).count, 1)
    }

    func testBackgroundLanesPersistAndValidateRanges() throws {
        var project = StoryboardProject()
        let scene = try XCTUnwrap(project.cuts[0].sceneID)
        let asset = PerformanceAudioAsset(name: "Music", fileName: "Audio/music.wav", duration: PerformanceTime(ticks: 96000))
        project.performancePlan.audioAssets = [asset]
        project.performancePlan.audioClips = [PerformanceAudioClip(sceneID: scene, audioAssetID: asset.id, end: PerformanceTime(ticks: 48000))]
        XCTAssertTrue(project.performancePlan.issues(in: project).isEmpty)
        XCTAssertEqual(try JSONDecoder().decode(StoryboardProject.self, from: JSONEncoder().encode(project)), project)
        project.performancePlan.audioClips[0].sourceOffset.ticks = 96000
        XCTAssertEqual(project.performancePlan.issues(in: project).count, 1)
        let json = Data("{\"characters\":[],\"cues\":[]}".utf8)
        XCTAssertTrue(try JSONDecoder().decode(PerformancePlan.self, from: json).audioClips.isEmpty)
        XCTAssertThrowsError(try PerformanceAudioService.placements(plan: project.performancePlan, sceneID: scene, urls: [:]))
    }

    func testMixSettingsLegacyDecodingAndValidation() throws {
        let cue = PerformanceCue(sceneID: UUID(), cutID: UUID(), dialogueID: UUID())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(cue)) as? [String: Any])
        json.removeValue(forKey: "mix")
        XCTAssertNil(try JSONDecoder().decode(PerformanceCue.self, from: JSONSerialization.data(withJSONObject: json)).mix)
        let clip = PerformanceAudioClip(sceneID: UUID(), audioAssetID: UUID())
        XCTAssertNil(try JSONDecoder().decode(PerformanceAudioClip.self, from: JSONEncoder().encode(clip)).mix)
        let start = PerformanceTime(); let end = PerformanceTime(ticks: 48000)
        XCTAssertFalse(PerformanceAudioMixSettings(volume: .nan).isValid(start: start, end: end))
        XCTAssertFalse(PerformanceAudioMixSettings(volume: 1.1).isValid(start: start, end: end))
        XCTAssertFalse(PerformanceAudioMixSettings(fadeIn: PerformanceTime(ticks: -1)).isValid(start: start, end: end))
        XCTAssertTrue(PerformanceAudioMixSettings(fadeIn: PerformanceTime(ticks: 24000), fadeOut: PerformanceTime(ticks: 24000)).isValid(start: start, end: end))
    }

    func testSceneLocalMuteSoloAndLegacyDefaults() throws {
        var plan = PerformancePlan()
        let scene = UUID(); let other = UUID()
        plan.laneStates = [PerformanceLaneState(sceneID: other, lane: .music, isSolo: true)]
        XCTAssertTrue(PerformanceMixLane.allCases.allSatisfy { plan.laneIsAudible($0, sceneID: scene) })
        plan.laneStates.append(PerformanceLaneState(sceneID: scene, lane: .music, isSolo: true))
        XCTAssertFalse(plan.laneIsAudible(.dialogue, sceneID: scene))
        XCTAssertTrue(plan.laneIsAudible(.music, sceneID: scene))
        plan.laneStates.append(PerformanceLaneState(sceneID: scene, lane: .ambience, isSolo: true))
        XCTAssertTrue(plan.laneIsAudible(.ambience, sceneID: scene))
        plan.laneStates[1].isMuted = true
        XCTAssertFalse(plan.laneIsAudible(.music, sceneID: scene))
        XCTAssertEqual(try JSONDecoder().decode(PerformancePlan.self, from: JSONEncoder().encode(plan)), plan)
        let legacy = try JSONDecoder().decode(PerformancePlan.self, from: Data("{}".utf8))
        XCTAssertTrue(legacy.laneStates.isEmpty)
        XCTAssertTrue(PerformanceMixLane.allCases.allSatisfy { legacy.laneIsAudible($0, sceneID: scene) })
    }

    func testNonFiniteTimesDoNotCorruptTicks() {
        var time = PerformanceTime(ticks: 48000)
        time.seconds = .infinity
        time.seconds = -.infinity
        time.seconds = .nan
        time.seconds = -1
        XCTAssertEqual(time.ticks, 48000)
    }
}
