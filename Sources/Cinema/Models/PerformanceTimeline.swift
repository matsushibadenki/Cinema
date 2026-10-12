import Foundation

/// Scene-relative time in 48 kHz ticks, independent of cut numbering.
struct PerformanceTime: Codable, Equatable {
    var ticks: Int64 = 0
    static let timescale: Int32 = 48_000
    var seconds: Double {
        get { Double(ticks) / Double(Self.timescale) }
        set { if newValue.isFinite && newValue >= 0 && newValue < Double(Int64.max) / Double(Self.timescale) { ticks = Int64((newValue * Double(Self.timescale)).rounded()) } }
    }
}

struct ProjectCharacter: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = ""
    var voiceID = ""
    var voiceProvider = ""
    var voiceModel = ""
    var speakingStyle = ""
    var referenceImageIDs: [UUID] = []
}

enum PerformanceProductionMode: String, Codable, CaseIterable {
    case nativeAudio, audioFirst, videoFirst
}

struct PerformanceAudioMixSettings: Codable, Equatable {
    var volume: Double = 1
    var fadeIn = PerformanceTime()
    var fadeOut = PerformanceTime()

    func isValid(start: PerformanceTime, end: PerformanceTime) -> Bool {
        volume.isFinite && (0...1).contains(volume) && fadeIn.ticks >= 0 && fadeOut.ticks >= 0 &&
        end.ticks > start.ticks && Double(fadeIn.ticks) + Double(fadeOut.ticks) <= Double(end.ticks) - Double(start.ticks)
    }
}

struct PerformanceCue: Codable, Identifiable, Equatable {
    var id = UUID()
    var sceneID: UUID
    var cutID: UUID
    var dialogueID: UUID
    var characterID: UUID?
    var audioAssetID: UUID? = nil
    var sourceOffset: PerformanceTime? = nil
    var mix: PerformanceAudioMixSettings? = nil
    var start = PerformanceTime()
    var end = PerformanceTime()
    var mode: PerformanceProductionMode = .nativeAudio
    var revision = 1
    var notes = ""
}

enum PerformanceAudioLane: String, Codable, CaseIterable {
    case music, ambience
}

struct PerformanceAudioClip: Codable, Identifiable, Equatable {
    var id = UUID()
    var sceneID: UUID
    var audioAssetID: UUID
    var lane: PerformanceAudioLane = .music
    var start = PerformanceTime()
    var end = PerformanceTime()
    var sourceOffset = PerformanceTime()
    var mix: PerformanceAudioMixSettings? = nil
}

enum PerformanceMixLane: String, Codable, CaseIterable {
    case dialogue, music, ambience
}

struct PerformanceLaneState: Codable, Equatable {
    var sceneID: UUID
    var lane: PerformanceMixLane
    var isMuted = false
    var isSolo = false
}

struct PerformancePlan: Codable, Equatable {
    var format = "cinema.performance-plan"
    var schemaVersion = "1.0.0"
    var timescale = PerformanceTime.timescale
    var characters: [ProjectCharacter] = []
    var cues: [PerformanceCue] = []
    var audioAssets: [PerformanceAudioAsset] = []
    var audioClips: [PerformanceAudioClip] = []
    var laneStates: [PerformanceLaneState] = []

