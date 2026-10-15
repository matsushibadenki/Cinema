import SwiftUI

struct StoryGraphEditorView: View {
    @Binding var document: StoryboardDocument
    var language: String
    @Environment(\.dismiss) private var dismiss
    @State private var selectedScene: UUID?
    @State private var baseline: StoryGraphEditingService.Draft?
    @State private var runs: [StoryGraphEditingService.Run] = []
    @State private var paragraphIndices: [Int] = []
    @State private var removals: Set<Int> = []
    @State private var additions: [String] = []
    @State private var errorMessage: String?

    private var changed: Bool { baseline.map { $0.runs != runs || !removals.isEmpty || !additions.isEmpty } ?? false }
    private var scenes: [StoryboardScene] { document.project.scenes(language: language) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(t("Story Graph 本文編集", "Story Graph Manuscript", "Story Graph 正文编辑")).font(.title2.bold())
                Image(systemName: "info.circle").foregroundStyle(.secondary)
                    .help(t("本文・書式・リンクを編集し、段落を追加・削除できます。参照や注釈のある段落は削除を防ぎます。「適用」まで変更は確定しません。", "Edit text, formatting and links; append or remove paragraphs. Referenced or annotated paragraphs are protected. Changes are committed only with Apply.", "编辑正文、格式和链接，添加或删除段落。被引用或有注释的段落受保护。点击应用后才会保存更改。"))
                Spacer()
                Button { additions.append("") } label: { Image(systemName: "text.badge.plus") }
                    .help(t("段落を末尾に追加", "Append Paragraph", "在末尾添加段落"))
                    .accessibilityLabel(t("段落を追加", "Add Paragraph", "添加段落"))
                    .disabled(baseline == nil || additions.count >= 512)
            }
            Picker(t("シーン", "Scene", "场景"), selection: $selectedScene) {
                ForEach(scenes) { scene in
                    Text(scene.cuts.first?.subtitle ?? "Story Graph").tag(Optional(scene.id))
                }
            }
            .disabled(changed)
            .onChange(of: selectedScene) { _, _ in load() }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).textSelection(.enabled)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    VStack(spacing: 6) {
                    ForEach(paragraphIndices, id: \.self) { paragraph in
                        HStack {
                            Text(t("段落", "Paragraph", "段落") + " \(paragraph + 1)").font(.caption)
                            Spacer()
                            Button {
                                if !removals.insert(paragraph).inserted { removals.remove(paragraph) }
                            } label: { Image(systemName: removals.contains(paragraph) ? "arrow.uturn.backward" : "trash") }
                            .help(removals.contains(paragraph) ? t("削除を取り消す", "Undo Removal", "撤销删除") : t("段落を削除", "Remove Paragraph", "删除段落"))
                            .accessibilityLabel(t("段落", "Paragraph", "段落") + " \(paragraph + 1)")
                        }
                    }
                    }
                    ForEach(runs.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(t("テキスト範囲", "Text Run", "文本范围") + " \(index + 1)")
                                .font(.headline)
                            HStack(spacing: 6) {
                                ForEach(StoryGraphEditingService.supportedStyles, id: \.self) { style in
                                    Button {
                                        if runs[index].styles.contains(style) { runs[index].styles.remove(style) }
                                        else { runs[index].styles.insert(style) }
                                    } label: {
                                        Image(systemName: symbol(style))
                                            .accessibilityLabel(styleName(style))
                                    }
                                    .buttonStyle(CinemaStateButtonStyle(isActive: runs[index].styles.contains(style)))
                                    .help(styleName(style))
                                }
                            }
                            HStack(spacing: 6) {
                                Image(systemName: "link").foregroundStyle(.secondary)
                                TextField(t("リンク先", "Link URL", "链接地址"), text: Binding(get: { runs[index].link ?? "" }, set: { runs[index].link = $0.isEmpty ? nil : $0 }))
                                    .textFieldStyle(.roundedBorder)
                                    .help(t("https・http・mailto。空欄でリンクを解除", "https, http or mailto. Clear to remove the link.", "https、http或mailto。清空以移除链接。"))
                            }
                            TextEditor(text: $runs[index].text)
                                .font(.body)
                                .frame(minHeight: 96, maxHeight: 160)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
                        }
                        .disabled(runs[index].path.first.map { removals.contains($0) } ?? false)
                        .opacity((runs[index].path.first.map { removals.contains($0) } ?? false) ? 0.45 : 1)
                        .padding(10)
                        .background(CinemaDesign.insetSurface, in: RoundedRectangle(cornerRadius: 8))
                    }
                    ForEach(additions.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(t("新しい段落", "New Paragraph", "新段落")).font(.caption)
                                Spacer()
                                Button { if additions.indices.contains(index) { additions.remove(at: index) } } label: { Image(systemName: "trash") }
                                    .help(t("追加を取り消す", "Cancel Addition", "取消添加"))
                            }
                            TextEditor(text: Binding(get: { additions.indices.contains(index) ? additions[index] : "" }, set: { if additions.indices.contains(index) { additions[index] = $0 } })).frame(minHeight: 80, maxHeight: 120)
                        }.padding(10).background(CinemaDesign.insetSurface, in: RoundedRectangle(cornerRadius: 8))
                    }
                    if baseline != nil && runs.isEmpty && additions.isEmpty {
                        Text(t("編集可能なテキスト範囲がありません。画像・コードなどは保持されます。", "There are no editable text runs. Images and code remain preserved.", "没有可编辑的文本范围。图像和代码将被保留。"))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 2)
            }
            HStack {
                Button(changed ? t("変更を破棄して閉じる", "Discard and Close", "放弃更改并关闭") : t("閉じる", "Close", "关闭")) { dismiss() }
                Spacer()
                Button(action: load) { Image(systemName: "arrow.counterclockwise") }
                    .help(t("元に戻す", "Reset", "重置")).disabled(!changed)
                Button(t("適用", "Apply", "应用"), action: apply)
                    .buttonStyle(CinemaPrimaryActionButtonStyle())
                    .disabled(!changed || baseline == nil)
            }
        }
        .padding(16)
        .frame(minWidth: 420, idealWidth: 660, minHeight: 480, idealHeight: 680)
        .background(CinemaDesign.canvasBackground)
        .onAppear { if selectedScene == nil { selectedScene = scenes.first?.id }; load() }
    }

    private func paragraphIndices(in baseline: StoryGraphEditingService.Draft) -> [Int] {
        guard let value = try? JSONSerialization.jsonObject(with: baseline.canonical) as? [String: Any],
              let blocks = value["content"] as? [[String: Any]] else { return [] }
        return blocks.indices.filter { blocks[$0]["type"] as? String == "paragraph" }
    }
    private func load() {
        baseline = nil; runs = []; paragraphIndices = []; removals = []; additions = []; errorMessage = nil
        guard let selectedScene else { return }
        do {
            let draft = try StoryGraphEditingService.draft(document, sceneID: selectedScene)
            baseline = draft; runs = draft.runs; paragraphIndices = paragraphIndices(in: draft)
        } catch { show(error) }
    }
    private func apply() {
        guard let baseline else { return }
        do {
            document = try StoryGraphEditingService.applying(runs, draft: baseline, to: document, removing: removals, appending: additions)
            load()
        } catch { show(error) }
    }
    private func show(_ error: Error) {
        errorMessage = (error as? StoryGraphEditingService.EditError)?.message(language)
            ?? (error as? StoryGraphService.BridgeError)?.message(language: language) ?? error.localizedDescription
    }
    private func t(_ ja: String, _ en: String, _ zh: String) -> String { language == "en" ? en : language == "zh-Hans" ? zh : ja }
    private func symbol(_ style: String) -> String {
        switch style { case "bold": "bold"; case "italic": "italic"; case "underline": "underline"; case "strike": "strikethrough"; default: "chevron.left.forwardslash.chevron.right" }
    }
    private func styleName(_ style: String) -> String {
        switch style {
        case "bold": t("太字", "Bold", "粗体")
        case "italic": t("斜体", "Italic", "斜体")
        case "underline": t("下線", "Underline", "下划线")
        case "strike": t("取り消し線", "Strikethrough", "删除线")
        default: t("コード", "Code", "代码")
        }
    }
}
