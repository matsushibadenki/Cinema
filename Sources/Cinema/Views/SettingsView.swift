import AppKit
import SwiftUI

struct SettingsView: View {
    private enum SettingsTab: Hashable {
        case ai
        case prompt
        case display
    }

    @AppStorage("geminiAPIKey") private var geminiAPIKey = ""
    @AppStorage("geminiModelName") private var geminiModelName = "nano-banana-2"
    @AppStorage("geminiVideoModelName") private var geminiVideoModelName = "veo-3.1-generate-preview"
    @AppStorage("geminiSystemPrompt") private var geminiSystemPrompt = ""
    @AppStorage("imageGenerationProvider") private var imageGenerationProvider = "gemini"
    @AppStorage("videoGenerationProvider") private var videoGenerationProvider = "gemini"
    @AppStorage("openAIAPIKey") private var openAIAPIKey = ""
    @AppStorage("openAIModelName") private var openAIModelName = "gpt-image-2"
    @AppStorage("openAIVideoModelName") private var openAIVideoModelName = "sora-2"
    @AppStorage("screenAspectRatio") private var screenAspectRatioRawValue = ScreenAspectRatio.television169.rawValue
    @AppStorage("showsGeneratePlaceholder") private var showsGeneratePlaceholder = true
    @AppStorage("screenBackgroundBrightness") private var screenBackgroundBrightness = 0.0
    @AppStorage("storyboardTextColumnWidth") private var storyboardTextColumnWidth = Double(StoryboardPageLayout.mainColumnWidth)
    @AppStorage("storyboardTextBaseFontSize") private var storyboardTextBaseFontSize = 11.0
    @AppStorage("scriptSpeakerFontSize") private var scriptSpeakerFontSize = Double(ScriptPageLayout.speakerFontSize)
    @AppStorage("scriptBodyFontSize") private var scriptBodyFontSize = Double(ScriptPageLayout.bodyFontSize)
    @AppStorage("scriptBodyLineAdvance") private var scriptBodyLineAdvance = Double(ScriptPageLayout.bodyLineAdvance)
    @AppStorage("scriptContentLabelFontSize") private var scriptContentLabelFontSize = 10.0
    @AppStorage("scriptSceneFontSize") private var scriptSceneFontSize = 11.5
    @AppStorage("aiCostLimitEnabled") private var aiCostLimitEnabled = false
    @AppStorage("aiCostLimitUSD") private var aiCostLimitUSD = 10.0
    @AppStorage("aiEstimatedCostUSD") private var aiEstimatedCostUSD = 0.0

