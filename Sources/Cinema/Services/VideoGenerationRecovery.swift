import Foundation

/// Written before the first request. No API keys or private absolute paths are stored.
struct VideoGenerationRun: Codable, Identifiable, Equatable {
    var id: UUID
    var projectID: UUID
    var sceneID: UUID
    var sceneTitle: String
    var cutIDs: [UUID]
    var provider: String
    var model: String
    var startedAt: Date
}

struct RecoveredVideoRun: Identifiable {
    var run: VideoGenerationRun
    var clips: [GeneratedCutVideo]
    var sceneVideo: SceneVideo?
    var id: UUID { run.id }
    var canAssemble: Bool { !clips.isEmpty && clips.map(\.cutID) == run.cutIDs }
}

struct VideoRecoveryReport {
    var runs: [RecoveredVideoRun] = []
    var unreadableRunCount = 0
}

/// Each clip is a tiny, self-describing directory published using an atomic rename.
/// A process exit between cuts cannot invalidate already published clips, and recovery
/// does not depend on whether SwiftUI autosaved the document before that exit.
enum VideoGenerationRecovery {
    enum RecoveryError: LocalizedError {
        case invalidRun
        case incompleteRun
        case emptyClip

        var errorDescription: String? {
            switch self {
            case .invalidRun: return "The saved generation run is invalid."
            case .incompleteRun: return "Some cuts have not finished. Completed clips remain available."
            case .emptyClip: return "The generated clip is empty."
            }
        }
    }

    static func begin(projectID: UUID, sceneID: UUID, title: String, cuts: [StoryboardCut],
                      provider: String, model: String, documentURL: URL) throws -> VideoGenerationRun {
        let run = VideoGenerationRun(id: UUID(), projectID: projectID, sceneID: sceneID,
                                     sceneTitle: title, cutIDs: cuts.map(\.id), provider: provider,
                                     model: model, startedAt: Date())
        guard !run.cutIDs.isEmpty, Set(run.cutIDs).count == run.cutIDs.count else { throw RecoveryError.invalidRun }
        let directory = runDirectory(run, documentURL: documentURL)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(run).write(to: directory.appendingPathComponent("run.json"), options: .atomic)
        return run
    }

