import Foundation

struct CinemaSceneBundleManifest: Codable, Equatable {
    static let format = "cinema.scene-bundle"
    static let schemaVersion = "1.0.0"
    static let promptVersion = "cinema.prompt.v1"

    var format: String
    var schemaVersion: String
    var promptVersion: String
    var exportedAt: Date
    var project: CinemaExportProject
    var scene: CinemaExportScene
    var capture: CinemaExportCapture
    var generation: CinemaExportGeneration
    var cuts: [CinemaExportCut]
    var references: [CinemaExportReference]
    var warnings: [String]
}

struct CinemaExportProject: Codable, Equatable {
    var title: String
    var context: ProjectContext
    var drawingPreset: DrawingPreset
}

struct CinemaExportScene: Codable, Equatable {
    var title: String
    var key: String
    var state: SceneState?
    var scenePromptPath: String
    var worldStatePromptPath: String
}

struct CinemaExportCapture: Codable, Equatable {
    var aspectRatioID: String
    var aspectRatioLabel: String
    var aspectRatio: Double
}

struct CinemaExportGeneration: Codable, Equatable {
    var application: String
    var applicationVersion: String
    var imageProvider: String
    var imageModel: String
    var videoProvider: String
    var videoModel: String
}

struct CinemaExportCut: Codable, Equatable {
    var id: UUID
    var number: Int
    var name: String
    var block: String
    var sequence: String
    var sceneName: String
    var situation: String
    var action: String
    var dialogue: [DialogueLine]
    var duration: String
    var durationSeconds: Double?
    var shotSettings: AIShotSettings
    var shotDelta: ShotDelta
    var referenceIDs: [ReferenceImage.ID]
    var storyboardImagePath: String?
    var imagePromptPath: String
    var videoPromptPath: String
}

struct CinemaExportReference: Codable, Equatable {
    var id: UUID
    var name: String
    var details: [DrawingSettingsSection]
    var assetPath: String?
}

struct CinemaSceneExportConfiguration: Equatable {
    var aspectRatio: ScreenAspectRatio
    var aspectRatioLanguage: String
    var imageProvider: String
    var imageModel: String
    var videoProvider: String
    var videoModel: String
    var applicationVersion: String
}

enum CinemaSceneBundleExporter {
    enum ExportError: LocalizedError {
        case noCuts

        var errorDescription: String? {
            switch self {
            case .noCuts:
                return "The scene bundle must contain at least one cut."
            }
        }
    }

