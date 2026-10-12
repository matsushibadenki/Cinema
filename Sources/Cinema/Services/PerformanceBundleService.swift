import Foundation
import CryptoKit
import AVFoundation

struct PerformanceBundleReceipt: Codable, Equatable {
    var bundleID: UUID
    var projectID: UUID
    var sceneID: UUID
    var cues: [PerformanceCue]
    var audioHashes: [UUID: String]
    var dialogue: [PerformanceDialogueSnapshot]
    var characters: [ProjectCharacter]
    var audioAssets: [PerformanceAudioAsset]
    var audioClips: [PerformanceAudioClip]? = nil
    var laneStates: [PerformanceLaneState]? = nil
}
struct PerformanceSceneBundle: Codable {
    var format = "cinema.scene-bundle"
    var schemaVersion = "2.0.0"
    var receipt: PerformanceBundleReceipt
    var performance: PerformancePlanExport
    var cuts: [StoryboardCut]
    var projectContext: ProjectContext
    var drawingSettings: DrawingSettings
}
struct PerformanceResultBundle: Codable {
    var format = "cinema.result-bundle"
    var schemaVersion = "2.0.0"
    var sourceBundleID: UUID
    var projectID: UUID
    var sceneID: UUID
    var runner: String
    var modelRevision: String
    var outputs: [PerformanceResultOutput]
}
struct PerformanceResultOutput: Codable {
    var dialogueID: UUID
    var audioPath: String?
    var alignment: AudioAlignmentFile?
    var videoPath: String?
}

enum PerformanceBundleService {
    enum BundleError: LocalizedError {
        case incompatible, stale, missingAudio, invalidOutput, unsafePath
        var errorDescription: String? {
            switch self {
            case .incompatible: "The bundle format or source identity is incompatible."
            case .stale: "The dialogue, audio or performance plan has changed since export. Export a new bundle."
            case .missingAudio: "An assigned locked audio asset is missing."
            case .invalidOutput: "A result contains invalid, empty or duplicate media."
            case .unsafePath: "The bundle contains an unsafe path."
            }
        }
    }
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    static func export(document: StoryboardDocument, sceneID: UUID, to parent: URL) throws -> (URL, PerformanceBundleReceipt) {
        var snapshot = document.project
        let cuts = snapshot.cuts.filter { $0.sceneID == sceneID }
        guard !cuts.isEmpty else { throw BundleError.incompatible }
        snapshot.cuts = cuts
        snapshot.performancePlan.cues = snapshot.performancePlan.cues.filter { $0.sceneID == sceneID }
        snapshot.performancePlan.audioClips = snapshot.performancePlan.audioClips.filter { $0.sceneID == sceneID }
        snapshot.performancePlan.laneStates = snapshot.performancePlan.laneStates.filter { $0.sceneID == sceneID }
        guard !snapshot.performancePlan.cues.isEmpty, snapshot.performancePlan.cues.allSatisfy({ $0.audioAssetID != nil }), snapshot.performancePlan.issues(in: snapshot).isEmpty else { throw BundleError.invalidOutput }
        let assetIDs = Set(snapshot.performancePlan.cues.compactMap(\.audioAssetID) + snapshot.performancePlan.audioClips.map(\.audioAssetID))
        snapshot.performancePlan.audioAssets = snapshot.performancePlan.audioAssets.filter { assetIDs.contains($0.id) }
        var hashes: [UUID: String] = [:]
        var audioFiles: [String: FileWrapper] = [:]
        for index in snapshot.performancePlan.audioAssets.indices {
            let asset = snapshot.performancePlan.audioAssets[index]
            guard let data = document.audioData[asset.fileName], !data.isEmpty else { throw BundleError.missingAudio }
            if let alignment = asset.alignment { try AudioAlignmentFile(audioAssetID: asset.id, segments: alignment).validate(for: asset) }
            hashes[asset.id] = hash(data)
            let ext = URL(fileURLWithPath: asset.fileName).pathExtension.lowercased()
            guard !ext.isEmpty, ext.allSatisfy({ $0.isLetter || $0.isNumber }) else { throw BundleError.unsafePath }
            let name = "\(asset.id).\(ext)"
            guard audioFiles[name] == nil else { throw BundleError.invalidOutput }
            audioFiles[name] = FileWrapper(regularFileWithContents: data)
            snapshot.performancePlan.audioAssets[index].fileName = "audio/" + name
        }
        guard Set(snapshot.performancePlan.audioAssets.map(\.id)) == assetIDs else { throw BundleError.missingAudio }
        let receipt = PerformanceBundleReceipt(bundleID: UUID(), projectID: snapshot.id, sceneID: sceneID, cues: snapshot.performancePlan.cues, audioHashes: hashes, dialogue: PerformancePlanExport(project: snapshot).dialogue, characters: snapshot.performancePlan.characters, audioAssets: document.project.performancePlan.audioAssets.filter { assetIDs.contains($0.id) }, audioClips: snapshot.performancePlan.audioClips, laneStates: snapshot.performancePlan.laneStates)
        let manifest = PerformanceSceneBundle(receipt: receipt, performance: PerformancePlanExport(project: snapshot), cuts: cuts, projectContext: snapshot.projectContext, drawingSettings: snapshot.drawingSettings)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let root = FileWrapper(directoryWithFileWrappers: ["manifest.json": FileWrapper(regularFileWithContents: try encoder.encode(manifest)), "audio": FileWrapper(directoryWithFileWrappers: audioFiles)])
        let url = parent.appendingPathComponent("performance_scene_v2_" + receipt.bundleID.uuidString)
        try root.write(to: url, options: .atomic, originalContentsURL: nil)
        return (url, receipt)
    }

