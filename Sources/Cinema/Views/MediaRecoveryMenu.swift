import SwiftUI

struct MediaRecoveryLabels {
    var language: String
    private func t(_ ja: String, _ en: String, _ zh: String) -> String { language == "en" ? en : language == "zh-Hans" ? zh : ja }
    var title: String { t("動画の保存先を復旧", "Recover Video Files", "恢复视频文件") }
    var retry: String { t("動画のコピーを再試行", "Retry Media Copy", "重试视频复制") }
    var choose: String { t("元のmoviesフォルダを選択…", "Choose Original movies Folder…", "选择原movies文件夹…") }
    func help(isSaved: Bool, isGenerating: Bool) -> String {
        if !isSaved { return t("復旧先を確定するため、先にプロジェクトを保存してください。", "Save the project first to establish the recovery destination.", "请先保存项目以确定恢复目标位置。") }
        if isGenerating { return t("動画生成が終了してから復旧できます。", "Recovery is available after video generation finishes.", "视频生成结束后可恢复文件。") }
        return t("元の動画を現在の保存先へコピーします。元ファイルは保持し、異なる既存ファイルは上書きしません。", "Copy original videos to the current location. Originals are preserved and different existing files are never overwritten.", "将原视频复制到当前位置。保留原文件，不覆盖内容不同的现有文件。")
    }
}

struct MediaRecoveryMenu: View {
    var language: String
    var isSaved: Bool
    var isGenerating: Bool
    var canRetry: Bool
    var retry: () -> Void
    var choose: () -> Void
    private var labels: MediaRecoveryLabels { MediaRecoveryLabels(language: language) }
    var body: some View {
        Menu(labels.title) {
            if canRetry { Button(labels.retry, action: retry) }
            Button(labels.choose, action: choose)
        }
        .disabled(!isSaved || isGenerating)
        .help(labels.help(isSaved: isSaved, isGenerating: isGenerating))
    }
}
