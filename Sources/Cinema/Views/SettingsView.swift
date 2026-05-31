import SwiftUI

struct SettingsView: View {
    private enum SettingsTab: Hashable {
        case gemini
        case display
    }

    @AppStorage("geminiAPIKey") private var geminiAPIKey = ""
    @AppStorage("geminiModelName") private var geminiModelName = "nano-banana-2"
    @AppStorage("geminiSystemPrompt") private var geminiSystemPrompt = ""
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
        .frame(width: 620, height: 360)
    }

    private var geminiSettings: some View {
        Form {
            Section("Gemini Image Generation") {
                SecureField("API Key", text: $geminiAPIKey)
                    .textFieldStyle(.roundedBorder)
                TextField("Model", text: $geminiModelName)
                    .textFieldStyle(.roundedBorder)
                Text("既定値は nano-banana-2 です。Google側の正式モデル名が異なる場合はここで変更できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("画像生成システムプロンプト") {
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
        .formStyle(.grouped)
        .padding(20)
    }

    private var displaySettings: some View {
        Form {
            Section("ドキュメントの画面比率") {
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

            Section("プレースホルダー") {
                Toggle("未生成の画面にGenerate表示を出す", isOn: $showsGeneratePlaceholder)
            }

            Section("画面背景") {
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

            Section("内容 / ト書き") {
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
        .formStyle(.grouped)
        .padding(20)
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
