import SwiftUI

struct StoryGraphEditorView: View {
    @Binding var document: StoryboardDocument
    var language: String
    @Environment(\.dismiss) private var dismiss
    @State private var selectedScene: UUID?
    @State private var baseline: StoryGraphEditingService.Draft?
    @State private var runs: [StoryGraphEditingService.Run] = []
    @State private var errorMessage: String?

    private var changed: Bool { baseline.map { $0.runs != runs } ?? false }
    private var scenes: [StoryboardScene] { document.project.scenes(language: language) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(t("Story Graph 本文編集", "Story Graph Manuscript", "Story Graph 正文编辑"))
                .font(.title2.bold())
            Text(t("テキスト範囲ごとに本文と書式を編集します。段落・画像・分岐は保持されます。", "Edit text and formatting within each run. Paragraphs, images and branches are preserved.", "逐段编辑文本范围及格式，保留段落、图像和分支。"))
                .font(.callout).foregroundStyle(.secondary)
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
                LazyVStack(alignment: .leading, spacing: 16) {
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
                            TextEditor(text: $runs[index].text)
                                .font(.body)
                                .frame(minHeight: 96, maxHeight: 160)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
                        }
                        .padding(12)
                        .background(CinemaDesign.insetSurface, in: RoundedRectangle(cornerRadius: 8))
                    }
                    if baseline != nil && runs.isEmpty {
                        Text(t("編集可能なテキスト範囲がありません。画像・コードなどは保持されます。", "There are no editable text runs. Images and code remain preserved.", "没有可编辑的文本范围。图像和代码将被保留。"))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 2)
            }
            HStack {
                Button(changed ? t("変更を破棄して閉じる", "Discard and Close", "放弃更改并关闭") : t("閉じる", "Close", "关闭")) { dismiss() }
                Spacer()
                Button(t("元に戻す", "Reset", "重置"), action: load).disabled(!changed)
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

    private func load() {
        baseline = nil; runs = []; errorMessage = nil
        guard let selectedScene else { return }
        do {
            let draft = try StoryGraphEditingService.draft(document, sceneID: selectedScene)
            baseline = draft; runs = draft.runs
        } catch { show(error) }
    }
    private func apply() {
        guard let baseline else { return }
        do {
            document = try StoryGraphEditingService.applying(runs, draft: baseline, to: document)
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