    @State private var selection: SettingsTab = .ai

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("AI生成", systemImage: "sparkles")
                    .tag(SettingsTab.ai)
                Label("生成プロンプト", systemImage: "text.quote")
                    .tag(SettingsTab.prompt)
                Label("画面表示", systemImage: "rectangle.inset.filled")
                    .tag(SettingsTab.display)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 160)
        } detail: {
            switch selection {
            case .ai:
                aiSettings
            case .prompt:
                promptSettings
            case .display:
                displaySettings
            }
        }
        .frame(minHeight: 360)
        .background(SettingsWindowConfigurator())
    }

    private var aiSettings: some View {
        SettingsDetailScrollView {
            SettingsSection("画像生成サービス") {
                Picker("Provider", selection: $imageGenerationProvider) {
                    ForEach(AIImageGenerationProvider.allCases) { provider in
                        Text(provider.label).tag(provider.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            SettingsSection("動画生成サービス") {
                Picker("Provider", selection: $videoGenerationProvider) {
                    ForEach(AIVideoGenerationProvider.allCases) { provider in
                        Text(provider.label).tag(provider.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            SettingsSection("Gemini") {
                SettingsFieldRow("API Key") {
                    APIKeyField(
                        text: $geminiAPIKey,
                        linkTitle: "Google AI Studioで取得",
                        linkURL: URL(string: "https://aistudio.google.com/app/apikey")!
                    )
                }

                SettingsFieldRow("Image Model") {
                    TextField("", text: $geminiModelName)
                        .textFieldStyle(.roundedBorder)
                }

                SettingsFieldRow("Video Model") {
                    TextField("", text: $geminiVideoModelName)
                        .textFieldStyle(.roundedBorder)
                }

                Text("画像と動画で別のモデル名を指定できます。Google側の正式モデル名が異なる場合はここで変更できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsSection("OpenAI") {
                SettingsFieldRow("API Key") {
                    APIKeyField(
                        text: $openAIAPIKey,
                        linkTitle: "OpenAI Platformで取得",
                        linkURL: URL(string: "https://platform.openai.com/api-keys")!
                    )
                }

                SettingsFieldRow("Image Model") {
                    TextField("", text: $openAIModelName)
                        .textFieldStyle(.roundedBorder)
                }

                SettingsFieldRow("Video Model") {
                    TextField("", text: $openAIVideoModelName)
                        .textFieldStyle(.roundedBorder)
                }

                Text("画像と動画で別のモデル名を指定できます。Soraなど動画モデル名もここで変更できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsSection("利用料金リミッター") {
                Toggle("推定料金の上限を有効にする", isOn: $aiCostLimitEnabled)

                SettingsFieldRow("上限 USD") {
                    TextField("", value: $aiCostLimitUSD, format: .number.precision(.fractionLength(2)))
                        .textFieldStyle(.roundedBorder)
                        .disabled(!aiCostLimitEnabled)
                }

                HStack {
                    Text("現在の推定料金")
                    Spacer()
                    Text(costText(aiEstimatedCostUSD))
                        .monospacedDigit()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                Text("上限を超えるとドキュメント側のAI枠が赤く警告され、追加の画像/動画生成は止めます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var promptSettings: some View {
        SettingsDetailScrollView {
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

    private func costText(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 4
        return formatter.string(from: NSNumber(value: value)) ?? "$0.0000"
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

            SettingsSection("台本表示") {
                SettingsSliderRow(
                    title: "話者名",
                    value: $scriptSpeakerFontSize,
                    range: 8...18,
                    step: 0.5,
                    suffix: "pt"
                )

                SettingsSliderRow(
                    title: "本文",
                    value: $scriptBodyFontSize,
                    range: 8...18,
                    step: 0.5,
                    suffix: "pt"
                )

                SettingsSliderRow(
                    title: "本文の行間",
                    value: $scriptBodyLineAdvance,
                    range: 14...28,
                    step: 0.5,
                    suffix: "pt"
                )

                SettingsSliderRow(
                    title: "内容",
                    value: $scriptContentLabelFontSize,
                    range: 7...16,
                    step: 0.5,
                    suffix: "pt"
                )

                SettingsSliderRow(
                    title: "シーン名",
                    value: $scriptSceneFontSize,
                    range: 8...18,
                    step: 0.5,
                    suffix: "pt"
                )

                Button("標準に戻す") {
                    scriptSpeakerFontSize = Double(ScriptPageLayout.speakerFontSize)
                    scriptBodyFontSize = Double(ScriptPageLayout.bodyFontSize)
                    scriptBodyLineAdvance = Double(ScriptPageLayout.bodyLineAdvance)
                    scriptContentLabelFontSize = 10.0
                    scriptSceneFontSize = 11.5
                }
                .buttonStyle(.bordered)
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
            .frame(width: 520, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(maxHeight: .infinity, alignment: .topLeading)
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
            .frame(width: 492, alignment: .leading)
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

private struct SettingsSliderRow: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var suffix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value, specifier: "%.1f") \(suffix)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: $value, in: range, step: step)
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
        window.minSize = NSSize(width: 520, height: 360)
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

private struct APIKeyField: View {
    @Binding var text: String
    var linkTitle: String
    var linkURL: URL

    var body: some View {
        HStack(spacing: 8) {
            SecureField("", text: $text)
                .textFieldStyle(.roundedBorder)

            Link(destination: linkURL) {
                Label(linkTitle, systemImage: "key")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
            }
            .buttonStyle(.link)
            .fixedSize()
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
