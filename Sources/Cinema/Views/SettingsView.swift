// file:///Users/Shared/Program/Xcode/Cinema/Sources/Cinema/Views/SettingsView.swift
// SettingsView.swift
// アプリケーションの設定項目（AI生成の設定、画面表示の設定など）を表示・管理するビュー

import AppKit
import SwiftUI

struct SettingsView: View {
    private enum SettingsTab: Hashable {
        case ai
        case display
    }

    @AppStorage("geminiAPIKey") private var geminiAPIKey = ""
    @AppStorage("geminiModelName") private var geminiModelName = "gemini-2.5-flash-image"
    @AppStorage("geminiVideoModelName") private var geminiVideoModelName = "veo-3.1-generate-preview"
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
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.japanese.rawValue

    @State private var selection: SettingsTab = .ai

    private let geminiImagePresets = ["gemini-2.5-flash-image"]
    private let geminiVideoPresets = ["veo-3.1-generate-preview"]
    private let openAIImagePresets = ["gpt-image-2", "gpt-image-1.5", "gpt-image-1-mini"]
    private let openAIVideoPresets = ["sora-2", "sora-2-pro"]

    @State private var geminiImageSelection: String = "custom"
    @State private var geminiVideoSelection: String = "custom"
    @State private var openAIImageSelection: String = "custom"
    @State private var openAIVideoSelection: String = "custom"

    @State private var geminiFetchedModels: [String] = []
    @State private var openAIFetchedModels: [String] = []
    @State private var isFetchingGemini = false
    @State private var isFetchingOpenAI = false
    @State private var geminiFetchError: String? = nil
    @State private var openAIFetchError: String? = nil

    private func initializeSelections() {
        if geminiImagePresets.contains(geminiModelName) {
            geminiImageSelection = geminiModelName
        } else if geminiFetchedModels.contains(geminiModelName) {
            geminiImageSelection = geminiModelName
        } else {
            geminiImageSelection = "custom"
        }

        if geminiVideoPresets.contains(geminiVideoModelName) {
            geminiVideoSelection = geminiVideoModelName
        } else if geminiFetchedModels.contains(geminiVideoModelName) {
            geminiVideoSelection = geminiVideoModelName
        } else {
            geminiVideoSelection = "custom"
        }

        if openAIImagePresets.contains(openAIModelName) {
            openAIImageSelection = openAIModelName
        } else if openAIFetchedModels.contains(openAIModelName) {
            openAIImageSelection = openAIModelName
        } else {
            openAIImageSelection = "custom"
        }

        if openAIVideoPresets.contains(openAIVideoModelName) {
            openAIVideoSelection = openAIVideoModelName
        } else if openAIFetchedModels.contains(openAIVideoModelName) {
            openAIVideoSelection = openAIVideoModelName
        } else {
            openAIVideoSelection = "custom"
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label(t(.aiGeneration), systemImage: "sparkles")
                    .tag(SettingsTab.ai)
                Label(t(.displaySettings), systemImage: "rectangle.inset.filled")
                    .tag(SettingsTab.display)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(200)
        } detail: {
            switch selection {
            case .ai:
                aiSettings
            case .display:
                displaySettings
            }
        }
        .frame(minWidth: 700, maxWidth: 700, minHeight: 360, maxHeight: .infinity)
        .background(SettingsWindowConfigurator())
        .onAppear {
            initializeSelections()
            Task {
                await fetchGeminiModels()
                await fetchOpenAIModels()
            }
        }
        .onChange(of: geminiImageSelection) { _, newValue in
            if newValue != "custom" {
                geminiModelName = newValue
            }
        }
        .onChange(of: geminiVideoSelection) { _, newValue in
            if newValue != "custom" {
                geminiVideoModelName = newValue
            }
        }
        .onChange(of: openAIImageSelection) { _, newValue in
            if newValue != "custom" {
                openAIModelName = newValue
            }
        }
        .onChange(of: openAIVideoSelection) { _, newValue in
            if newValue != "custom" {
                openAIVideoModelName = newValue
            }
        }
        .onChange(of: geminiModelName) { _, newValue in
            if geminiImagePresets.contains(newValue) || geminiFetchedModels.contains(newValue) {
                geminiImageSelection = newValue
            } else {
                geminiImageSelection = "custom"
            }
        }
        .onChange(of: geminiVideoModelName) { _, newValue in
            if geminiVideoPresets.contains(newValue) || geminiFetchedModels.contains(newValue) {
                geminiVideoSelection = newValue
            } else {
                geminiVideoSelection = "custom"
            }
        }
        .onChange(of: openAIModelName) { _, newValue in
            if openAIImagePresets.contains(newValue) || openAIFetchedModels.contains(newValue) {
                openAIImageSelection = newValue
            } else {
                openAIImageSelection = "custom"
            }
        }
        .onChange(of: openAIVideoModelName) { _, newValue in
            if openAIVideoPresets.contains(newValue) || openAIFetchedModels.contains(newValue) {
                openAIVideoSelection = newValue
            } else {
                openAIVideoSelection = "custom"
            }
        }
        .onChange(of: geminiAPIKey) { _, _ in
            Task {
                await fetchGeminiModels()
            }
        }
        .onChange(of: openAIAPIKey) { _, _ in
            Task {
                await fetchOpenAIModels()
            }
        }
    }

