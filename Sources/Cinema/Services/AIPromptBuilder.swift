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

        if let previousCut {
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
        }

        return sections.filter { !$0.isEmpty }.joined(separator: "\n\n")
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

    private static func labeled(_ label: String, _ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : "\(label):\n\(trimmed)"
    }
}
