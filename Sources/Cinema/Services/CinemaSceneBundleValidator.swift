import Foundation

struct CinemaSceneBundleValidationItem: Identifiable, Equatable {
    enum Severity: Int, Comparable {
        case information
        case warning
        case error

        static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    let id: String
    var severity: Severity
    var message: String
}

struct CinemaSceneBundleValidationReport: Equatable {
    var items: [CinemaSceneBundleValidationItem]
    var cutCount: Int
    var referenceCount: Int
    var storyboardImageCount: Int

    var canExport: Bool { !items.contains { $0.severity == .error } }
    var warningCount: Int { items.filter { $0.severity == .warning }.count }
    var errorCount: Int { items.filter { $0.severity == .error }.count }
}

enum CinemaSceneBundleValidator {
    static func validate(
        sceneTitle: String,
        sceneState: SceneState?,
        cuts: [StoryboardCut],
        references: [ReferenceImage],
        imageData: [String: Data],
        language: String
    ) -> CinemaSceneBundleValidationReport {
        var items: [CinemaSceneBundleValidationItem] = []
        let localized = ValidationLocalization(language: language)

        if cuts.isEmpty {
            items.append(.init(id: "no-cuts", severity: .error, message: localized.noCuts))
        }

        if sceneState == nil {
            items.append(.init(id: "no-state", severity: .warning, message: localized.noSceneState))
        } else if let sceneState, !hasMeaningfulState(sceneState) {
            items.append(.init(id: "empty-state", severity: .warning, message: localized.emptySceneState))
        }

        let referenceLookup = Dictionary(uniqueKeysWithValues: references.map { ($0.id, $0) })
        var referencedIDs = Set<ReferenceImage.ID>()
        var storyboardImageCount = 0

        for cut in cuts {
            let prefix = "cut-\(cut.id.uuidString)"
            if AIPromptBuilder.cutPrompt(for: cut).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                items.append(.init(id: "\(prefix)-prompt", severity: .error, message: localized.emptyPrompt(cut.cutNumber)))
            }

            let duration = cut.duration.trimmingCharacters(in: .whitespacesAndNewlines)
            if duration.isEmpty || Double(duration.replacingOccurrences(of: ",", with: ".")) == nil {
                items.append(.init(id: "\(prefix)-duration", severity: .warning, message: localized.invalidDuration(cut.cutNumber)))
            }

            if let fileName = cut.imageFileName {
                if imageData[fileName] == nil {
                    items.append(.init(id: "\(prefix)-image", severity: .warning, message: localized.missingStoryboard(cut.cutNumber)))
                } else {
                    storyboardImageCount += 1
                }
            }

            for referenceID in cut.referenceImageIDs {
                referencedIDs.insert(referenceID)
                guard let reference = referenceLookup[referenceID] else {
                    items.append(.init(id: "\(prefix)-reference-\(referenceID)", severity: .warning, message: localized.unknownReference(cut.cutNumber)))
                    continue
                }
                if imageData[reference.imageFileName] == nil {
                    items.append(.init(id: "reference-image-\(referenceID)", severity: .warning, message: localized.missingReference(reference.name)))
                }
            }
        }

        var seenItemIDs = Set<String>()
        items = items.filter { seenItemIDs.insert($0.id).inserted }

        if items.isEmpty {
            items.append(.init(id: "ready", severity: .information, message: localized.ready(sceneTitle)))
        }

        return CinemaSceneBundleValidationReport(
            items: items.sorted { $0.severity > $1.severity },
            cutCount: cuts.count,
            referenceCount: referencedIDs.count,
            storyboardImageCount: storyboardImageCount
        )
    }

    private static func hasMeaningfulState(_ state: SceneState) -> Bool {
        let categories = [
            state.characterState, state.objectState, state.environmentState, state.cameraState,
            state.lightingState, state.eventState, state.timelineState, state.audioState
        ]
        return categories.contains { !$0.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.fields.isEmpty }
            || !state.persistenceRules.isEmpty
            || !state.conservationRules.isEmpty
            || !state.causalityRules.isEmpty
            || !state.eventGraph.initialStateSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !state.eventGraph.events.isEmpty
            || !state.eventGraph.stateTransitions.isEmpty
    }
}

private struct ValidationLocalization {
    let language: AppLanguage

    init(language: String) {
        self.language = AppLanguage.value(for: language)
    }

    var noCuts: String { value("書き出すカットが選択されていません。", "No cuts are selected for export.", "未选择要导出的镜头。") }
    var noSceneState: String { value("Scene Stateがありません。", "Scene State is missing.", "缺少 Scene State。") }
    var emptySceneState: String { value("Scene Stateは作成済みですが、内容が未入力です。", "Scene State exists but has no content.", "Scene State 已创建，但内容为空。") }
    func emptyPrompt(_ cut: Int) -> String { value("Cut \(cut)は生成プロンプトが空です。", "Cut \(cut) has an empty generation prompt.", "镜头 \(cut) 的生成提示词为空。") }
    func invalidDuration(_ cut: Int) -> String { value("Cut \(cut)の秒数が未設定または数値ではありません。", "Cut \(cut) has a missing or invalid duration.", "镜头 \(cut) 的时长缺失或格式无效。") }
    func missingStoryboard(_ cut: Int) -> String { value("Cut \(cut)の絵コンテ画像データが見つかりません。", "Storyboard image data for cut \(cut) is missing.", "找不到镜头 \(cut) 的分镜图像数据。") }
    func unknownReference(_ cut: Int) -> String { value("Cut \(cut)に存在しないリファレンスが指定されています。", "Cut \(cut) references an unknown asset.", "镜头 \(cut) 引用了不存在的素材。") }
    func missingReference(_ name: String) -> String { value("リファレンス「\(name)」の画像データが見つかりません。", "Image data for reference “\(name)” is missing.", "找不到参考“\(name)”的图像数据。") }
    func ready(_ scene: String) -> String { value("「\(scene)」は書き出し可能です。", "“\(scene)” is ready to export.", "“\(scene)”已可导出。") }

    private func value(_ japanese: String, _ english: String, _ chinese: String) -> String {
        switch language {
        case .japanese: japanese
        case .english: english
        case .simplifiedChinese: chinese
        }
    }
}