    private var aiSettings: some View {
        SettingsDetailScrollView {
            SettingsSection(t(.imageGenerationService)) {
                Picker("Provider", selection: $imageGenerationProvider) {
                    ForEach(AIImageGenerationProvider.allCases) { provider in
                        Text(provider.label).tag(provider.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            SettingsSection(t(.videoGenerationService)) {
                Picker("Provider", selection: $videoGenerationProvider) {
                    ForEach(AIVideoGenerationProvider.allCases) { provider in
                        Text(provider.label).tag(provider.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            SettingsSection("Gemini") {
                SettingsFieldRow("API Key") {
                    VStack(alignment: .leading, spacing: 6) {
                        APIKeyField(
                            text: $geminiAPIKey,
                            linkTitle: t(.getGoogleAIStudio),
                            linkURL: URL(string: "https://aistudio.google.com/app/apikey")!
                        )
                        
                        HStack(spacing: 8) {
                            if isFetchingGemini {
                                ProgressView()
                                    .controlSize(.small)
                                Text(t(.fetchingModels))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Button(action: {
                                    Task {
                                        await fetchGeminiModels()
                                    }
                                }) {
                                    Label(t(.refreshModels), systemImage: "arrow.clockwise")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .disabled(geminiAPIKey.isEmpty)

                                if let error = geminiFetchError {
                                    Text(CinemaStrings.fetchError(error, language: appLanguage))
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                        .lineLimit(1)
                                } else if !geminiFetchedModels.isEmpty {
                                    Text(CinemaStrings.fetchComplete(count: geminiFetchedModels.count, language: appLanguage))
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }

                SettingsFieldRow("Image Model") {
                    VStack(alignment: .leading, spacing: 4) {
                        Picker("", selection: $geminiImageSelection) {
                            Section(header: Text(t(.recommendedModels))) {
                                ForEach(geminiImagePresets, id: \.self) { preset in
                                    Text(preset).tag(preset)
                                }
                            }
                            
                            let fetchedList = geminiFetchedModels.filter { ($0.contains("imagen") || $0.contains("gemini") || $0.contains("flash")) && !geminiImagePresets.contains($0) }
                            if !fetchedList.isEmpty {
                                Section(header: Text(t(.fetchedModels))) {
                                    ForEach(fetchedList, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                            }
                            
                            Section {
                                Text(t(.customDirectInput)).tag("custom")
                            }
                        }
                        .pickerStyle(.menu)
                        
                        if geminiImageSelection == "custom" {
                            TextField(t(.enterModelName), text: $geminiModelName)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                SettingsFieldRow("Video Model") {
                    VStack(alignment: .leading, spacing: 4) {
                        Picker("", selection: $geminiVideoSelection) {
                            Section(header: Text(t(.recommendedModels))) {
                                ForEach(geminiVideoPresets, id: \.self) { preset in
                                    Text(preset).tag(preset)
                                }
                            }
                            
                            let fetchedList = geminiFetchedModels.filter { ($0.contains("veo") || $0.contains("generate")) && !geminiVideoPresets.contains($0) }
                            if !fetchedList.isEmpty {
                                Section(header: Text(t(.fetchedModels))) {
                                    ForEach(fetchedList, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                            }
                            
                            Section {
                                Text(t(.customDirectInput)).tag("custom")
                            }
                        }
                        .pickerStyle(.menu)
                        
                        if geminiVideoSelection == "custom" {
                            TextField(t(.enterModelName), text: $geminiVideoModelName)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                Text(t(.geminiModelHelp))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsSection("OpenAI") {
                SettingsFieldRow("API Key") {
                    VStack(alignment: .leading, spacing: 6) {
                        APIKeyField(
                            text: $openAIAPIKey,
                            linkTitle: t(.getOpenAIPlatform),
                            linkURL: URL(string: "https://platform.openai.com/api-keys")!
                        )
                        
                        HStack(spacing: 8) {
                            if isFetchingOpenAI {
                                ProgressView()
                                    .controlSize(.small)
                                Text(t(.fetchingModels))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Button(action: {
                                    Task {
                                        await fetchOpenAIModels()
                                    }
                                }) {
                                    Label(t(.refreshModels), systemImage: "arrow.clockwise")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .disabled(openAIAPIKey.isEmpty)

                                if let error = openAIFetchError {
                                    Text(CinemaStrings.fetchError(error, language: appLanguage))
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                        .lineLimit(1)
                                } else if !openAIFetchedModels.isEmpty {
                                    Text(CinemaStrings.fetchComplete(count: openAIFetchedModels.count, language: appLanguage))
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }

                SettingsFieldRow("Image Model") {
                    VStack(alignment: .leading, spacing: 4) {
                        Picker("", selection: $openAIImageSelection) {
                            Section(header: Text(t(.recommendedModels))) {
                                ForEach(openAIImagePresets, id: \.self) { preset in
                                    Text(preset).tag(preset)
                                }
                            }
                            
                            let fetchedList = openAIFetchedModels.filter { ($0.contains("dall") || $0.contains("gpt")) && !openAIImagePresets.contains($0) }
                            if !fetchedList.isEmpty {
                                Section(header: Text(t(.fetchedModels))) {
                                    ForEach(fetchedList, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                            }
                            
                            Section {
                                Text(t(.customDirectInput)).tag("custom")
                            }
                        }
                        .pickerStyle(.menu)
                        
                        if openAIImageSelection == "custom" {
                            TextField(t(.enterModelName), text: $openAIModelName)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                SettingsFieldRow("Video Model") {
                    VStack(alignment: .leading, spacing: 4) {
                        Picker("", selection: $openAIVideoSelection) {
                            Section(header: Text(t(.recommendedModels))) {
                                ForEach(openAIVideoPresets, id: \.self) { preset in
                                    Text(preset).tag(preset)
                                }
                            }
                            
                            let fetchedList = openAIFetchedModels.filter { $0.contains("sora") && !openAIVideoPresets.contains($0) }
                            if !fetchedList.isEmpty {
                                Section(header: Text(t(.fetchedModels))) {
                                    ForEach(fetchedList, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                            }
                            
                            Section {
                                Text(t(.customDirectInput)).tag("custom")
                            }
                        }
                        .pickerStyle(.menu)
                        
                        if openAIVideoSelection == "custom" {
                            TextField(t(.enterModelName), text: $openAIVideoModelName)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                Text(t(.openAIModelHelp))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsSection(t(.costLimiter)) {
                Toggle(t(.enableCostLimit), isOn: $aiCostLimitEnabled)

                SettingsFieldRow(t(.limitUSD)) {
                    TextField("", value: $aiCostLimitUSD, format: .number.precision(.fractionLength(2)))
                        .textFieldStyle(.roundedBorder)
                        .disabled(!aiCostLimitEnabled)
                }

                HStack {
                    Text(t(.currentEstimatedCost))
                    Spacer()
                    Text(costText(aiEstimatedCostUSD))
                        .monospacedDigit()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                Text(t(.costLimiterHelp))
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

    private func fetchGeminiModels() async {
        guard !geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            geminiFetchedModels = []
            geminiFetchError = nil
            return
        }

        isFetchingGemini = true
        geminiFetchError = nil

        do {
            let models = try await GeminiImageService.fetchAvailableModels(apiKey: geminiAPIKey)
            await MainActor.run {
                self.geminiFetchedModels = models
                self.isFetchingGemini = false
                if geminiModelName != "custom" && !geminiImagePresets.contains(geminiModelName) && models.contains(geminiModelName) {
                    geminiImageSelection = geminiModelName
                }
                if geminiVideoModelName != "custom" && !geminiVideoPresets.contains(geminiVideoModelName) && models.contains(geminiVideoModelName) {
                    geminiVideoSelection = geminiVideoModelName
                }
            }
        } catch {
            await MainActor.run {
                self.geminiFetchError = error.localizedDescription
                self.isFetchingGemini = false
            }
        }
    }

    private func fetchOpenAIModels() async {
        guard !openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            openAIFetchedModels = []
            openAIFetchError = nil
            return
        }

        isFetchingOpenAI = true
        openAIFetchError = nil

        do {
            let models = try await OpenAIImageService.fetchAvailableModels(apiKey: openAIAPIKey)
            await MainActor.run {
                self.openAIFetchedModels = models
                self.isFetchingOpenAI = false
                if openAIModelName != "custom" && !openAIImagePresets.contains(openAIModelName) && models.contains(openAIModelName) {
                    openAIImageSelection = openAIModelName
                }
                if openAIVideoModelName != "custom" && !openAIVideoPresets.contains(openAIVideoModelName) && models.contains(openAIVideoModelName) {
                    openAIVideoSelection = openAIVideoModelName
                }
            }
        } catch {
            await MainActor.run {
                self.openAIFetchError = error.localizedDescription
                self.isFetchingOpenAI = false
            }
        }
    }

    private var displaySettings: some View {
        SettingsDetailScrollView {
            SettingsSection(CinemaStrings.text(.language, language: appLanguage)) {
                Picker(CinemaStrings.text(.language, language: appLanguage), selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            SettingsSection(t(.documentAspectRatio)) {
                Picker(t(.screenSize), selection: $screenAspectRatioRawValue) {
                    ForEach(ScreenAspectRatio.allCases) { ratio in
                        VStack(alignment: .leading) {
                            Text(ratio.label(language: appLanguage))
                            Text(ratio.detail(language: appLanguage))
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

                Text(t(.screenFrameDescription))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsSection(t(.placeholder)) {
                Toggle(t(.showGeneratePlaceholder), isOn: $showsGeneratePlaceholder)
            }

            SettingsSection(t(.screenBackground)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(t(.brightness))
                        Spacer()
                        Text("\(Int((screenBackgroundBrightness * 100).rounded()))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(value: $screenBackgroundBrightness, in: 0...0.6, step: 0.01)
                }
            }

            SettingsSection(t(.contentAndDialogue)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(t(.width))
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

                Picker(t(.textSize), selection: $storyboardTextBaseFontSize) {
                    Text(t(.small)).tag(9.0)
                    Text(t(.standard)).tag(11.0)
                    Text(t(.large)).tag(13.0)
                    Text(t(.extraLarge)).tag(15.0)
                }
                .pickerStyle(.menu)

                Text(t(.contentDialogueWidthDescription))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if showsScriptSettings {
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

    private var showsScriptSettings: Bool {
        false
    }

    private func t(_ key: CinemaTextKey) -> String {
        CinemaStrings.text(key, language: appLanguage)
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
            .frame(maxWidth: .infinity, alignment: .leading)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.65), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window, coordinator: context.coordinator)
        }
    }

    private func configure(window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }
        window.styleMask.insert(.resizable)
        let fixedWidth: CGFloat = 700
        let minSize = NSSize(width: fixedWidth, height: 360)
        let maxSize = NSSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude)
        coordinator.fixedWidth = fixedWidth
        window.delegate = coordinator
        window.contentMinSize = minSize
        window.contentMaxSize = maxSize
        window.minSize = minSize
        window.maxSize = maxSize
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        var fixedWidth: CGFloat = 700

        func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
            NSSize(width: fixedWidth, height: max(frameSize.height, 360))
        }
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