    static func checkpoint(_ data: Data, cutID: UUID, run: VideoGenerationRun,
                           documentURL: URL) throws -> GeneratedCutVideo {
        guard run.cutIDs.contains(cutID) else { throw RecoveryError.invalidRun }
        guard !data.isEmpty else { throw RecoveryError.emptyClip }
        let directory = runDirectory(run, documentURL: documentURL)
        let finalDirectory = directory.appendingPathComponent(cutID.uuidString, isDirectory: true)
        // Repeated delivery is idempotent, keeping the original successful clip.
        if let existing = try? readClip(at: finalDirectory, run: run, cutID: cutID) { return existing }
        let staging = directory.appendingPathComponent("staging-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: staging) }
        var clip = GeneratedCutVideo(sceneTitle: run.sceneTitle, cutID: cutID,
                                     videoFileName: "\(relativeDirectory(run))/\(cutID.uuidString)/clip.mp4")
        clip.sceneID = run.sceneID
        try data.write(to: staging.appendingPathComponent("clip.mp4"), options: .atomic)
        try JSONEncoder().encode(clip).write(to: staging.appendingPathComponent("clip.json"), options: .atomic)
        try FileManager.default.moveItem(at: staging, to: finalDirectory)
        return clip
    }

    static func finish(_ data: Data, run: VideoGenerationRun, documentURL: URL) throws -> SceneVideo {
        guard !data.isEmpty else { throw RecoveryError.emptyClip }
        let directory = runDirectory(run, documentURL: documentURL)
        for cutID in run.cutIDs {
            _ = try readClip(at: directory.appendingPathComponent(cutID.uuidString), run: run, cutID: cutID)
        }
        let finalDirectory = directory.appendingPathComponent("combined", isDirectory: true)
        if let existing = try? readScene(at: finalDirectory, run: run) { return existing }
        let staging = directory.appendingPathComponent("staging-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: staging) }
        var video = SceneVideo(title: run.sceneTitle,
                               videoFileName: "\(relativeDirectory(run))/combined/scene.mp4")
        video.sceneID = run.sceneID
        try data.write(to: staging.appendingPathComponent("scene.mp4"), options: .atomic)
        try JSONEncoder().encode(video).write(to: staging.appendingPathComponent("scene.json"), options: .atomic)
        try FileManager.default.moveItem(at: staging, to: finalDirectory)
        return video
    }

    static func scan(projectID: UUID, documentURL: URL) -> VideoRecoveryReport {
        let root = documentURL.deletingLastPathComponent()
            .appendingPathComponent("movies/generation/\(projectID.uuidString)", isDirectory: true)
            .standardizedFileURL.resolvingSymlinksInPath()
        var report = VideoRecoveryReport()
        guard let folders = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey]) else { return report }
        for folder in folders where UUID(uuidString: folder.lastPathComponent) != nil {
            do {
                guard try folder.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw RecoveryError.invalidRun }
                let run = try JSONDecoder().decode(VideoGenerationRun.self, from: Data(contentsOf: folder.appendingPathComponent("run.json")))
                guard run.projectID == projectID, run.id.uuidString == folder.lastPathComponent,
                      Set(run.cutIDs).count == run.cutIDs.count else { throw RecoveryError.invalidRun }
                var clips: [GeneratedCutVideo] = []
                for cutID in run.cutIDs {
                    let clipDirectory = folder.appendingPathComponent(cutID.uuidString)
                    guard FileManager.default.fileExists(atPath: clipDirectory.path) else { continue }
                    do { clips.append(try readClip(at: clipDirectory, run: run, cutID: cutID)) }
                    catch { report.unreadableRunCount += 1 }
                }
                let combined = folder.appendingPathComponent("combined")
                var scene: SceneVideo?
                if FileManager.default.fileExists(atPath: combined.path) {
                    do { scene = try readScene(at: combined, run: run) }
                    catch { report.unreadableRunCount += 1 }
                }
                report.runs.append(RecoveredVideoRun(run: run, clips: clips, sceneVideo: scene))
            } catch { report.unreadableRunCount += 1 }
        }
        report.runs.sort { $0.run.startedAt < $1.run.startedAt }
        return report
    }

    @discardableResult
    static func restore(_ report: VideoRecoveryReport, into project: inout StoryboardProject) -> Int {
        var restored = 0
        var ids = Set(project.generatedCutVideos.map(\.id))
        for recovered in report.runs where recovered.run.projectID == project.id {
            for clip in recovered.clips where project.cuts.contains(where: { $0.id == clip.cutID }) {
                if ids.insert(clip.id).inserted {
                    project.generatedCutVideos.append(clip)
                    restored += 1
                }
            }
            if let scene = recovered.sceneVideo, project.cuts.contains(where: { $0.sceneID == scene.sceneID }) {
                let existing = project.sceneVideos.first { $0.sceneID == scene.sceneID }
                if existing.map({ $0.generatedAt < scene.generatedAt }) ?? true {
                    project.sceneVideos.removeAll { $0.sceneID == scene.sceneID }
                    project.sceneVideos.append(scene)
                }
            }
        }
        project.normalizeSceneIdentities()
        return restored
    }

    static func assemble(_ recovered: RecoveredVideoRun, documentURL: URL,
                         concatenate: ([Data]) async throws -> Data = VideoAssemblyService.concatenate) async throws -> SceneVideo {
        guard recovered.canAssemble else { throw RecoveryError.incompleteRun }
        try Task.checkCancellation()
        let data = try recovered.clips.map { clip -> Data in
            guard let url = GeneratedVideoStorageService.fileURL(for: clip.videoFileName, documentURL: documentURL) else { throw RecoveryError.invalidRun }
            return try Data(contentsOf: url)
        }
        let combined = try await concatenate(data)
        try Task.checkCancellation()
        return try finish(combined, run: recovered.run, documentURL: documentURL)
    }

    private static func readClip(at directory: URL, run: VideoGenerationRun, cutID: UUID) throws -> GeneratedCutVideo {
        guard directory.resolvingSymlinksInPath().path == directory.standardizedFileURL.path else { throw RecoveryError.invalidRun }
        let clip = try JSONDecoder().decode(GeneratedCutVideo.self, from: Data(contentsOf: directory.appendingPathComponent("clip.json")))
        guard clip.cutID == cutID, clip.sceneID == run.sceneID,
              clip.videoFileName == "\(relativeDirectory(run))/\(cutID.uuidString)/clip.mp4" else { throw RecoveryError.invalidRun }
        try validateMedia(directory.appendingPathComponent("clip.mp4"))
        return clip
    }

    private static func readScene(at directory: URL, run: VideoGenerationRun) throws -> SceneVideo {
        guard directory.resolvingSymlinksInPath().path == directory.standardizedFileURL.path else { throw RecoveryError.invalidRun }
        let scene = try JSONDecoder().decode(SceneVideo.self, from: Data(contentsOf: directory.appendingPathComponent("scene.json")))
        guard scene.sceneID == run.sceneID, scene.videoFileName == "\(relativeDirectory(run))/combined/scene.mp4" else { throw RecoveryError.invalidRun }
        try validateMedia(directory.appendingPathComponent("scene.mp4"))
        return scene
    }

    private static func validateMedia(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? 0) > 0 else { throw RecoveryError.invalidRun }
    }

    private static func relativeDirectory(_ run: VideoGenerationRun) -> String {
        "generation/\(run.projectID.uuidString)/\(run.id.uuidString)"
    }

    private static func runDirectory(_ run: VideoGenerationRun, documentURL: URL) -> URL {
        documentURL.deletingLastPathComponent().appendingPathComponent("movies/\(relativeDirectory(run))", isDirectory: true)
            .standardizedFileURL.resolvingSymlinksInPath()
    }
}