    static func export(
        project: StoryboardProject,
        sceneTitle: String,
        cuts: [StoryboardCut],
        imageData: [String: Data],
        configuration: CinemaSceneExportConfiguration,
        to baseURL: URL,
        exportedAt: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> URL {
        guard !cuts.isEmpty else { throw ExportError.noCuts }

        let directoryName = "\(safePathComponent(sceneTitle, fallback: "untitled_scene"))_cinema_bundle_v1"
        let bundleURL = uniqueDirectoryURL(baseURL.appendingPathComponent(directoryName), fileManager: fileManager)
        let promptsURL = bundleURL.appendingPathComponent("prompts", isDirectory: true)
        let storyboardURL = bundleURL.appendingPathComponent("storyboard", isDirectory: true)
        let referencesURL = bundleURL.appendingPathComponent("references", isDirectory: true)

        try fileManager.createDirectory(at: promptsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: storyboardURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: referencesURL, withIntermediateDirectories: true)

        let references = referencedImages(for: cuts, in: project.referenceImages)
        let drawingPrompt = drawingPrompt(project: project, references: references)
        let scenePrompt = AIPromptBuilder.scenePrompt(
            title: sceneTitle,
            cuts: cuts,
            drawingPrompt: drawingPrompt,
            isSingleCutGeneration: cuts.count == 1
        )
        let sceneState = sceneState(for: sceneTitle, in: project.sceneStates)
        let worldStatePrompt = worldStatePrompt(sceneTitle: sceneTitle, state: sceneState, cuts: cuts)

        try write(scenePrompt, to: promptsURL.appendingPathComponent("scene.txt"))
        try write(worldStatePrompt, to: promptsURL.appendingPathComponent("world-state.txt"))

        var warnings: [String] = []
        var exportedReferences: [CinemaExportReference] = []

        for reference in references {
            let relativePath = "references/\(reference.id.uuidString).\(fileExtension(reference.imageFileName))"
            if let data = imageData[reference.imageFileName] {
                try data.write(to: bundleURL.appendingPathComponent(relativePath), options: .atomic)
                exportedReferences.append(exportReference(reference, assetPath: relativePath))
            } else {
                warnings.append("Missing reference image data for \(reference.id.uuidString).")
                exportedReferences.append(exportReference(reference, assetPath: nil))
            }
        }

        var exportedCuts: [CinemaExportCut] = []
        for (index, cut) in cuts.enumerated() {
            let number = String(format: "%03d", cut.cutNumber)
            let previousCut = index > 0 ? cuts[index - 1] : nil
            let cutCorePrompt = AIPromptBuilder.cutPrompt(for: cut, previousCut: previousCut)
            let imagePrompt = [drawingPrompt, worldStatePrompt, cutCorePrompt]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: "\n\n")
            let videoPrompt = [
                "Scene: \(sceneTitle)",
                durationLine(for: cut),
                worldStatePrompt,
                cutCorePrompt
            ]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")

            let imagePromptPath = "prompts/cut-\(number)-image.txt"
            let videoPromptPath = "prompts/cut-\(number)-video.txt"
            try write(imagePrompt, to: bundleURL.appendingPathComponent(imagePromptPath))
            try write(videoPrompt, to: bundleURL.appendingPathComponent(videoPromptPath))

            var storyboardImagePath: String?
            if let imageFileName = cut.imageFileName {
                if let data = imageData[imageFileName] {
                    let relativePath = "storyboard/cut-\(number).\(fileExtension(imageFileName))"
                    try data.write(to: bundleURL.appendingPathComponent(relativePath), options: .atomic)
                    storyboardImagePath = relativePath
                } else {
                    warnings.append("Missing storyboard image data for cut \(cut.cutNumber).")
                }
            }

            exportedCuts.append(
                CinemaExportCut(
                    id: cut.id,
                    number: cut.cutNumber,
                    name: cut.cutName,
                    block: cut.subtitle,
                    sequence: cut.scriptHeading,
                    sceneName: cut.sceneName,
                    situation: cut.situation,
                    action: cut.action,
                    dialogue: cut.dialogueLines,
                    duration: cut.duration,
                    durationSeconds: durationSeconds(cut.duration),
                    shotSettings: cut.aiShotSettings,
                    shotDelta: cut.shotDelta,
                    referenceIDs: cut.enabledReferenceImageIDs,
                    storyboardImagePath: storyboardImagePath,
                    imagePromptPath: imagePromptPath,
                    videoPromptPath: videoPromptPath
                )
            )
        }

        let manifest = CinemaSceneBundleManifest(
            format: CinemaSceneBundleManifest.format,
            schemaVersion: CinemaSceneBundleManifest.schemaVersion,
            promptVersion: CinemaSceneBundleManifest.promptVersion,
            exportedAt: exportedAt,
            project: CinemaExportProject(
                title: project.title,
                context: project.projectContext,
                drawingPreset: project.drawingSettings.selectedPreset
            ),
            scene: CinemaExportScene(
                title: sceneTitle,
                key: sceneState?.sceneKey.isEmpty == false ? sceneState?.sceneKey ?? sceneTitle : sceneTitle,
                state: sceneState,
                scenePromptPath: "prompts/scene.txt",
                worldStatePromptPath: "prompts/world-state.txt"
            ),
            capture: CinemaExportCapture(
                aspectRatioID: configuration.aspectRatio.rawValue,
                aspectRatioLabel: configuration.aspectRatio.label(language: configuration.aspectRatioLanguage),
                aspectRatio: Double(configuration.aspectRatio.ratio)
            ),
            generation: CinemaExportGeneration(
                application: "Cinema",
                applicationVersion: configuration.applicationVersion,
                imageProvider: configuration.imageProvider,
                imageModel: configuration.imageModel,
                videoProvider: configuration.videoProvider,
                videoModel: configuration.videoModel
            ),
            cuts: exportedCuts,
            references: exportedReferences,
            warnings: warnings
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: bundleURL.appendingPathComponent("manifest.json"), options: .atomic)
        try write(readmeText(), to: bundleURL.appendingPathComponent("README.txt"))

        return bundleURL
    }

    private static func sceneState(for title: String, in states: [SceneState]) -> SceneState? {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return states.first { state in
            state.sceneKey.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedTitle
                || state.title.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedTitle
        }
    }

    private static func referencedImages(for cuts: [StoryboardCut], in references: [ReferenceImage]) -> [ReferenceImage] {
        var seen = Set<ReferenceImage.ID>()
        return cuts.flatMap(\.enabledReferenceImageIDs).compactMap { id in
            guard seen.insert(id).inserted else { return nil }
            return references.first { $0.id == id }
        }
    }

