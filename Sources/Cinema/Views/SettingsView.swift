import AppKit
import SwiftUI

struct SettingsView: View {
    private enum SettingsTab: Hashable {
        case gemini
        case display
    }

    @AppStorage("geminiAPIKey") private var geminiAPIKey = ""
    @AppStorage("geminiModelName") private var geminiModelName = "nano-banana-2"
    @AppStorage("geminiSystemPrompt") private var geminiSystemPrompt = ""
    @AppStorage("imageGenerationProvider") private var imageGenerationProvider = "gemini"
    @AppStorage("openAIAPIKey") private var openAIAPIKey = ""
    @AppStorage("openAIModelName") private var openAIModelName = "gpt-image-1"
    @AppStorage("screenAspectRatio") private var screenAspectRatioRawValue = ScreenAspectRatio.television169.rawValue
    @AppStorage("showsGeneratePlaceholder") private var showsGeneratePlaceholder = true
    @AppStorage("screenBackgroundBrightness") private var screenBackgroundBrightness = 0.0
    @AppStorage("storyboardTextColumnWidth") private var storyboardTextColumnWidth = Double(StoryboardPageLayout.mainColumnWidth)
    @AppStorage("storyboardTextBaseFontSize") private var storyboardTextBaseFontSize = 11.0

    @State private var selection: SettingsTab = .gemini

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("AI画像生成", systemImage: "sparkles")
                    .tag(SettingsTab.gemini)
                Label("画面表示", systemImage: "rectangle.inset.filled")
                    .tag(SettingsTab.display)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 160)
        } detail: {
            switch selection {
            case .gemini:
                geminiSettings
            case .display:
                displaySettings
            }
        }
        .frame(minWidth: 620, minHeight: 360)
        .background(SettingsWindowConfigurator())
    }

    private var geminiSettings: some View {
        SettingsDetailScrollView {
            SettingsSection("画像生成サービス") {
                Picker("Provider", selection: $imageGenerationProvider) {
                    Text("Gemini").tag("gemini")
                    Text("OpenAI").tag("openai")
                }
                .pickerStyle(.segmented)
            }

            SettingsSection("Gemini Image Generation") {
                SettingsFieldRow("API Key") {
                    SecureField("", text: $geminiAPIKey)
                        .textFieldStyle(.roundedBorder)
                }

                SettingsFieldRow("Model") {
                    TextField("", text: $geminiModelName)
                        .textFieldStyle(.roundedBorder)
                }

                Text("既定値は nano-banana-2 です。Google側の正式モデル名が異なる場合はここで変更できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsSection("OpenAI Image Generation") {
                SettingsFieldRow("API Key") {
                    SecureField("", text: $openAIAPIKey)
                        .textFieldStyle(.roundedBorder)
                }

                SettingsFieldRow("Model") {
                    TextField("", text: $openAIModelName)
                        .textFieldStyle(.roundedBorder)
                }

                Text("既定値は gpt-image-1 です。OpenAIのGPT Image系モデル名をここで変更できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsSection("画像生成システムプロンプト") {
                TextEditor(text: $geminiSystemPrompt)
                    .font(.system(size: 12))
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.separator, lineWidth: 0.5)
                    }

                Text("アプリ全体の画像生成方針を記入します。空の場合は標準の絵コンテ向け方針を使います。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var displaySettings: some View {
        SettingsDetailScrollView {
            SettingsSection("ドキュメントの画面比率") {
                Picker("画面サイズ", selection: $screenAspectRatioRawValue) {
                    ForEach(ScreenAspectRatio.allCases) { ratio in
                        VStack(alignment: .leading) {
                            Text(ratio.label)
                            Text(ratio.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(ratio.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)

                AspectRatioPreview(
                    aspectRatio: ScreenAspectRatio.value(for: screenAspectRatioRawValue).ratio,
                    backgroundBrightness: CGFloat(screenBackgroundBrightness)
                )
                    .frame(width: 220, height: 100)
                    .padding(.top, 8)

                Text("画面欄は選択した比率の白いフレームで表示し、余白は黒ベタになります。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsSection("プレースホルダー") {
                Toggle("未生成の画面にGenerate表示を出す", isOn: $showsGeneratePlaceholder)
            }

            SettingsSection("画面背景") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("明度")
                        Spacer()
                        Text("\(Int((screenBackgroundBrightness * 100).rounded()))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(value: $screenBackgroundBrightness, in: 0...0.6, step: 0.01)
                }
            }

            SettingsSection("内容 / ト書き") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("幅")
                        Spacer()
                        Text("\(Int(storyboardTextColumnWidth.rounded())) pt")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(
                        value: $storyboardTextColumnWidth,
                        in: Double(StoryboardPageLayout.minimumTextColumnWidth)...Double(StoryboardPageLayout.maximumTextColumnWidth),
                        step: 1
                    )
                }

                Picker("文字サイズ", selection: $storyboardTextBaseFontSize) {
                    Text("小").tag(9.0)
                    Text("標準").tag(11.0)
                    Text("大").tag(13.0)
                    Text("特大").tag(15.0)
                }
                .pickerStyle(.menu)

                Text("内容 / ト書きの幅を広げると、その分だけ画面欄が狭くなります。文字量が多い場合は選択サイズから自動で縮小します。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SettingsDetailScrollView<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                content
            }
            .padding(20)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SettingsSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.65), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
    }
}

private struct SettingsWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        window.styleMask.insert(.resizable)
        window.minSize = NSSize(width: 620, height: 360)
    }
}

private struct SettingsFieldRow<Content: View>: View {
    var label: String
    @ViewBuilder var content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(width: 130, alignment: .leading)
            content
        }
    }
}

private struct AspectRatioPreview: View {
    var aspectRatio: CGFloat
    var backgroundBrightness: CGFloat

    private var backgroundColor: Color {
        Color(white: min(max(backgroundBrightness, 0), 1))
    }

    var body: some View {
        GeometryReader { proxy in
            let size = fittedSize(in: proxy.size, aspectRatio: aspectRatio)

            ZStack {
                Rectangle()
                    .fill(backgroundColor)
                Rectangle()
                    .fill(.white)
                    .frame(width: size.width, height: size.height)
                    .overlay {
                        Rectangle()
                            .stroke(.gray.opacity(0.5), lineWidth: 1)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private func fittedSize(in size: CGSize, aspectRatio: CGFloat) -> CGSize {
        let widthBasedHeight = size.width / aspectRatio
        if widthBasedHeight <= size.height {
            return CGSize(width: size.width, height: widthBasedHeight)
        }

        return CGSize(width: size.height * aspectRatio, height: size.height)
    }
}

#Preview("Settings") {
    SettingsView()
}
