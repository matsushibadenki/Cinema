import SwiftUI

struct SceneStateWorkspaceView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case state
        case preview
        var id: String { rawValue }
    }

    let sceneTitle: String
    @Binding var sceneState: SceneState
    let cuts: [StoryboardCut]
    let references: [ReferenceImage]
    let imageData: [String: Data]
    let appLanguage: String

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Tab = .state

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            Group {
                switch selectedTab {
                case .state:
                    stateEditor
                case .preview:
                    exportPreview
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 900, idealWidth: 1040, minHeight: 680, idealHeight: 760)
        .background(CinemaDesign.panelBackground)
    }

    private var header: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(sceneTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CinemaDesign.ink)
                Text(label(.sceneTruth))
                    .font(.caption)
                    .foregroundStyle(CinemaDesign.mutedInk)
            }

            Spacer()

            HStack(spacing: 2) {
                tabButton(.state, title: label(.sceneState), symbol: "square.stack.3d.up")
                tabButton(.preview, title: label(.exportPreview), symbol: "checklist.checked")
            }
            .frame(width: 360)

            Button(label(.done)) { dismiss() }
                .buttonStyle(CinemaActionButtonStyle())
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .frame(height: 68)
    }

    private func tabButton(_ tab: Tab, title: String, symbol: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(CinemaStateButtonStyle(isActive: selectedTab == tab, expands: true))
    }

    private var stateEditor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sectionHeading(label(.persistentState), detail: label(.persistentStateHelp))

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 18) {
                    categoryEditor(label(.character), keyPath: \.characterState, symbol: "person.2")
                    categoryEditor(label(.object), keyPath: \.objectState, symbol: "shippingbox")
                    categoryEditor(label(.environment), keyPath: \.environmentState, symbol: "mountain.2")
                    categoryEditor(label(.camera), keyPath: \.cameraState, symbol: "camera")
                    categoryEditor(label(.lighting), keyPath: \.lightingState, symbol: "lightbulb")
                    categoryEditor(label(.event), keyPath: \.eventState, symbol: "bolt")
                    categoryEditor(label(.timeline), keyPath: \.timelineState, symbol: "clock")
                    categoryEditor(label(.audio), keyPath: \.audioState, symbol: "waveform")
                }

                Divider()
                rulesEditor
                Divider()
                eventGraphEditor
            }
            .padding(20)
        }
    }

    private func categoryEditor(
        _ title: String,
        keyPath: WritableKeyPath<SceneState, SceneStateCategory>,
        symbol: String
    ) -> some View {
        let category = Binding(
            get: { sceneState[keyPath: keyPath] },
            set: { sceneState[keyPath: keyPath] = $0; sceneState.updatedAt = Date() }
        )

        return VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CinemaDesign.ink)

            TextEditor(text: category.summary)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .padding(7)
                .frame(minHeight: 68)
                .background(CinemaDesign.insetSurface)
                .overlay(Rectangle().stroke(CinemaDesign.fineBorder, lineWidth: 0.7))
                .overlay(alignment: .topLeading) {
                    if category.wrappedValue.summary.isEmpty {
                        Text(label(.summaryPlaceholder))
                            .font(.system(size: 12))
                            .foregroundStyle(CinemaDesign.quietInk)
                            .padding(12)
                            .allowsHitTesting(false)
                    }
                }

            ForEach(category.fields) { $field in
                HStack(spacing: 6) {
                    TextField(label(.key), text: $field.key)
                        .textFieldStyle(.plain)
                        .frame(width: 92)
                    Divider()
                    TextField(label(.value), text: $field.value)
                        .textFieldStyle(.plain)
                    Button {
                        category.wrappedValue.fields.removeAll { $0.id == field.id }
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(CinemaDesign.mutedInk)
                }
                .padding(.horizontal, 8)
                .frame(height: 30)
                .overlay(Rectangle().stroke(CinemaDesign.fineBorder, lineWidth: 0.6))
            }

            Button {
                category.wrappedValue.fields.append(DrawingSettingsField(key: "", value: ""))
            } label: {
                Label(label(.addDetail), systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(CinemaDesign.mutedInk)
        }
        .padding(.bottom, 2)
    }

    private var rulesEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading(label(.rules), detail: label(.rulesHelp))
            ruleGroup(label(.persistence), rules: $sceneState.persistenceRules, kind: .persistence)
            ruleGroup(label(.conservation), rules: $sceneState.conservationRules, kind: .conservation)
            ruleGroup(label(.causality), rules: $sceneState.causalityRules, kind: .causality)
        }
    }

    private func ruleGroup(_ title: String, rules: Binding<[SceneRule]>, kind: SceneRule.Kind) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(CinemaDesign.mutedInk)
            ForEach(rules) { $rule in
                HStack(spacing: 8) {
                    Toggle("", isOn: $rule.isEnabled).labelsHidden().toggleStyle(.checkbox)
                    TextField(label(.ruleName), text: $rule.title).textFieldStyle(.plain).frame(width: 150)
                    Divider()
                    TextField(label(.rule), text: $rule.rule).textFieldStyle(.plain)
                    Button { rules.wrappedValue.removeAll { $0.id == rule.id } } label: { Image(systemName: "trash") }
                        .buttonStyle(.plain).foregroundStyle(CinemaDesign.mutedInk)
                }
                .padding(.horizontal, 8)
                .frame(height: 32)
                .overlay(Rectangle().stroke(CinemaDesign.fineBorder, lineWidth: 0.6))
            }
            Button {
                rules.wrappedValue.append(SceneRule(kind: kind))
            } label: { Label(label(.addRule), systemImage: "plus") }
                .buttonStyle(.plain).font(.caption).foregroundStyle(CinemaDesign.mutedInk)
        }
    }

    private var eventGraphEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading(label(.eventSequence), detail: label(.eventHelp))
            TextField(label(.initialState), text: $sceneState.eventGraph.initialStateSummary)
                .textFieldStyle(.plain)
                .padding(.horizontal, 9)
                .frame(height: 34)
                .overlay(Rectangle().stroke(CinemaDesign.fineBorder, lineWidth: 0.7))

            ForEach($sceneState.eventGraph.events) { $event in
                HStack(spacing: 8) {
                    TextField(label(.eventName), text: $event.title).textFieldStyle(.plain).frame(width: 160)
                    TextField(label(.start), text: $event.startTime).textFieldStyle(.plain).frame(width: 70)
                    Text("→").foregroundStyle(CinemaDesign.quietInk)
                    TextField(label(.end), text: $event.endTime).textFieldStyle(.plain).frame(width: 70)
                    Divider()
                    TextField(label(.description), text: $event.description).textFieldStyle(.plain)
                    Button { sceneState.eventGraph.events.removeAll { $0.id == event.id } } label: { Image(systemName: "trash") }
                        .buttonStyle(.plain).foregroundStyle(CinemaDesign.mutedInk)
                }
                .padding(.horizontal, 8)
                .frame(height: 34)
                .overlay(Rectangle().stroke(CinemaDesign.fineBorder, lineWidth: 0.6))
            }

            Button { sceneState.eventGraph.events.append(SceneEvent()) } label: {
                Label(label(.addEvent), systemImage: "plus")
            }
            .buttonStyle(.plain).font(.caption).foregroundStyle(CinemaDesign.mutedInk)

            Text(label(.transitions)).font(.system(size: 12, weight: .semibold)).foregroundStyle(CinemaDesign.mutedInk)
            ForEach($sceneState.eventGraph.stateTransitions) { $transition in
                HStack(spacing: 8) {
                    TextField(label(.from), text: $transition.fromStateID).textFieldStyle(.plain).frame(width: 130)
                    Image(systemName: "arrow.right").foregroundStyle(CinemaDesign.quietInk)
                    TextField(label(.to), text: $transition.toStateID).textFieldStyle(.plain).frame(width: 130)
                    Divider()
                    TextField(label(.description), text: $transition.summary).textFieldStyle(.plain)
                    Button { sceneState.eventGraph.stateTransitions.removeAll { $0.id == transition.id } } label: { Image(systemName: "trash") }
                        .buttonStyle(.plain).foregroundStyle(CinemaDesign.mutedInk)
                }
                .padding(.horizontal, 8)
                .frame(height: 34)
                .overlay(Rectangle().stroke(CinemaDesign.fineBorder, lineWidth: 0.6))
            }
            Button { sceneState.eventGraph.stateTransitions.append(StateTransition()) } label: {
                Label(label(.addTransition), systemImage: "plus")
            }
            .buttonStyle(.plain).font(.caption).foregroundStyle(CinemaDesign.mutedInk)
        }
    }

    private var exportPreview: some View {
        let report = CinemaSceneBundleValidator.validate(
            sceneTitle: sceneTitle,
            sceneState: sceneState,
            cuts: cuts,
            references: references,
            imageData: imageData,
            language: appLanguage
        )

        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 18) {
                    readinessBadge(report)
                    metric(label(.cuts), value: report.cutCount)
                    metric(label(.storyboardImages), value: report.storyboardImageCount)
                    metric(label(.references), value: report.referenceCount)
                    metric(label(.warnings), value: report.warningCount)
                    Spacer()
                }

                Divider()
                sectionHeading(label(.validation), detail: label(.validationHelp))
                VStack(spacing: 0) {
                    ForEach(report.items) { item in
                        validationRow(item)
                        if item.id != report.items.last?.id { Divider() }
                    }
                }
                .overlay(Rectangle().stroke(CinemaDesign.fineBorder, lineWidth: 0.7))

                Divider()
                sectionHeading(label(.bundleContents), detail: label(.bundleHelp))
                bundleTree
            }
            .padding(20)
        }
    }

    private func readinessBadge(_ report: CinemaSceneBundleValidationReport) -> some View {
        HStack(spacing: 8) {
            Image(systemName: report.canExport ? "checkmark.circle.fill" : "xmark.octagon.fill")
            Text(report.canExport ? label(.ready) : label(.needsAttention))
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(report.canExport ? CinemaDesign.ink : Color.red)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .overlay(Rectangle().stroke(report.canExport ? CinemaDesign.strongBorder : Color.red.opacity(0.7), lineWidth: 0.8))
    }

    private func metric(_ title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(CinemaDesign.quietInk)
            Text("\(value)").font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
        }
        .frame(minWidth: 74, alignment: .leading)
    }

    private func validationRow(_ item: CinemaSceneBundleValidationItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: validationSymbol(item.severity))
                .foregroundStyle(validationColor(item.severity))
                .frame(width: 18)
            Text(item.message).font(.system(size: 12)).foregroundStyle(CinemaDesign.ink)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 38)
    }

    private var bundleTree: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("manifest.json")
            Text("prompts/scene.txt")
            Text("prompts/world-state.txt")
            Text("prompts/cut-###-image.txt")
            Text("prompts/cut-###-video.txt")
            Text("storyboard/cut-###.<ext>")
            Text("references/<uuid>.<ext>")
        }
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(CinemaDesign.mutedInk)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CinemaDesign.insetSurface)
        .overlay(Rectangle().stroke(CinemaDesign.fineBorder, lineWidth: 0.7))
    }

    private func sectionHeading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(CinemaDesign.ink)
            Text(detail).font(.caption).foregroundStyle(CinemaDesign.mutedInk)
        }
    }

    private func validationSymbol(_ severity: CinemaSceneBundleValidationItem.Severity) -> String {
        switch severity {
        case .information: "checkmark.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "xmark.octagon"
        }
    }

    private func validationColor(_ severity: CinemaSceneBundleValidationItem.Severity) -> Color {
        switch severity {
        case .information: CinemaDesign.ink
        case .warning: .orange
        case .error: .red
        }
    }

    private enum CopyKey {
        case sceneTruth, sceneState, exportPreview, done, persistentState, persistentStateHelp
        case character, object, environment, camera, lighting, event, timeline, audio
        case summaryPlaceholder, key, value, addDetail, rules, rulesHelp, persistence, conservation, causality
        case ruleName, rule, addRule, eventSequence, eventHelp, initialState, eventName, start, end, description
        case addEvent, transitions, from, to, addTransition, cuts, storyboardImages, references, warnings
        case validation, validationHelp, bundleContents, bundleHelp, ready, needsAttention
    }

    private func label(_ key: CopyKey) -> String {
        let values: (String, String, String)
        switch key {
        case .sceneTruth: values = ("シーン全体で維持する状態とルール", "Persistent state and rules for the whole scene", "整个场景中持续保持的状态与规则")
        case .sceneState: values = ("Scene State", "Scene State", "Scene State")
        case .exportPreview: values = ("書き出し確認", "Export Preview", "导出预览")
        case .done: values = ("完了", "Done", "完成")
        case .persistentState: values = ("永続的な状態", "Persistent State", "持久状态")
        case .persistentStateHelp: values = ("カット間で変化しない事実を記録します。", "Record facts that remain true across cuts.", "记录在镜头之间保持不变的事实。")
        case .character: values = ("キャラクター", "Character", "角色")
        case .object: values = ("オブジェクト", "Object", "物体")
        case .environment: values = ("環境", "Environment", "环境")
        case .camera: values = ("カメラ", "Camera", "摄影机")
        case .lighting: values = ("照明", "Lighting", "灯光")
        case .event: values = ("イベント", "Event", "事件")
        case .timeline: values = ("タイムライン", "Timeline", "时间线")
        case .audio: values = ("音声", "Audio", "音频")
        case .summaryPlaceholder: values = ("状態の要約", "State summary", "状态摘要")
        case .key: values = ("項目", "Key", "项目")
        case .value: values = ("値", "Value", "值")
        case .addDetail: values = ("詳細を追加", "Add Detail", "添加详细信息")
        case .rules: values = ("継続ルール", "Persistent Rules", "持续规则")
        case .rulesHelp: values = ("生成時に必ず守る不変条件を指定します。", "Define invariants that generation must preserve.", "定义生成时必须保持的不变条件。")
        case .persistence: values = ("維持", "Persistence", "保持")
        case .conservation: values = ("保存", "Conservation", "守恒")
        case .causality: values = ("因果", "Causality", "因果")
        case .ruleName: values = ("ルール名", "Rule name", "规则名称")
        case .rule: values = ("ルール", "Rule", "规则")
        case .addRule: values = ("ルールを追加", "Add Rule", "添加规则")
        case .eventSequence: values = ("イベントと状態遷移", "Events and State Transitions", "事件与状态转换")
        case .eventHelp: values = ("時間順の出来事と、その結果生じる状態を記録します。", "Record events in time order and the states they produce.", "按时间顺序记录事件及其产生的状态。")
        case .initialState: values = ("初期状態", "Initial state", "初始状态")
        case .eventName: values = ("イベント名", "Event name", "事件名称")
        case .start: values = ("開始", "Start", "开始")
        case .end: values = ("終了", "End", "结束")
        case .description: values = ("内容", "Description", "内容")
        case .addEvent: values = ("イベントを追加", "Add Event", "添加事件")
        case .transitions: values = ("状態遷移", "State Transitions", "状态转换")
        case .from: values = ("遷移前", "From", "转换前")
        case .to: values = ("遷移後", "To", "转换后")
        case .addTransition: values = ("状態遷移を追加", "Add Transition", "添加状态转换")
        case .cuts: values = ("カット", "Cuts", "镜头")
        case .storyboardImages: values = ("絵コンテ画像", "Storyboard Images", "分镜图像")
        case .references: values = ("リファレンス", "References", "参考")
        case .warnings: values = ("警告", "Warnings", "警告")
        case .validation: values = ("検証結果", "Validation", "验证结果")
        case .validationHelp: values = ("エラーは書き出し前に修正してください。警告があっても書き出しは可能です。", "Fix errors before export. Warnings do not block export.", "请在导出前修复错误。警告不会阻止导出。")
        case .bundleContents: values = ("Bundle構成", "Bundle Contents", "Bundle 内容")
        case .bundleHelp: values = ("外部runnerはmanifestの相対pathから各ファイルを読み込みます。", "External runners resolve every file relative to the manifest.", "外部运行器根据清单中的相对路径读取文件。")
        case .ready: values = ("書き出し可能", "Ready to Export", "可导出")
        case .needsAttention: values = ("修正が必要", "Needs Attention", "需要修正")
        }
        switch AppLanguage.value(for: appLanguage) {
        case .japanese: return values.0
        case .english: return values.1
        case .simplifiedChinese: return values.2
        }
    }
}