    private static func drawingPrompt(project: StoryboardProject, references: [ReferenceImage]) -> String {
        let referencePrompt = references.enumerated().compactMap { index, reference -> String? in
            let text = reference.promptText().trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : "Reference image \(index + 1):\n\(text)"
        }
        .joined(separator: "\n\n")

        return [
            project.projectContext.promptText,
            project.drawingSettings.promptText(),
            referencePrompt.isEmpty ? "" : "Reference image details:\n\(referencePrompt)"
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: "\n\n")
    }

    private static func worldStatePrompt(sceneTitle: String, state: SceneState?, cuts: [StoryboardCut]) -> String {
        guard let state else {
            let continuity = cuts.flatMap(\.shotDelta.continuityRequirements).filter { !$0.isEmpty }
            return (["Scene world state: \(sceneTitle)"] + continuity.map { "- \($0)" }).joined(separator: "\n")
        }

        let categories = [
            state.characterState,
            state.objectState,
            state.environmentState,
            state.cameraState,
            state.lightingState,
            state.eventState,
            state.timelineState,
            state.audioState
        ]
        .compactMap(categoryPrompt)

        let rules = (state.persistenceRules + state.conservationRules + state.causalityRules)
            .filter(\.isEnabled)
            .map { "- [\($0.kind.rawValue)] \($0.title): \($0.rule)" }

        let events = state.eventGraph.events.map { event in
            "- \(event.title) [\(event.startTime)-\(event.endTime)]: \(event.description)"
        }
        let transitions = state.eventGraph.stateTransitions.map { transition in
            "- \(transition.fromStateID) -> \(transition.toStateID): \(transition.summary)"
        }
        let cameraObservations = cuts.compactMap { cut -> String? in
            let summary = cut.shotDelta.cameraObservation.framingSummary.trimmingCharacters(in: .whitespacesAndNewlines)
            return summary.isEmpty ? nil : "- Cut \(cut.cutNumber): \(summary)"
        }

        return [
            "Scene world state: \(sceneTitle)",
            labeled("Initial state", state.eventGraph.initialStateSummary),
            categories.isEmpty ? "" : "Persistent state:\n\(categories.joined(separator: "\n\n"))",
            rules.isEmpty ? "" : "Persistent rules:\n\(rules.joined(separator: "\n"))",
            events.isEmpty ? "" : "Event sequence:\n\(events.joined(separator: "\n"))",
            transitions.isEmpty ? "" : "State transitions:\n\(transitions.joined(separator: "\n"))",
            cameraObservations.isEmpty ? "" : "Camera observations:\n\(cameraObservations.joined(separator: "\n"))"
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }

    private static func categoryPrompt(_ category: SceneStateCategory) -> String? {
        let summary = category.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let fields = category.fields.compactMap { field -> String? in
            let key = field.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty || !value.isEmpty else { return nil }
            return "- \(key.isEmpty ? "Detail" : key): \(value)"
        }
        guard !summary.isEmpty || !fields.isEmpty else { return nil }
        return ["[\(category.title)]", summary, fields.joined(separator: "\n")]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func exportReference(_ reference: ReferenceImage, assetPath: String?) -> CinemaExportReference {
        CinemaExportReference(id: reference.id, name: reference.name, details: reference.details, assetPath: assetPath)
    }

    private static func durationLine(for cut: StoryboardCut) -> String {
        let value = cut.duration.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "" : "Duration seconds: \(value)"
    }

    private static func durationSeconds(_ value: String) -> Double? {
        Double(value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
    }

    private static func labeled(_ label: String, _ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : "\(label):\n\(trimmed)"
    }

    private static func write(_ text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func fileExtension(_ fileName: String) -> String {
        let ext = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        return ext.isEmpty ? "png" : ext
    }

    private static func safePathComponent(_ value: String, fallback: String) -> String {
        let invalid = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let sanitized = value.components(separatedBy: invalid).joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? fallback : sanitized
    }

    private static func uniqueDirectoryURL(_ proposedURL: URL, fileManager: FileManager) -> URL {
        guard fileManager.fileExists(atPath: proposedURL.path) else { return proposedURL }
        var suffix = 2
        while fileManager.fileExists(atPath: proposedURL.path + "-\(suffix)") {
            suffix += 1
        }
        return URL(fileURLWithPath: proposedURL.path + "-\(suffix)", isDirectory: true)
    }

    private static func readmeText() -> String {
        """
        Cinema Scene Bundle v1

        manifest.json          Stable machine-readable handoff manifest
        prompts/scene.txt      Scene-level generation prompt
        prompts/world-state.txt Structured continuity and world-state prompt
        prompts/cut-*-image.txt Per-cut image generation prompts
        prompts/cut-*-video.txt Per-cut video generation prompts
        storyboard/            Generated storyboard frames, when available
        references/            Referenced source images, when available

        Paths in manifest.json are relative to this directory. API keys and local absolute paths are never exported.
        """
    }
}