    init() {}
    private enum CodingKeys: String, CodingKey { case format, schemaVersion, timescale, characters, cues, audioAssets, audioClips, laneStates }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decodeIfPresent(String.self, forKey: .format) ?? "cinema.performance-plan"
        schemaVersion = try c.decodeIfPresent(String.self, forKey: .schemaVersion) ?? "1.0.0"
        timescale = try c.decodeIfPresent(Int32.self, forKey: .timescale) ?? PerformanceTime.timescale
        guard timescale == PerformanceTime.timescale else { throw DecodingError.dataCorruptedError(forKey: .timescale, in: c, debugDescription: "Unsupported performance timescale") }
        characters = try c.decodeIfPresent([ProjectCharacter].self, forKey: .characters) ?? []
        cues = try c.decodeIfPresent([PerformanceCue].self, forKey: .cues) ?? []
        audioAssets = try c.decodeIfPresent([PerformanceAudioAsset].self, forKey: .audioAssets) ?? []
        audioClips = try c.decodeIfPresent([PerformanceAudioClip].self, forKey: .audioClips) ?? []
        laneStates = try c.decodeIfPresent([PerformanceLaneState].self, forKey: .laneStates) ?? []
    }

    func laneIsAudible(_ lane: PerformanceMixLane, sceneID: UUID) -> Bool {
        let states = laneStates.filter { $0.sceneID == sceneID }
        let state = states.first { $0.lane == lane }
        return state?.isMuted != true && (!states.contains { $0.isSolo } || state?.isSolo == true)
    }

    func issues(in project: StoryboardProject) -> [String] {
        let dialogueIssues = cues.flatMap { cue -> [String] in
            var issues: [String] = []
            guard let cut = project.cuts.first(where: { $0.id == cue.cutID }), cut.sceneID == cue.sceneID,
                  cut.dialogueLines.contains(where: { $0.id == cue.dialogueID }) else { return ["Unresolved dialogue or scene: \(cue.id)"] }
            if let mix = cue.mix, !mix.isValid(start: cue.start, end: cue.end) { issues.append("Invalid audio mix: \(cue.id)") }
            if cue.start.ticks < 0 || cue.end.ticks <= cue.start.ticks { issues.append("Invalid timing: \(cue.id)") }
            if let id = cue.characterID, !characters.contains(where: { $0.id == id }) { issues.append("Missing character: \(cue.id)") }
            if let id = cue.audioAssetID {
                if let asset = audioAssets.first(where: { $0.id == id }) {
                    let offset = cue.sourceOffset?.ticks ?? 0
                    if offset < 0 || cue.end.ticks > cue.start.ticks && Double(offset) + Double(cue.end.ticks) - Double(cue.start.ticks) > Double(asset.duration.ticks) { issues.append("Audio range exceeds asset: \(cue.id)") }
                } else { issues.append("Missing audio asset: \(cue.id)") }
            }
            if cue.mode == .audioFirst && cue.audioAssetID == nil { issues.append("Audio-first cue has no locked audio asset yet: \(cue.id)") }
            return issues
        }
        var stateIssues: [String] = []
        let keys = laneStates.map { $0.sceneID.uuidString + ":" + $0.lane.rawValue }
        if Set(keys).count != keys.count { stateIssues.append("Duplicate scene audio lane state") }
        if laneStates.contains(where: { state in !project.cuts.contains { $0.sceneID == state.sceneID } }) { stateIssues.append("Unresolved audio lane scene") }
        return dialogueIssues + audioClipIssues(in: project) + stateIssues
    }

    func audioClipIssues(in project: StoryboardProject) -> [String] {
        audioClips.flatMap { clip -> [String] in
            var issues: [String] = []
            if !project.cuts.contains(where: { $0.sceneID == clip.sceneID }) { issues.append("Unresolved audio scene: \(clip.id)") }
            if let mix = clip.mix, !mix.isValid(start: clip.start, end: clip.end) { issues.append("Invalid audio mix: \(clip.id)") }
            if clip.start.ticks < 0 || clip.end.ticks <= clip.start.ticks || clip.sourceOffset.ticks < 0 { issues.append("Invalid audio clip timing: \(clip.id)") }
            if let asset = audioAssets.first(where: { $0.id == clip.audioAssetID }) {
                if Double(clip.sourceOffset.ticks) + Double(clip.end.ticks) - Double(clip.start.ticks) > Double(asset.duration.ticks) { issues.append("Audio range exceeds asset: \(clip.id)") }
            } else { issues.append("Missing audio asset: \(clip.id)") }
            return issues
        }
    }

    func prompt(for cuts: [StoryboardCut]) -> String {
        let ids = Set(cuts.map(\.id))
        let selected = cues.filter { ids.contains($0.cutID) }
        guard !selected.isEmpty else { return "" }
        return (["PERFORMANCE PLAN (timing is scene-relative; guidance only, not verified lip sync):"] + selected.map { cue in
            let character = characters.first { $0.id == cue.characterID }
            return "Dialogue \(cue.dialogueID), character \(character?.name ?? "unassigned") [\(character?.id.uuidString ?? "none")], voice \(character?.voiceID ?? ""), provider/model \(character?.voiceProvider ?? "")/\(character?.voiceModel ?? ""), style \(character?.speakingStyle ?? ""), \(cue.start.ticks)/\(timescale)–\(cue.end.ticks)/\(timescale) seconds, mode \(cue.mode.rawValue), locked audio \(cue.audioAssetID?.uuidString ?? "none"), source offset \(cue.sourceOffset?.ticks ?? 0)/\(timescale) seconds, revision \(cue.revision). \(cue.notes)"
        }).joined(separator: "\n")
    }
}

struct PerformancePlanExport: Codable, Equatable {
    var plan: PerformancePlan
    var projectID: UUID
    var dialogue: [PerformanceDialogueSnapshot]
    var warnings: [String]

    init(project: StoryboardProject) {
        plan = project.performancePlan
        projectID = project.id
        dialogue = project.cuts.flatMap { cut in
            cut.dialogueLines.map { PerformanceDialogueSnapshot(cutID: cut.id, sceneID: cut.sceneID, dialogueID: $0.id, speaker: $0.speaker, text: $0.dialogue, performance: $0.performance) }
        }
        warnings = plan.issues(in: project)
    }
}

struct PerformanceDialogueSnapshot: Codable, Equatable {
    var cutID: UUID
    var sceneID: UUID?
    var dialogueID: UUID
    var speaker: String
    var text: String
    var performance: DialoguePerformance
}

struct PerformanceAudioAsset: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var fileName: String
    var duration: PerformanceTime
    var importedAt = Date()
    var alignment: [AudioAlignmentSegment]? = nil
}
