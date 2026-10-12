import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Scene-scoped actions keep file commands attached to the active document window.
struct ProjectFileActions {
    var editStoryGraph: () -> Void
    var hasStoryGraph: Bool
    var exportStoryGraph: (Bool) -> Void
    var savePortableProject: () -> Void
    var isSaved: Bool
    var isGenerating: Bool
    var canRetryMediaCopy: Bool
    var retryMediaCopy: () -> Void
    var chooseOriginalMoviesFolder: () -> Void
}

private struct ProjectFileActionsKey: FocusedValueKey {
    typealias Value = ProjectFileActions
}

extension FocusedValues {
    var projectFileActions: ProjectFileActions? {
        get { self[ProjectFileActionsKey.self] }
        set { self[ProjectFileActionsKey.self] = newValue }
    }
}

struct ProjectFileCommands: Commands {
    @Environment(\.newDocument) private var newDocument
    @FocusedValue(\.projectFileActions) private var actions
    var language: String

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Button(t("動画込みで作品コピーを保存…", "Save Portable Project Copy…", "保存含视频的项目副本…")) {
                actions?.savePortableProject()
            }
            .disabled(actions == nil || (actions?.isGenerating ?? false))
        }
        CommandGroup(after: .importExport) {
            Menu(t("インポート", "Import", "导入")) {
                Button("Story Graph…", action: importStoryGraph)
            }
            Button(t("Story Graph 本文を編集…", "Edit Story Graph Manuscript…", "编辑 Story Graph 正文…")) { actions?.editStoryGraph() }
                .disabled(actions == nil || !(actions?.hasStoryGraph ?? false) || (actions?.isGenerating ?? false))
            Menu(t("エクスポート", "Export", "导出")) {
                Button("Story Graph…") { actions?.exportStoryGraph(false) }
                Button(t("Story Graph（新しいグラフ）…", "Story Graph (New Graph)…", "Story Graph（新图）…")) {
                    actions?.exportStoryGraph(true)
                }
            }
            .disabled(actions == nil)
            Menu(t("プロジェクトファイルの管理", "Manage Project Files", "管理项目文件")) {
                MediaRecoveryMenu(
                    language: language,
                    isSaved: actions?.isSaved ?? false,
                    isGenerating: actions?.isGenerating ?? false,
                    canRetry: actions?.canRetryMediaCopy ?? false,
                    retry: { actions?.retryMediaCopy() },
                    choose: { actions?.chooseOriginalMoviesFolder() }
                )
            }
            .disabled(actions == nil)
        }
    }

    private func t(_ ja: String, _ en: String, _ zh: String) -> String {
        language == "en" ? en : language == "zh-Hans" ? zh : ja
    }

    private func importStoryGraph() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= StoryGraphService.limit else { throw StoryGraphService.BridgeError.tooLarge }
            let imported = try StoryGraphService.read(Data(contentsOf: url, options: .mappedIfSafe))
            newDocument(imported)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Story Graph"
            alert.informativeText = (error as? StoryGraphService.BridgeError)?.message(language: language) ?? error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
