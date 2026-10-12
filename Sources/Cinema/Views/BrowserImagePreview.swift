import SwiftUI
import AppKit

struct BrowserImagePreview: View {
    var image: GeneratedImage
    var data: Data?
    var language: String
    @Environment(\.dismiss) private var dismiss
    private func text(_ ja: String, _ en: String, _ zh: String) -> String { language == "en" ? en : language == "zh-Hans" ? zh : ja }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(image.title).font(.title2).lineLimit(2)
                Spacer()
                Button(text("閉じる", "Close", "关闭")) { dismiss() }.fixedSize()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Group {
                        if let data, let bitmap = NSImage(data: data) { Image(nsImage: bitmap).resizable().scaledToFit() }
                        else { Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary) }
                    }.frame(height: 260).frame(maxWidth: .infinity).padding(.horizontal, 16)
                    Text("\(image.provider) · \(image.model) · \(String(format: "%.3f", image.aspectRatio))").foregroundStyle(.secondary)
                    Text(image.generatedAt, style: .date)
                    Text(text("プロンプト", "Prompt", "提示词")).font(.headline)
                    Text(image.prompt).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                    Text(text("生成時の設定・コンテキスト", "Generation Settings / Context", "生成设置与上下文")).font(.headline)
                    Text(image.context).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                }
            }
            Button(text("プロンプトをコピー", "Copy Prompt", "复制提示词")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(image.prompt + "\n\n" + image.context, forType: .string)
            }
        }.padding(16).frame(minWidth: 380, idealWidth: 620, minHeight: 540, idealHeight: 620)
            .environment(\.locale, Locale(identifier: language == "en" ? "en_US" : language == "zh-Hans" ? "zh_CN" : "ja_JP"))
    }
}
