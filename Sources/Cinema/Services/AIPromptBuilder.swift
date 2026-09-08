import Foundation

enum AIPromptBuilder {
    static func cutPrompt(for cut: StoryboardCut, previousCut: StoryboardCut? = nil) -> String {
        var sections = [
            labeled("Scene content", cut.situation),
            labeled("Action direction", cut.action),
            labeled("Names and dialogue", dialoguePrompt(for: cut)),
            labeled("Structured shot direction", cut.aiShotSettings.promptText),
            labeled("Additional cut direction", cut.generationPrompt)
        ]

        let hasCutContent = sections.contains { !$0.isEmpty }

        if let previousCut, !requestsContinuityReset(cut) {
            let handoff = [
                labeled("Previous cut ending state", previousCut.aiShotSettings.endState),
                labeled("Previous cut action", previousCut.action),
                labeled("Required transition", previousCut.aiShotSettings.transition)
            ]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

            if !handoff.isEmpty {
                sections.insert("Continuity from previous cut:\n\(handoff)", at: 0)
            }

            sections.insert(sameSceneContinuityContract(for: cut), at: 0)
        } else if hasCutContent {
            sections.insert(sceneResetContract, at: 0)
        }

        return sections.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    static func requestsContinuityReset(_ cut: StoryboardCut) -> Bool {
        if !cut.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        let transition = cut.aiShotSettings.transition.lowercased()
        let markers = [
            "scene change", "new scene", "hard cut to", "time jump", "location change",
            "場面転換", "新しい場面", "別の場所", "場所転換", "時間経過", "タイムジャンプ",
            "场景切换", "新场景", "地点切换", "时间跳跃"
        ]
        return markers.contains { transition.contains($0) }
    }

    private static func sameSceneContinuityContract(for cut: StoryboardCut) -> String {
        let explicitChanges = [
            labeledFields("Character changes", cut.shotDelta.characterChanges),
            labeledFields("Object changes", cut.shotDelta.objectChanges),
            labeledFields("Environment changes", cut.shotDelta.environmentChanges),
            labeledFields("Camera changes", cut.shotDelta.cameraChanges),
            labeledFields("Lighting changes", cut.shotDelta.lightingChanges),
            labeledFields("Timeline changes", cut.shotDelta.timelineChanges),
            cut.shotDelta.continuityRequirements.isEmpty
                ? ""
                : "Continuity requirements:\n- \(cut.shotDelta.continuityRequirements.joined(separator: "\n- "))"
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")

        return [
            "SAME-SCENE CONTINUITY CONTRACT (higher priority than the creative preset):",
            "Use the immediately preceding frame as binding visual evidence, not loose inspiration.",
            "Match the apparent time of day, weather and wetness, atmosphere, practical light sources, key/fill direction and ratio, color temperature, white balance, exposure, black level, contrast, saturation, film response, and color grade.",
            "Preserve character identity, age, hair, wardrobe colors and materials, props, vehicles, architecture, platform geometry, and screen direction.",
            "The creative/drawing preset may change rendering craft and production polish only. It must not introduce a new palette, relight the location, cool or warm the white balance, or replace established production design.",
            "Change only details explicitly requested by the current cut or listed below. If no change is specified, carry the previous value forward exactly.",
            explicitChanges
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }

    private static let sceneResetContract = """
    NEW-SCENE RESET CONTRACT:
    Establish this cut from its own scene description, Scene State, and selected references.
    Do not inherit lighting, palette, geography, weather, wardrobe, props, or composition from an earlier scene unless the current cut explicitly requests a match.
    The creative/drawing preset may define the new scene's visual treatment.
    """

    private static func labeledFields(_ label: String, _ fields: [DrawingSettingsField]) -> String {
        let values = fields.compactMap { field -> String? in
            let key = field.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty || !value.isEmpty else { return nil }
            return key.isEmpty ? value : "\(key): \(value)"
        }
        return values.isEmpty ? "" : "\(label):\n- \(values.joined(separator: "\n- "))"
    }

    static func scenePrompt(
        title: String,
        cuts: [StoryboardCut],
        drawingPrompt: String,
        isSingleCutGeneration: Bool,
        previousCut: StoryboardCut? = nil
    ) -> String {
        let cutDescriptions = cuts.enumerated().map { index, cut in
            [
                "Cut \(cut.cutNumber)",
                labeled("Duration seconds", cut.duration),
                cutPrompt(
                    for: cut,
                    previousCut: index > 0 ? cuts[index - 1] : previousCut
                )
            ]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        }
        .joined(separator: "\n\n")

        return [
            isSingleCutGeneration
                ? "Generate one cinematic shot that belongs to a continuous storyboard sequence."
                : "Create a cinematic preview for the selected storyboard scene.",
            "Scene title: \(title)",
            labeled("Drawing and continuity bible", drawingPrompt),
            "Preserve character identity, wardrobe, props, location geometry, screen direction, lighting, and color across every cut.",
            "Treat the supplied storyboard frame as composition guidance and, when supported, as the opening frame.",
            "Do not merge separate cuts into an unplanned montage. Respect the specified opening state, ending state, movement, duration, and transition.",
            cutDescriptions
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }

    static func dialoguePrompt(for cut: StoryboardCut) -> String {
        let dialogue = cut.dialogueLines.compactMap { line -> String? in
            let speaker = line.speaker.trimmingCharacters(in: .whitespacesAndNewlines)
            let text = line.dialogue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !speaker.isEmpty || !text.isEmpty else { return nil }
            return speaker.isEmpty ? text : "\(speaker): \(text)"
        }
        .joined(separator: "\n")

        return dialogue.isEmpty ? cut.action.trimmingCharacters(in: .whitespacesAndNewlines) : dialogue
    }

    static func worldStatePrompt(sceneTitle: String, state: SceneState?, cuts: [StoryboardCut]) -> String {
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

    private static func labeled(_ label: String, _ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : "\(label):\n\(trimmed)"
    }
}
