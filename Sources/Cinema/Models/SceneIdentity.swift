import Foundation

struct StoryboardScene: Identifiable, Equatable {
    var id: UUID
    var title: String
    var cuts: [StoryboardCut]
    var key: String { id.uuidString }
}

extension StoryboardProject {
    static func scenes(from cuts: [StoryboardCut], language: String) -> [StoryboardScene] {
        var scenes: [StoryboardScene] = []
        for cut in cuts {
            let heading = cut.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if scenes.isEmpty || !heading.isEmpty || (cut.sceneID != nil && cut.sceneID != scenes.last?.id) {
                scenes.append(StoryboardScene(
                    id: cut.sceneID ?? cut.id,
                    title: heading.isEmpty ? CinemaStrings.blockName(scenes.count + 1, language: language) : heading,
                    cuts: [cut]
                ))
            } else {
                scenes[scenes.count - 1].cuts.append(cut)
            }
        }
        return scenes
    }

    func scenes(language: String) -> [StoryboardScene] {
        Self.scenes(from: cuts, language: language)
    }

    /// Old documents describe boundaries using subtitles. Once assigned, identities
    /// survive renames, heading deletion, and reordering within a block.
    mutating func normalizeSceneIdentities() {
        var currentID: UUID?
        var usedIDs = Set<UUID>()
        for index in cuts.indices {
            let startsBlock = index == 0 || !cuts[index].subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if startsBlock {
                let candidate = cuts[index].sceneID ?? cuts[index].id
                currentID = usedIDs.insert(candidate).inserted ? candidate : UUID()
            }
            cuts[index].sceneID = currentID
        }
        let sections = scenes(language: "ja")
        let legacyStates = sceneStates.filter { $0.sceneID == nil }
        for section in sections {
            if let index = sceneStates.firstIndex(where: { $0.sceneID == section.id }) {
                sceneStates[index].title = section.title
                sceneStates[index].sceneKey = section.key
                continue
            }
            let aliases = Set([section.title] + (section.cuts.first?.subtitle.isEmpty == true
                ? [CinemaStrings.blockName(1, language: "en"), CinemaStrings.blockName(1, language: "zh-Hans")] : []))
            guard let old = legacyStates.first(where: { aliases.contains($0.sceneKey) || aliases.contains($0.title) }) else { continue }
            var state = old
            state.sceneID = section.id
            state.sceneKey = section.key
            state.title = section.title
            if let index = sceneStates.firstIndex(where: { $0.id == old.id && $0.sceneID == nil }) {
                sceneStates[index] = state
            } else {
                // A legacy same-name block shared one state. Preserve its content
                // as independent copies rather than losing one of the blocks.
                state.id = UUID()
                sceneStates.append(state)
            }
        }
        for index in generatedCutVideos.indices {
            if let scene = sections.first(where: { $0.cuts.contains { $0.id == generatedCutVideos[index].cutID } }) {
                generatedCutVideos[index].sceneID = scene.id
                generatedCutVideos[index].sceneTitle = scene.title
            }
        }
        for index in sceneVideos.indices {
            if let sceneID = sceneVideos[index].sceneID {
                if let scene = sections.first(where: { $0.id == sceneID }) { sceneVideos[index].title = scene.title }
            } else {
                let matches = sections.filter { $0.title == sceneVideos[index].title }
                // Do not guess which block owns a legacy same-name combined movie.
                if matches.count == 1 { sceneVideos[index].sceneID = matches[0].id }
            }
        }
    }

    func sceneState(for sceneID: UUID) -> SceneState? {
        sceneStates.first { $0.sceneID == sceneID }
    }

    mutating func moveCut(_ cutID: UUID, relativeTo targetID: UUID, after: Bool) {
        guard cutID != targetID,
              let source = cuts.firstIndex(where: { $0.id == cutID }),
              let target = cuts.first(where: { $0.id == targetID }) else { return }
        let sections = scenes(language: "ja")
        var moved = cuts.remove(at: source)
        moved.sceneID = target.sceneID
        moved.subtitle = ""
        moved.scriptHeading = ""
        moved.sceneName = ""
        guard let destination = cuts.firstIndex(where: { $0.id == targetID }) else { return }
        cuts.insert(moved, at: destination + (after ? 1 : 0))
        // Preserve headings on the first surviving cut of each original scene.
        for section in sections {
            guard let first = cuts.firstIndex(where: { $0.sceneID == section.id }),
                  let heading = section.cuts.first else { continue }
            for index in cuts.indices where cuts[index].sceneID == section.id {
                cuts[index].subtitle = ""
                cuts[index].scriptHeading = ""
                cuts[index].sceneName = ""
            }
            cuts[first].subtitle = heading.subtitle
            cuts[first].scriptHeading = heading.scriptHeading
            cuts[first].sceneName = heading.sceneName
        }
        normalizeSceneIdentities()
        for index in cuts.indices { cuts[index].cutNumber = index + 1 }
    }
}