    /// Validate and stage every output before mutating the document; retain original takes.
    static func importResult(at root: URL, into document: inout StoryboardDocument) async throws -> Int {
        let result = try JSONDecoder().decode(PerformanceResultBundle.self, from: Data(contentsOf: safeURL("manifest.json", root: root)))
        guard result.format == "cinema.result-bundle", result.schemaVersion == "2.0.0", result.projectID == document.project.id,
              let receipt = document.project.performanceBundleReceipts.first(where: { $0.bundleID == result.sourceBundleID }), receipt.projectID == result.projectID, receipt.sceneID == result.sceneID else { throw BundleError.incompatible }
        guard !document.project.importedGenerationResults.contains(where: { $0.sourceBundleID == result.sourceBundleID }), !result.outputs.isEmpty,
              Set(result.outputs.map(\.dialogueID)).count == result.outputs.count else { throw BundleError.invalidOutput }
        guard receipt.characters == document.project.performancePlan.characters else { throw BundleError.stale }
        if let clips = receipt.audioClips {
            guard clips == document.project.performancePlan.audioClips.filter({ $0.sceneID == receipt.sceneID }) else { throw BundleError.stale }
        }
        if let states = receipt.laneStates {
            guard states == document.project.performancePlan.laneStates.filter({ $0.sceneID == receipt.sceneID }) else { throw BundleError.stale }
        }
        for original in receipt.audioAssets {
            guard document.project.performancePlan.audioAssets.contains(original),
                  let data = document.audioData[original.fileName], hash(data) == receipt.audioHashes[original.id] else { throw BundleError.stale }
        }
        let currentDialogue = PerformancePlanExport(project: document.project).dialogue
        guard receipt.dialogue.allSatisfy({ currentDialogue.contains($0) }) else { throw BundleError.stale }
        var staged = document
        for output in result.outputs {
            guard let expected = receipt.cues.first(where: { $0.dialogueID == output.dialogueID }),
                  let index = staged.project.performancePlan.cues.firstIndex(where: { $0.id == expected.id }), staged.project.performancePlan.cues[index] == expected,
                  let cut = staged.project.cuts.first(where: { $0.id == expected.cutID && $0.sceneID == result.sceneID }), cut.dialogueLines.contains(where: { $0.id == output.dialogueID }),
                  let audioID = expected.audioAssetID, let original = staged.project.performancePlan.audioAssets.first(where: { $0.id == audioID }),
                  receipt.audioAssets.contains(original), let originalData = staged.audioData[original.fileName], hash(originalData) == receipt.audioHashes[audioID] else { throw BundleError.stale }
            guard output.audioPath != nil || output.alignment != nil || output.videoPath != nil else { throw BundleError.invalidOutput }
            var take = original; take.id = UUID(); take.importedAt = Date()
            if let path = output.audioPath {
                let url = try safeURL(path, root: root)
                let file = try AVAudioFile(forReading: url)
                guard file.length > 0, file.processingFormat.sampleRate > 0 else { throw BundleError.invalidOutput }
                let bytes = try Data(contentsOf: url)
                take.duration.seconds = Double(file.length) / file.processingFormat.sampleRate
                let name = "Audio/" + take.id.uuidString + "." + url.pathExtension
                take.fileName = name; take.alignment = nil; staged.audioData[name] = bytes
            }
            if let alignment = output.alignment {
                var reference = take; reference.id = audioID
                try alignment.validate(for: reference); take.alignment = alignment.segments
            }
            let offset = expected.sourceOffset?.seconds ?? 0
            guard offset + expected.end.seconds - expected.start.seconds <= take.duration.seconds else { throw BundleError.invalidOutput }
            staged.project.performancePlan.audioAssets.append(take)
            staged.project.performancePlan.cues[index].audioAssetID = take.id
            staged.project.performancePlan.cues[index].revision += 1
            if let path = output.videoPath {
                let videoURL = try safeURL(path, root: root)
                let videoAsset = AVURLAsset(url: videoURL)
                let tracks = try await videoAsset.loadTracks(withMediaType: .video)
                let duration = try await videoAsset.load(.duration)
                guard !tracks.isEmpty, duration.seconds.isFinite, duration.seconds > 0 else { throw BundleError.invalidOutput }
                let bytes = try Data(contentsOf: videoURL)
                guard !bytes.isEmpty else { throw BundleError.invalidOutput }
                let name = "Videos/" + UUID().uuidString + ".mp4"
                staged.videoData[name] = bytes
                var video = GeneratedCutVideo(sceneTitle: cut.subtitle, cutID: cut.id, videoFileName: name)
                video.sceneID = result.sceneID; staged.project.generatedCutVideos.append(video)
            }
        }
        var provenance = ImportedGenerationResult(sourceBundleID: result.sourceBundleID, sceneTitle: result.sceneID.uuidString, runner: result.runner, modelRevision: result.modelRevision)
        provenance.sceneID = result.sceneID
        staged.project.importedGenerationResults.append(provenance)
        document = staged
        return result.outputs.count
    }
    static func safeURL(_ path: String, root: URL) throws -> URL {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else { throw BundleError.unsafePath }
        let root = root.resolvingSymlinksInPath().standardizedFileURL
        var url = root
        for component in path.split(separator: "/") {
            guard component != "." else { throw BundleError.unsafePath }
            url = url.appendingPathComponent(String(component)).resolvingSymlinksInPath().standardizedFileURL
            guard url.path.hasPrefix(root.path + "/") else { throw BundleError.unsafePath }
        }
        guard url != root else { throw BundleError.unsafePath }
        return url
    }
}
