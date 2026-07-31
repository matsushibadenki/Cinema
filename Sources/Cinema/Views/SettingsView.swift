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
    @AppStorage("geminiModelName") private var geminiModelName = "gemini-3.1-flash-image"
    @AppStorage("geminiVideoModelName") private var geminiVideoModelName = "veo-3.1-generate-preview"
    @AppStorage("imageGenerationProvider") private var imageGenerationProvider = "gemini"
    @AppStorage("videoGenerationProvider") private var videoGenerationProvider = "gemini"
    @AppStorage("openAIAPIKey") private var openAIAPIKey = ""
    @AppStorage("openAIModelName") private var openAIModelName = "gpt-image-2"
    @AppStorage("openAIVideoModelName") private var openAIVideoModelName = "sora-2"
    @AppStorage("deepInfraAPIKey") private var deepInfraAPIKey = ""
    @AppStorage("deepInfraModelName") private var deepInfraModelName = "black-forest-labs/FLUX-1-schnell"
    @AppStorage("deepInfraVideoModelName") private var deepInfraVideoModelName = "Wan-AI/Wan2.1-T2V-14B"
    @AppStorage("novitaAPIKey") private var novitaAPIKey = ""
    @AppStorage("novitaModelName") private var novitaModelName = "sd_xl_base_1.0.safetensors"
    @AppStorage("novitaVideoModelName") private var novitaVideoModelName = "darkSushiMixMix_225D_64380.safetensors"
    @AppStorage("hyperbolicAPIKey") private var hyperbolicAPIKey = ""
    @AppStorage("hyperbolicModelName") private var hyperbolicModelName = "SDXL1.0-base"
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

    private let geminiImagePresets = ["gemini-3.1-flash-image"]
    private let geminiVideoPresets = ["veo-3.1-generate-preview"]
    private let openAIImagePresets = ["gpt-image-2", "gpt-image-1.5", "gpt-image-1-mini"]
    private let openAIVideoPresets = ["sora-2", "sora-2-pro"]
    private let deepInfraImagePresets = ["black-forest-labs/FLUX-1-schnell", "black-forest-labs/FLUX-1-dev"]
    private let deepInfraVideoPresets = ["Wan-AI/Wan2.1-T2V-14B"]
    private let novitaImagePresets = ["sd_xl_base_1.0.safetensors"]
    private let novitaVideoPresets = ["darkSushiMixMix_225D_64380.safetensors"]
    private let hyperbolicImagePresets = ["SDXL1.0-base", "FLUX.1-dev"]

    @State private var geminiImageSelection: String = "custom"
    @State private var geminiVideoSelection: String = "custom"
    @State private var openAIImageSelection: String = "custom"
    @State private var openAIVideoSelection: String = "custom"
    @State private var deepInfraImageSelection: String = "custom"
    @State private var deepInfraVideoSelection: String = "custom"
    @State private var novitaImageSelection: String = "custom"
    @State private var novitaVideoSelection: String = "custom"
    @State private var hyperbolicImageSelection: String = "custom"

    @State private var geminiFetchedModels: [String] = []
    @State private var openAIFetchedModels: [String] = []
    @State private var deepInfraFetchedImageModels: [String] = []
    @State private var deepInfraFetchedVideoModels: [String] = []
    @State private var isFetchingGemini = false
    @State private var isFetchingOpenAI = false
    @State private var isFetchingDeepInfra = false
    @State private var geminiFetchError: String? = nil
    @State private var openAIFetchError: String? = nil
    @State private var deepInfraFetchError: String? = nil

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

        if deepInfraImagePresets.contains(deepInfraModelName) {
            deepInfraImageSelection = deepInfraModelName
        } else if deepInfraFetchedImageModels.contains(deepInfraModelName) {
            deepInfraImageSelection = deepInfraModelName
        } else {
            deepInfraImageSelection = "custom"
        }

        if deepInfraVideoPresets.contains(deepInfraVideoModelName) {
            deepInfraVideoSelection = deepInfraVideoModelName
        } else if deepInfraFetchedVideoModels.contains(deepInfraVideoModelName) {
            deepInfraVideoSelection = deepInfraVideoModelName
        } else {
            deepInfraVideoSelection = "custom"
        }

        novitaImageSelection = novitaImagePresets.contains(novitaModelName) ? novitaModelName : "custom"
        novitaVideoSelection = novitaVideoPresets.contains(novitaVideoModelName) ? novitaVideoModelName : "custom"
        hyperbolicImageSelection = hyperbolicImagePresets.contains(hyperbolicModelName) ? hyperbolicModelName : "custom"
    }

    var body: some View {
        settingsWindow
    }

    private var settingsWindow: some View {
        settingsWindowFetchObservers
    }

    private var settingsWindowBase: AnyView {
        AnyView(
            settingsSplitView
                .frame(minWidth: 820, maxWidth: 820, minHeight: 420, maxHeight: .infinity)
                .background(SettingsWindowConfigurator())
        )
    }

    private var settingsWindowSelectionObservers: some View {
        settingsWindowBase
        .onAppear(perform: handleAppear)
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
        .onChange(of: deepInfraImageSelection) { _, newValue in
            if newValue != "custom" {
                deepInfraModelName = newValue
            }
        }
        .onChange(of: deepInfraVideoSelection) { _, newValue in
            if newValue != "custom" {
                deepInfraVideoModelName = newValue
            }
        }
        .onChange(of: novitaImageSelection) { _, newValue in
            if newValue != "custom" {
                novitaModelName = newValue
            }
        }
        .onChange(of: novitaVideoSelection) { _, newValue in
            if newValue != "custom" {
                novitaVideoModelName = newValue
            }
        }
        .onChange(of: hyperbolicImageSelection) { _, newValue in
            if newValue != "custom" {
                hyperbolicModelName = newValue
            }
        }
    }

    private var settingsWindowModelObservers: some View {
        settingsWindowSelectionObservers
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
        .onChange(of: deepInfraModelName) { _, newValue in
            if deepInfraImagePresets.contains(newValue) || deepInfraFetchedImageModels.contains(newValue) {
                deepInfraImageSelection = newValue
            } else {
                deepInfraImageSelection = "custom"
            }
        }
        .onChange(of: deepInfraVideoModelName) { _, newValue in
            if deepInfraVideoPresets.contains(newValue) || deepInfraFetchedVideoModels.contains(newValue) {
                deepInfraVideoSelection = newValue
            } else {
                deepInfraVideoSelection = "custom"
            }
        }
        .onChange(of: novitaModelName) { _, newValue in
            novitaImageSelection = novitaImagePresets.contains(newValue) ? newValue : "custom"
        }
        .onChange(of: novitaVideoModelName) { _, newValue in
            novitaVideoSelection = novitaVideoPresets.contains(newValue) ? newValue : "custom"
        }
        .onChange(of: hyperbolicModelName) { _, newValue in
            hyperbolicImageSelection = hyperbolicImagePresets.contains(newValue) ? newValue : "custom"
        }
    }

    private var settingsWindowFetchObservers: some View {
        settingsWindowModelObservers
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
        .onChange(of: deepInfraAPIKey) { _, _ in
            Task {
                await fetchDeepInfraModels()
            }
        }
    }

    private var settingsSplitView: some View {
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
    }

    private var aiSettings: some View {
        SettingsDetailScrollView {
            SettingsSection(t(.imageGenerationService), icon: "photo.on.rectangle.angled") {
                SettingsFieldRow("Provider") {
                    Picker("", selection: $imageGenerationProvider) {
                        ForEach(AIImageGenerationProvider.allCases) { provider in
                            Text(provider.label).tag(provider.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            SettingsSection(t(.videoGenerationService), icon: "film.stack") {
                SettingsFieldRow("Provider") {
                    Picker("", selection: $videoGenerationProvider) {
                        ForEach(AIVideoGenerationProvider.allCases) { provider in
                            Text(provider.label).tag(provider.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
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

            SettingsSection("DeepInfra") {
                providerSummaryRow(imageReady: true, videoReady: true)

                SettingsFieldRow("API Key") {
                    VStack(alignment: .leading, spacing: 6) {
                        APIKeyField(
                            text: $deepInfraAPIKey,
                            linkTitle: "DeepInfra Dashboard",
                            linkURL: URL(string: "https://deepinfra.com/dash/api_keys")!
                        )

                        HStack(spacing: 8) {
                            if isFetchingDeepInfra {
                                ProgressView()
                                    .controlSize(.small)
                                Text(t(.fetchingModels))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Button(action: {
                                    Task {
                                        await fetchDeepInfraModels()
                                    }
                                }) {
                                    Label(t(.refreshModels), systemImage: "arrow.clockwise")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)

                                if let error = deepInfraFetchError {
                                    Text(CinemaStrings.fetchError(error, language: appLanguage))
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                        .lineLimit(1)
                                } else if !deepInfraFetchedImageModels.isEmpty || !deepInfraFetchedVideoModels.isEmpty {
                                    Text(CinemaStrings.fetchComplete(count: deepInfraFetchedImageModels.count + deepInfraFetchedVideoModels.count, language: appLanguage))
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }

                SettingsFieldRow("Image Model") {
                    modelPicker(
                        selection: $deepInfraImageSelection,
                        customValue: $deepInfraModelName,
                        presets: deepInfraImagePresets,
                        fetchedModels: deepInfraFetchedImageModels
                    )
                }

                SettingsFieldRow("Video Model") {
                    modelPicker(
                        selection: $deepInfraVideoSelection,
                        customValue: $deepInfraVideoModelName,
                        presets: deepInfraVideoPresets,
                        fetchedModels: deepInfraFetchedVideoModels
                    )
                }
            }

            SettingsSection("Novita") {
                providerSummaryRow(imageReady: true, videoReady: true)

                SettingsFieldRow("API Key") {
                    APIKeyField(
                        text: $novitaAPIKey,
                        linkTitle: "Novita Console",
                        linkURL: URL(string: "https://novita.ai/settings")!
                    )
                }

                SettingsFieldRow("Image Model") {
                    modelPicker(
                        selection: $novitaImageSelection,
                        customValue: $novitaModelName,
                        presets: novitaImagePresets,
                        fetchedModels: []
                    )
                }

                SettingsFieldRow("Video Model") {
                    modelPicker(
                        selection: $novitaVideoSelection,
                        customValue: $novitaVideoModelName,
                        presets: novitaVideoPresets,
                        fetchedModels: []
                    )
                }

                Text("Novita は画像・動画とも非同期APIです。必要に応じてモデル名を直接入力して切り替えられます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsSection("Hyperbolic") {
                providerSummaryRow(imageReady: true, videoReady: false)

                SettingsFieldRow("API Key") {
                    APIKeyField(
                        text: $hyperbolicAPIKey,
                        linkTitle: "Hyperbolic Settings",
                        linkURL: URL(string: "https://app.hyperbolic.xyz/settings")!
                    )
                }

                SettingsFieldRow("Image Model") {
                    modelPicker(
                        selection: $hyperbolicImageSelection,
                        customValue: $hyperbolicModelName,
                        presets: hyperbolicImagePresets,
                        fetchedModels: []
                    )
                }

                Text("Hyperbolic はこのアプリでは画像生成に対応しています。動画生成は未接続です。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SettingsSection(t(.costLimiter), icon: "gauge.with.dots.needle.67percent") {
                Toggle(t(.enableCostLimit), isOn: $aiCostLimitEnabled)

                SettingsFieldRow(t(.limitUSD)) {
                    TextField("", value: $aiCostLimitUSD, format: .number.precision(.fractionLength(2)))
                        .textFieldStyle(.roundedBorder)
                        .disabled(!aiCostLimitEnabled)
                }

                if aiCostLimitEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(t(.currentEstimatedCost))
                            Spacer()
                            Text(costText(aiEstimatedCostUSD))
                                .monospacedDigit()
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.black.opacity(0.06))

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        costRatio >= 0.9
                                        ? Color.red
                                        : (costRatio >= 0.7 ? Color.orange : Color.green)
                                    )
                                    .frame(width: proxy.size.width * min(costRatio, 1.0))
                            }
                        }
                        .frame(height: 6)
                    }
                } else {
                    HStack {
                        Text(t(.currentEstimatedCost))
                        Spacer()
                        Text(costText(aiEstimatedCostUSD))
                            .monospacedDigit()
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Text(t(.costLimiterHelp))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var costRatio: CGFloat {
        guard aiCostLimitUSD > 0 else { return 0 }
        return CGFloat(aiEstimatedCostUSD / aiCostLimitUSD)
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

    private func fetchDeepInfraModels() async {
        isFetchingDeepInfra = true
        deepInfraFetchError = nil

        do {
            async let imageModels = DeepInfraCatalogService.fetchImageModels()
            async let videoModels = DeepInfraCatalogService.fetchVideoModels()
            let (images, videos) = try await (imageModels, videoModels)
            await MainActor.run {
                self.deepInfraFetchedImageModels = images
                self.deepInfraFetchedVideoModels = videos
                self.isFetchingDeepInfra = false
                initializeSelections()
            }
        } catch {
            await MainActor.run {
                self.deepInfraFetchError = error.localizedDescription
                self.isFetchingDeepInfra = false
            }
        }
    }

    private func loadAIModels() async {
        await fetchGeminiModels()
        await fetchOpenAIModels()
        await fetchDeepInfraModels()
    }

    private func startLoadingAIModels() {
        Task {
            await loadAIModels()
        }
    }

    private func handleAppear() {
        initializeSelections()
        startLoadingAIModels()
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

    @ViewBuilder
    private func modelPicker(
        selection: Binding<String>,
        customValue: Binding<String>,
        presets: [String],
        fetchedModels: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("", selection: selection) {
                if !presets.isEmpty {
                    Section(header: Text(t(.recommendedModels))) {
                        ForEach(presets, id: \.self) { preset in
                            Text(preset).tag(preset)
                        }
                    }
                }

                let dynamicModels = fetchedModels.filter { !presets.contains($0) }
                if !dynamicModels.isEmpty {
                    Section(header: Text(t(.fetchedModels))) {
                        ForEach(dynamicModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }

                Section {
                    Text(t(.customDirectInput)).tag("custom")
                }
            }
            .pickerStyle(.menu)

            if selection.wrappedValue == "custom" {
                TextField(t(.enterModelName), text: customValue)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    @ViewBuilder
    private func providerSummaryRow(imageReady: Bool, videoReady: Bool) -> some View {
        HStack(spacing: 8) {
            ProviderSupportBadge(title: "Image", isEnabled: imageReady)
            ProviderSupportBadge(title: "Video", isEnabled: videoReady)
        }
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
    var icon: String?
    @ViewBuilder var content: Content

    init(_ title: String, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CinemaDesign.aiSparkle)
                }
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(CinemaDesign.ink)
            }
            .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(CinemaDesign.fineBorder, lineWidth: 0.6)
            }
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
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

private struct ProviderSupportBadge: View {
    var title: String
    var isEnabled: Bool

    var body: some View {
        Text(isEnabled ? "\(title) Ready" : "\(title) Manual")
            .font(.caption.weight(.medium))
            .foregroundStyle(isEnabled ? CinemaDesign.ink : CinemaDesign.mutedInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(isEnabled ? CinemaDesign.keyColorSoft.opacity(1.2) : CinemaDesign.insetSurface)
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(isEnabled ? CinemaDesign.warmBorder : CinemaDesign.fineBorder, lineWidth: 0.7)
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
