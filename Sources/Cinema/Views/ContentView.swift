import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum DocumentDisplayMode: String, CaseIterable, Identifiable {
    case storyboard
    case script

    var id: String { rawValue }

    var label: String {
        switch self {
        case .storyboard:
            return "絵コンテ"
        case .script:
            return "台本"
        }
    }
}

private struct GenerationErrorAlert: Identifiable {
    let id = UUID()
    var title: String
    var message: String
}

struct ContentView: View {
    @Binding var document: StoryboardDocument

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
    @AppStorage("showsCutActionControls") private var showsCutActionControls = true
    @AppStorage("screenBackgroundBrightness") private var screenBackgroundBrightness = 0.0
    @AppStorage("storyboardTextColumnWidth") private var storyboardTextColumnWidth = Double(StoryboardPageLayout.mainColumnWidth)
    @AppStorage("storyboardTextBaseFontSize") private var storyboardTextBaseFontSize = 11.0
    @AppStorage("aiEstimatedTokensUsed") private var aiEstimatedTokensUsed = 0
    @AppStorage("aiEstimatedCostUSD") private var aiEstimatedCostUSD = 0.0
    @AppStorage("aiCostLimitEnabled") private var aiCostLimitEnabled = false
    @AppStorage("aiCostLimitUSD") private var aiCostLimitUSD = 10.0
    @AppStorage("showsReferenceSidebar") private var showsReferenceSidebar = true

    @State private var pageIndex = 0
    @State private var generationStatus: String?
    @State private var generatingCutID: StoryboardCut.ID?
    @State private var generatingSceneTitle: String?
    @State private var generationErrorAlert: GenerationErrorAlert?
    @State private var selectedVideoSceneTitle: String?
    @State private var selectedVideoCutIDs: Set<StoryboardCut.ID> = []
    @State private var zoomScale: CGFloat = 1.0
    @State private var pinchStartZoomScale: CGFloat?
    @State private var displayMode: DocumentDisplayMode = .storyboard
    @State private var showsDrawingSettings = false
    @State private var showsFullCanvas = false
    @State private var isInitialStoryboardFitPending = true
    @State private var storyboardCanvasHeight: CGFloat = 0

    private let cutsPerPage = 5
    private let minimumZoomScale: CGFloat = 0.5
    private let maximumZoomScale: CGFloat = 2.5
    private let zoomStep: CGFloat = 0.1
    private let pageCanvasPadding: CGFloat = 16

    var body: some View {
        NavigationSplitView {
            SidebarView(
                title: $document.project.title,
                drawingSettings: $document.project.drawingSettings,
                cuts: document.project.cuts,
                pageIndex: $pageIndex,
                pageCount: currentPageCount,
                addCut: addCutAtEnd,
                addSubtitle: addSubtitleAtEnd,
                addCutAbove: addCutAbove,
                addCutBelow: addCutAfter,
                deleteCut: deleteCut,
                deletePage: deletePage,
                jumpToCut: jumpToCut,
                moveCuts: moveCuts,
                moveCutRelativeToTarget: moveCutRelativeToTarget,
                updateCutName: updateCutName,
                sceneVideos: document.project.sceneVideos,
                selectedVideoSceneTitle: $selectedVideoSceneTitle,
                selectedVideoCutIDs: $selectedVideoCutIDs,
                generatingSceneTitle: generatingSceneTitle,
                generateSceneVideo: generateSceneVideo,
                saveSceneVideo: saveSceneVideo,
                exportScenePrompts: exportScenePrompts,
                aiEstimatedTokensUsed: aiEstimatedTokensUsed,
                aiEstimatedCostUSD: aiEstimatedCostUSD,
                aiCostLimitEnabled: aiCostLimitEnabled,
                aiCostLimitUSD: aiCostLimitUSD,
                isAICostLimitExceeded: isAICostLimitExceeded
            )
        } detail: {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    toolbar
                    detailCanvas
                }

                if showsReferenceSidebar {
                    Divider()
                    ReferenceSidebarView(document: $document)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .background(CinemaDesign.canvasBackground)
            .animation(.easeInOut(duration: 0.18), value: showsReferenceSidebar)
        }
        .navigationTitle(documentTitle)
        .background(MainWindowConfigurator())
        .alert(item: $generationErrorAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .printCurrentStoryboardPage)) { _ in
            printCurrentPage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mainWindowDidApplyInitialFrame)) { _ in
            applyInitialStoryboardFit(availableHeight: storyboardCanvasHeight, finalize: true)
        }
        .onChange(of: document.project.cuts.count) { _, _ in
            pageIndex = min(pageIndex, max(currentPageCount - 1, 0))
            ensureSelectedVideoScene()
            ensureSelectedVideoCuts()
        }
        .onChange(of: displayMode) { _, _ in
            pageIndex = min(pageIndex, max(currentPageCount - 1, 0))
        }
        .onChange(of: selectedVideoSceneTitle) { _, _ in
            ensureSelectedVideoCuts(reset: true)
        }
        .onAppear {
            migrateGeminiImageModelIfNeeded()
            document.project.drawingSettings.ensureSelection()
            ensureSelectedVideoScene()
            ensureSelectedVideoCuts()
        }
    }

    private var pageCount: Int {
        storyboardPageCutIDs.count
    }

    private var storyboardPageCutIDs: [[StoryboardCut.ID]] {
        StoryboardPageView.pageCutIDs(for: document.project.cuts, cutsPerPage: cutsPerPage)
    }

    private var documentTitle: String {
        let title = document.project.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Cinema" : title
    }

    private var scriptPageCount: Int {
        ScriptPageView.pageCount(for: document.project.cuts)
    }

    private var currentPageCount: Int {
        if showsDrawingSettings { return 1 }
        switch displayMode {
        case .storyboard:
            return pageCount
        case .script:
            return scriptPageCount
        }
    }

    private var currentPageSize: CGSize {
        switch displayMode {
        case .storyboard:
            return StoryboardPageLayout.pageSize
        case .script:
            return ScriptPageLayout.pageSize
        }
    }

    private var isAICostLimitExceeded: Bool {
        aiCostLimitEnabled && aiEstimatedCostUSD >= aiCostLimitUSD
    }

    private var zoomablePage: some View {
        ZStack(alignment: .topLeading) {
            currentPage
                .frame(width: currentPageSize.width, height: currentPageSize.height)
                .background(pageSurfaceBackground)
                .clipShape(RoundedRectangle(cornerRadius: showsFullCanvas ? 0 : 4))
                .overlay {
                    if !showsFullCanvas {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(CinemaDesign.warmBorder, lineWidth: 0.8)
                    }
                }
                .shadow(color: CinemaDesign.pageShadow.opacity(showsFullCanvas ? 0 : 1), radius: 24, x: 0, y: 12)
                .shadow(color: Color.white.opacity(showsFullCanvas ? 0 : 0.75), radius: 1, x: 0, y: -1)
                .scaleEffect(zoomScale, anchor: .topLeading)
        }
        .frame(
            width: currentPageSize.width * zoomScale,
            height: currentPageSize.height * zoomScale,
            alignment: .topLeading
        )
        .padding(showsFullCanvas ? 0 : pageCanvasPadding)
        .gesture(zoomGesture)
    }

    private var detailCanvas: some View {
        Group {
            if showsDrawingSettings {
                DrawingSettingsView(settings: $document.project.drawingSettings)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .textBackgroundColor))
            } else if showsFullCanvas {
                GeometryReader { proxy in
                    ScrollView([.horizontal, .vertical], showsIndicators: false) {
                        fullCanvasPage(availableSize: proxy.size)
                    }
                    .background(Color.clear)
                }
            } else {
                GeometryReader { proxy in
                    ScrollView([.horizontal, .vertical], showsIndicators: !showsFullCanvas) {
                        zoomablePage
                    }
                    .background {
                        if showsFullCanvas {
                            Color.clear
                        } else {
                            CinemaDesign.canvasBackground
                        }
                    }
                    .onAppear {
                        storyboardCanvasHeight = proxy.size.height
                        applyInitialStoryboardFit(availableHeight: proxy.size.height)
                    }
                    .onChange(of: proxy.size.height) { _, newHeight in
                        storyboardCanvasHeight = newHeight
                        applyInitialStoryboardFit(availableHeight: newHeight)
                    }
                }
            }
        }
    }

    private var pageSurfaceBackground: Color {
        showsFullCanvas ? .clear : Color(nsColor: .textBackgroundColor)
    }

    private func fullCanvasPage(availableSize: CGSize) -> some View {
        let horizontalPadding: CGFloat = 16
        let verticalPadding: CGFloat = 16
        let availableWidth = max(availableSize.width - (horizontalPadding * 2), 1)
        let scale = availableWidth / currentPageSize.width
        let fittedWidth = currentPageSize.width * scale
        let fittedHeight = currentPageSize.height * scale

        return currentPage
            .frame(width: currentPageSize.width, height: currentPageSize.height)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: fittedWidth, height: fittedHeight, alignment: .topLeading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func applyInitialStoryboardFit(availableHeight: CGFloat, finalize: Bool = false) {
        guard (isInitialStoryboardFitPending || finalize),
              displayMode == .storyboard,
              !showsDrawingSettings,
              !showsFullCanvas,
              availableHeight > 0 else {
            return
        }

        let availablePageHeight = max(availableHeight - (pageCanvasPadding * 2), 1)
        zoomScale = clampedZoomScale(availablePageHeight / StoryboardPageLayout.pageSize.height)
        if finalize {
            isInitialStoryboardFitPending = false
        }
    }

    @ViewBuilder
    private var currentPage: some View {
        switch displayMode {
        case .storyboard:
            StoryboardPageView(
                document: $document,
                pageIndex: pageIndex,
                cutsPerPage: cutsPerPage,
                pageCutIDs: storyboardPageCutIDs.indices.contains(pageIndex) ? storyboardPageCutIDs[pageIndex] : [],
                generatingCutID: generatingCutID,
                generate: generateImage,
                importImage: importImage,
                addAfter: addCutAfter,
                delete: deleteCut
            )
            .screenAspectRatio(ScreenAspectRatio.value(for: screenAspectRatioRawValue).ratio)
            .showsGeneratePlaceholder(showsGeneratePlaceholder)
            .showsCutActionControls(showsCutActionControls)
            .screenBackgroundBrightness(CGFloat(screenBackgroundBrightness))
            .storyboardTextColumnWidth(CGFloat(storyboardTextColumnWidth))
            .storyboardTextBaseFontSize(CGFloat(storyboardTextBaseFontSize))
        case .script:
            ScriptPageView(
                cuts: document.project.cuts,
                pageIndex: pageIndex,
                documentTitle: document.project.title
            )
        }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if pinchStartZoomScale == nil {
                    pinchStartZoomScale = zoomScale
                }
                let baseScale = pinchStartZoomScale ?? zoomScale
                zoomScale = clampedZoomScale(baseScale * value)
            }
            .onEnded { value in
                let baseScale = pinchStartZoomScale ?? zoomScale
                zoomScale = clampedZoomScale(baseScale * value)
                pinchStartZoomScale = nil
            }
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    Picker("", selection: $displayMode) {
                        ForEach(DocumentDisplayMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    .onChange(of: displayMode) { _, _ in
                        showsDrawingSettings = false
                        showsFullCanvas = false
                    }

                    Button {
                        showsDrawingSettings.toggle()
                        if showsDrawingSettings {
                            showsFullCanvas = false
                            zoomScale = 1.0
                            pageIndex = 0
                        }
                    } label: {
                        Label("描画設定", systemImage: "paintpalette")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(showsDrawingSettings ? .accentColor : nil)
                    .padding(.leading, 12)
                }

                Spacer(minLength: 16)

                HStack(spacing: 12) {
                    Button {
                        pageIndex = max(pageIndex - 1, 0)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .help("前ページ")
                    .disabled(showsDrawingSettings || pageIndex == 0)

                    Text("\(pageIndex + 1) / \(currentPageCount)")
                        .font(.system(.headline, design: .rounded).monospacedDigit())
                        .foregroundStyle(CinemaDesign.ink)
                        .frame(minWidth: 72)

                    Button {
                        pageIndex = min(pageIndex + 1, currentPageCount - 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .help("次ページ")
                    .disabled(showsDrawingSettings || pageIndex >= currentPageCount - 1)

                    Button {
                        toggleFullCanvas()
                    } label: {
                        Label("全面", systemImage: showsFullCanvas ? "rectangle.inset.filled" : "rectangle.expand.vertical")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(showsFullCanvas ? .accentColor : nil)
                    .disabled(showsDrawingSettings)

                    if !showsFullCanvas {
                        Divider()
                            .frame(height: 22)

                        Button {
                            changeZoom(by: -zoomStep)
                        } label: {
                            Image(systemName: "minus.magnifyingglass")
                        }
                        .help("縮小")
                        .disabled(showsDrawingSettings || zoomScale <= minimumZoomScale)

                        Text(zoomPercentageText)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 52)

                        Button {
                            changeZoom(by: zoomStep)
                        } label: {
                            Image(systemName: "plus.magnifyingglass")
                        }
                        .help("拡大")
                        .disabled(showsDrawingSettings || zoomScale >= maximumZoomScale)

                        Button {
                            zoomScale = 1.0
                        } label: {
                            Label("実寸", systemImage: "1.magnifyingglass")
                        }
                        .disabled(showsDrawingSettings || abs(zoomScale - 1.0) < 0.001)
                    }
                }

                Spacer(minLength: 16)

                HStack(spacing: 12) {
                    Button {
                        showsReferenceSidebar.toggle()
                    } label: {
                        Image(systemName: showsReferenceSidebar ? "sidebar.right" : "sidebar.right")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(showsReferenceSidebar ? .accentColor : nil)
                    .help(showsReferenceSidebar ? "リファレンスを非表示" : "リファレンスを表示")

                    Button {
                        printCurrentPage()
                    } label: {
                        Label("プリント", systemImage: "printer")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(showsDrawingSettings)
                }
            }

            if let generationStatus {
                Text(generationStatus)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CinemaDesign.fineBorder)
                .frame(height: 1)
        }
    }

    private var zoomPercentageText: String {
        "\(Int((zoomScale * 100).rounded()))%"
    }

    private func changeZoom(by delta: CGFloat) {
        zoomScale = clampedZoomScale(zoomScale + delta)
    }

    private func toggleFullCanvas() {
        showsFullCanvas.toggle()
    }

    private func clampedZoomScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minimumZoomScale), maximumZoomScale)
    }

    private func printCurrentPage() {
        switch displayMode {
        case .storyboard:
            PrintService.printPage(document: document, pageIndex: pageIndex)
        case .script:
            PrintService.printScriptPage(document: document, pageIndex: pageIndex)
        }
    }

    private func addCutAtEnd() {
        let cut = StoryboardCut(cutNumber: document.project.cuts.count + 1)
        document.project.cuts.append(cut)
        selectedVideoCutIDs.insert(cut.id)
        document.renumberCuts()
        jumpToCut(cut.id)
    }

    private func addSubtitleAtEnd() {
        let cut = StoryboardCut(cutNumber: document.project.cuts.count + 1, subtitle: nextSubtitleName())
        document.project.cuts.append(cut)
        selectedVideoCutIDs.insert(cut.id)
        document.renumberCuts()
        jumpToCut(cut.id)
    }

    private func addCutAbove(_ cutID: StoryboardCut.ID) {
        guard let index = document.project.cuts.firstIndex(where: { $0.id == cutID }) else { return }
        var cut = StoryboardCut(cutNumber: index + 1)
        if !document.project.cuts[index].subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cut.subtitle = document.project.cuts[index].subtitle
            cut.scriptHeading = document.project.cuts[index].scriptHeading
            cut.sceneName = document.project.cuts[index].sceneName
            document.project.cuts[index].subtitle = ""
            document.project.cuts[index].scriptHeading = ""
            document.project.cuts[index].sceneName = ""
        }
        document.project.cuts.insert(cut, at: index)
        selectedVideoCutIDs.insert(cut.id)
        document.renumberCuts()
        jumpToCut(cut.id)
    }

    private func addCutAfter(_ cutID: StoryboardCut.ID) {
        guard let index = document.project.cuts.firstIndex(where: { $0.id == cutID }) else { return }
        let cut = StoryboardCut(cutNumber: index + 2)
        document.project.cuts.insert(cut, at: index + 1)
        selectedVideoCutIDs.insert(cut.id)
        document.renumberCuts()
        jumpToCut(cut.id)
    }

    private func deleteCut(_ cutID: StoryboardCut.ID) {
        guard document.project.cuts.count > 1 else { return }
        if let cut = document.project.cuts.first(where: { $0.id == cutID }), let imageFileName = cut.imageFileName {
            document.imageData[imageFileName] = nil
        }
        document.project.cuts.removeAll { $0.id == cutID }
        document.renumberCuts()
    }

    private func deletePage(_ page: Int) {
        guard pageCount > 1 else { return }

        guard storyboardPageCutIDs.indices.contains(page) else { return }
        let removedCutIDs = Set(storyboardPageCutIDs[page])
        let removedCuts = document.project.cuts.filter { removedCutIDs.contains($0.id) }
        for cut in removedCuts {
            if let imageFileName = cut.imageFileName {
                document.imageData[imageFileName] = nil
            }
        }

        document.project.cuts.removeAll { removedCutIDs.contains($0.id) }
        if document.project.cuts.isEmpty {
            document.project.cuts.append(StoryboardCut(cutNumber: 1))
        }
        document.renumberCuts()
        pageIndex = min(page, max(pageCount - 1, 0))
    }

    private func jumpToCut(_ cutID: StoryboardCut.ID) {
        guard let page = storyboardPageCutIDs.firstIndex(where: { $0.contains(cutID) }) else { return }
        pageIndex = page
    }

    private func moveCuts(_ source: IndexSet, _ destination: Int, in cutIDs: [StoryboardCut.ID]) {
        let sectionIDs = cutIDs.compactMap { id in
            document.project.cuts.first(where: { $0.id == id })?.id
        }
        var reorderedIDs = sectionIDs
        reorderedIDs.move(fromOffsets: source, toOffset: destination)

        let reorderedCuts = reorderedIDs.compactMap { id in
            document.project.cuts.first(where: { $0.id == id })
        }
        guard reorderedCuts.count == sectionIDs.count else { return }

        var sectionIndex = 0
        for index in document.project.cuts.indices where sectionIDs.contains(document.project.cuts[index].id) {
            document.project.cuts[index] = reorderedCuts[sectionIndex]
            sectionIndex += 1
        }
        normalizeSceneMetadata(for: reorderedIDs)
        document.renumberCuts()
    }

    private func moveCutRelativeToTarget(_ draggedID: StoryboardCut.ID, _ targetID: StoryboardCut.ID, _ position: CutDropPosition) {
        guard draggedID != targetID,
              let sourceIndex = document.project.cuts.firstIndex(where: { $0.id == draggedID }),
              let targetIndex = document.project.cuts.firstIndex(where: { $0.id == targetID }) else { return }

        let movedCut = document.project.cuts.remove(at: sourceIndex)
        let rawTargetIndex: Int
        switch position {
        case .before:
            rawTargetIndex = targetIndex
        case .after:
            rawTargetIndex = targetIndex + 1
        }
        let adjustedTargetIndex = sourceIndex < rawTargetIndex ? rawTargetIndex - 1 : rawTargetIndex
        document.project.cuts.insert(movedCut, at: adjustedTargetIndex)
        document.renumberCuts()
        jumpToCut(draggedID)
    }

    private func updateCutName(_ cutID: StoryboardCut.ID, _ newValue: String) {
        guard let index = document.project.cuts.firstIndex(where: { $0.id == cutID }) else { return }
        document.project.cuts[index].cutName = newValue
    }

    private func normalizeSceneMetadata(for cutIDs: [StoryboardCut.ID]) {
        guard let firstID = cutIDs.first,
              let firstIndex = document.project.cuts.firstIndex(where: { $0.id == firstID }) else { return }

        var subtitle = ""
        var scriptHeading = ""
        var sceneName = ""
        for id in cutIDs {
            guard let cut = document.project.cuts.first(where: { $0.id == id }) else { continue }
            if subtitle.isEmpty { subtitle = cut.subtitle }
            if scriptHeading.isEmpty { scriptHeading = cut.scriptHeading }
            if sceneName.isEmpty { sceneName = cut.sceneName }
        }

        for id in cutIDs {
            guard let index = document.project.cuts.firstIndex(where: { $0.id == id }) else { continue }
            document.project.cuts[index].subtitle = ""
            document.project.cuts[index].scriptHeading = ""
            document.project.cuts[index].sceneName = ""
        }

        document.project.cuts[firstIndex].subtitle = subtitle
        document.project.cuts[firstIndex].scriptHeading = scriptHeading
        document.project.cuts[firstIndex].sceneName = sceneName
    }

    private func nextSubtitleName() -> String {
        let count = document.project.cuts.filter { !$0.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count + 1
        return "ブロック\(count)"
    }

    private func generateSceneVideo(for title: String) {
        guard canStartAIGeneration() else { return }

        let cuts = selectedVideoCuts(for: title)
        guard !cuts.isEmpty else {
            generationStatus = "動画生成するカットを選択してください"
            return
        }

        let prompt = sceneVideoPrompt(title: title, cuts: cuts)
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            generationStatus = "シーンに内容かセリフを入力してください"
            return
        }

        generatingSceneTitle = title
        generationStatus = "シーン「\(title)」の動画を生成中..."

        Task {
            do {
                let provider = AIVideoGenerationProvider.value(for: videoGenerationProvider)
                let referenceImages = sceneReferenceImages(for: cuts)
                let durationSeconds = videoDurationSeconds(for: cuts, hasReferenceImages: provider == .gemini && !referenceImages.isEmpty)
                let videoData: Data

                switch provider {
                case .gemini:
                    let service = GeminiVideoService(apiKey: geminiAPIKey, model: geminiVideoModelName)
                    videoData = try await service.generateSceneVideo(
                        prompt: prompt,
                        durationSeconds: durationSeconds,
                        aspectRatio: videoAspectRatio,
                        referenceImages: referenceImages
                    )
                case .openAI:
                    let service = OpenAIVideoService(apiKey: openAIAPIKey, model: openAIVideoModelName)
                    videoData = try await service.generateSceneVideo(
                        prompt: prompt,
                        durationSeconds: durationSeconds,
                        aspectRatio: videoAspectRatio,
                        inputReference: openAIVideoReferenceImage(from: referenceImages.first, aspectRatio: videoAspectRatio)
                    )
                }

                await MainActor.run {
                    let safeTitle = safeFileComponent(title)
                    let fileName = "Videos/\(safeTitle)-\(UUID().uuidString).mp4"
                    document.videoData[fileName] = videoData
                    document.project.sceneVideos.removeAll { $0.title == title }
                    document.project.sceneVideos.append(SceneVideo(title: title, videoFileName: fileName))
                    recordAIUsage(prompt: prompt, kind: .video(provider: provider.rawValue, seconds: durationSeconds))
                    generationStatus = "シーン「\(title)」の動画を生成しました"
                    generatingSceneTitle = nil
                }
            } catch {
                await MainActor.run {
                    generationStatus = "動画生成に失敗しました"
                    generationErrorAlert = GenerationErrorAlert(title: "動画生成エラー", message: formattedErrorMessage(error))
                    generatingSceneTitle = nil
                }
            }
        }
    }

    private func ensureSelectedVideoScene() {
        let sections = sceneSections()
        if let selectedVideoSceneTitle, sections.contains(where: { $0.title == selectedVideoSceneTitle }) {
            return
        }
        self.selectedVideoSceneTitle = sections.first?.title
    }

    private func ensureSelectedVideoCuts(reset: Bool = false) {
        guard let selectedVideoSceneTitle else { return }
        let sceneCutIDs = Set(cutsForScene(title: selectedVideoSceneTitle).map(\.id))
        if reset || selectedVideoCutIDs.isEmpty {
            selectedVideoCutIDs = sceneCutIDs
            return
        }

        selectedVideoCutIDs = selectedVideoCutIDs.intersection(sceneCutIDs)
        if selectedVideoCutIDs.isEmpty {
            selectedVideoCutIDs = sceneCutIDs
        }
    }

    private func cutsForScene(title: String) -> [StoryboardCut] {
        sceneSections().first(where: { $0.title == title })?.cuts ?? []
    }

    private func selectedVideoCuts(for title: String) -> [StoryboardCut] {
        cutsForScene(title: title).filter { selectedVideoCutIDs.contains($0.id) }
    }

    private func sceneSections() -> [(title: String, cuts: [StoryboardCut])] {
        var sections: [(title: String, cuts: [StoryboardCut])] = []
        var currentTitle = "ブロック1"
        var currentCuts: [StoryboardCut] = []

        for cut in document.project.cuts {
            let subtitle = cut.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !subtitle.isEmpty {
                if !currentCuts.isEmpty {
                    sections.append((currentTitle, currentCuts))
                    currentCuts = []
                }
                currentTitle = subtitle
            }
            currentCuts.append(cut)
        }

        if !currentCuts.isEmpty {
            sections.append((currentTitle, currentCuts))
        }

        return sections
    }

    private func sceneVideoPrompt(title: String, cuts: [StoryboardCut]) -> String {
        let cutDescriptions = cuts.map { cut -> String in
            [
                "Cut \(cut.cutNumber)",
                labeledPrompt("Duration seconds", cut.duration),
                labeledPrompt("Scene content", cut.situation),
                labeledPrompt("Names and dialogue", dialoguePrompt(for: cut)),
                labeledPrompt("Additional direction", cut.generationPrompt)
            ]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
        }
        .joined(separator: "\n\n")

        return [
            "Create a cinematic video for the selected storyboard scene.",
            "Scene title: \(title)",
            "Drawing settings:\n\(drawingPromptForGeneration(references: referencesForCuts(cuts)))",
            "Use the attached storyboard images as visual references for composition, characters, locations, and continuity.",
            "Respect the cut order and timing notes. Use camera movement and scene motion to connect the cuts into one coherent short video.",
            cutDescriptions
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: "\n\n")
    }

    private func sceneReferenceImages(for cuts: [StoryboardCut]) -> [GeminiReferenceImage] {
        let linkedReferences = referencesForCuts(cuts).compactMap { reference -> GeminiReferenceImage? in
            guard let data = document.imageData[reference.imageFileName] else { return nil }
            return GeminiReferenceImage(mimeType: mimeType(for: reference.imageFileName), data: data)
        }

        let storyboardImages = cuts.compactMap { cut -> GeminiReferenceImage? in
            guard let fileName = cut.imageFileName, let data = document.imageData[fileName] else { return nil }
            return GeminiReferenceImage(mimeType: mimeType(for: fileName), data: data)
        }

        return linkedReferences + storyboardImages
    }

    private func referencesForCuts(_ cuts: [StoryboardCut]) -> [ReferenceImage] {
        var seenIDs = Set<ReferenceImage.ID>()
        let ids = cuts.flatMap(\.referenceImageIDs)
        return ids.compactMap { id in
            guard !seenIDs.contains(id),
                  let reference = document.project.referenceImages.first(where: { $0.id == id }) else {
                return nil
            }
            seenIDs.insert(id)
            return reference
        }
    }

    private func videoDurationSeconds(for cuts: [StoryboardCut], hasReferenceImages: Bool) -> Int {
        if hasReferenceImages { return 8 }

        let total = cuts
            .compactMap { Double($0.duration.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")) }
            .reduce(0, +)

        if total <= 4 { return 4 }
        if total <= 6 { return 6 }
        return 8
    }

    private var videoAspectRatio: String {
        let ratio = ScreenAspectRatio.value(for: screenAspectRatioRawValue).ratio
        return ratio < 1 ? "9:16" : "16:9"
    }

    private func openAIVideoReferenceImage(from image: GeminiReferenceImage?, aspectRatio: String) -> OpenAIVideoReferenceImage? {
        guard let image else { return nil }
        let size = aspectRatio == "9:16" ? (width: 720, height: 1280) : (width: 1280, height: 720)
        return OpenAIVideoReferenceImage(
            fileName: "reference.png",
            mimeType: "image/png",
            data: ImageHelpers.pngDataByResizing(image.data, width: size.width, height: size.height)
        )
    }

    private func safeFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let result = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return result.isEmpty ? "scene" : result
    }

    private func saveSceneVideo(_ video: SceneVideo) {
        guard let data = document.videoData[video.videoFileName] else {
            generationStatus = "動画データが見つかりません"
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = "\(video.title).mp4"
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
            } catch {
                NSSound.beep()
            }
        }
    }

    private func exportScenePrompts(for title: String) {
        let cuts = selectedVideoCuts(for: title)
        let selectedCuts = cuts.filter { selectedVideoCutIDs.contains($0.id) }
        
        guard !selectedCuts.isEmpty else {
            generationStatus = "書き出すカットを選択してください"
            return
        }
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "選択"
        panel.message = "プロンプトと画像を書き出すフォルダを選択してください。"
        
        let response = panel.runModal()
        guard response == .OK, let baseURL = panel.url else { return }
        
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let safeTitle = title.components(separatedBy: invalidCharacters).joined(separator: "_")
        let folderName = safeTitle.isEmpty ? "untitled_scene" : safeTitle
        let sceneFolderURL = baseURL.appendingPathComponent(folderName)
        
        do {
            try FileManager.default.createDirectory(at: sceneFolderURL, withIntermediateDirectories: true, attributes: nil)
            
            // 1. シーン全体のまとめテキストを作成
            var summary = ""
            summary += "=========================================\n"
            summary += "シーン: \(title)\n"
            summary += "=========================================\n\n"
            
            let scenePrompt = sceneVideoPrompt(title: title, cuts: selectedCuts)
            summary += "【シーン動画生成用プロンプト (AI動画生成用)】\n"
            summary += "-----------------------------------------\n"
            summary += scenePrompt + "\n"
            summary += "-----------------------------------------\n\n"
            
            summary += "【カット別詳細】\n"
            summary += "-----------------------------------------\n"
            
            for cut in selectedCuts {
                let cutNumStr = String(format: "%02d", cut.cutNumber)
                let durationStr = cut.duration.isEmpty ? "未設定" : "\(cut.duration)秒"
                
                summary += "■ カット \(cut.cutNumber) (\(durationStr))\n"
                summary += "・内容: \(cut.situation)\n"
                
                let dialogue = dialoguePrompt(for: cut)
                if !dialogue.isEmpty {
                    summary += "・セリフ:\n\(dialogue)\n"
                }
                
                let drawPrompt = drawingPromptForGeneration(references: referencesForCut(cut))
                let cPrompt = cutPrompt(for: cut)
                let fullImagePrompt = [drawPrompt, cPrompt].filter { !$0.isEmpty }.joined(separator: "\n")
                summary += "・画像生成プロンプト:\n\(fullImagePrompt)\n"
                
                if !cut.generationPrompt.isEmpty {
                    summary += "・追加の指示: \(cut.generationPrompt)\n"
                }
                summary += "-----------------------------------------\n\n"
                
                // 2. カットごとの個別プロンプトテキストを書き出し
                var cutPromptContent = ""
                cutPromptContent += "【画像生成用プロンプト (Image Generation Prompt)】\n"
                cutPromptContent += fullImagePrompt + "\n\n"
                cutPromptContent += "【動画生成用指示 (Video Generation Settings)】\n"
                cutPromptContent += "Duration: \(durationStr)\n"
                cutPromptContent += "Situation: \(cut.situation)\n"
                if !dialogue.isEmpty {
                    cutPromptContent += "Dialogue:\n\(dialogue)\n"
                }
                if !cut.generationPrompt.isEmpty {
                    cutPromptContent += "Additional Direction: \(cut.generationPrompt)\n"
                }
                
                let cutPromptURL = sceneFolderURL.appendingPathComponent("cut_\(cutNumStr)_prompt.txt")
                try cutPromptContent.write(to: cutPromptURL, atomically: true, encoding: .utf8)
                
                // 3. 生成済みのコンテ画像を書き出し
                if let imageFileName = cut.imageFileName,
                   let imageData = document.imageData[imageFileName] {
                    let imageURL = sceneFolderURL.appendingPathComponent("cut_\(cutNumStr)_image.png")
                    try imageData.write(to: imageURL)
                }
                
                // 4. リファレンス画像を書き出し
                let refs = referencesForCut(cut)
                for (index, ref) in refs.enumerated() {
                    if let refData = document.imageData[ref.imageFileName] {
                        let refNum = index + 1
                        let refURL = sceneFolderURL.appendingPathComponent("cut_\(cutNumStr)_ref_\(refNum).png")
                        try refData.write(to: refURL)
                    }
                }
            }
            
            let summaryURL = sceneFolderURL.appendingPathComponent("scene_summary.txt")
            try summary.write(to: summaryURL, atomically: true, encoding: .utf8)
            
            generationStatus = "シーン「\(title)」のプロンプトと画像をフォルダ「\(folderName)」に書き出しました"
        } catch {
            generationStatus = "書き出しに失敗しました: \(error.localizedDescription)"
        }
    }

    private func generateImage(for cutID: StoryboardCut.ID) {
        guard canStartAIGeneration() else { return }

        guard let index = document.project.cuts.firstIndex(where: { $0.id == cutID }) else { return }
        let cut = document.project.cuts[index]
        let prompt = cutPrompt(for: cut)
        let aspectRatio = ScreenAspectRatio.value(for: screenAspectRatioRawValue).ratio

        guard !prompt.isEmpty else {
            generationStatus = "内容かセリフを入力してください"
            return
        }

        generatingCutID = cutID
        generationStatus = "カット\(cut.cutNumber)を生成中..."

        Task {
            do {
                let data: Data
                switch AIImageGenerationProvider.value(for: imageGenerationProvider) {
                case .openAI:
                    let service = OpenAIImageService(apiKey: openAIAPIKey, model: openAIModelName)
                    data = try await service.generateStoryboardImage(
                        drawingPrompt: drawingPromptForGeneration(references: referencesForCut(cut)),
                        cutPrompt: prompt,
                        aspectRatio: aspectRatio
                    )
                case .gemini:
                    let service = GeminiImageService(apiKey: geminiAPIKey, model: geminiModelName)
                    data = try await service.generateStoryboardImage(
                        drawingPrompt: drawingPromptForGeneration(references: referencesForCut(cut)),
                        cutPrompt: prompt,
                        aspectRatio: aspectRatio,
                        referenceImages: referenceImagesForGeneration(for: cut)
                    )
                }
                let fittedData = ImageHelpers.pngDataByCropping(data, toAspectRatio: aspectRatio)
                await MainActor.run {
                    let fileName = "Images/\(cutID.uuidString).png"
                    document.imageData[fileName] = fittedData
                    if let updateIndex = document.project.cuts.firstIndex(where: { $0.id == cutID }) {
                        document.project.cuts[updateIndex].imageFileName = fileName
                    }
                    recordAIUsage(prompt: prompt, kind: .image(provider: imageGenerationProvider))
                    generationStatus = "カット\(cut.cutNumber)を生成しました"
                    generatingCutID = nil
                }
            } catch {
                await MainActor.run {
                    generationStatus = "画像生成に失敗しました"
                    generationErrorAlert = GenerationErrorAlert(title: "画像生成エラー", message: formattedErrorMessage(error))
                    generatingCutID = nil
                }
            }
        }
    }

    private func importImage(for cutID: StoryboardCut.ID) {
        guard let cutIndex = document.project.cuts.firstIndex(where: { $0.id == cutID }) else { return }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url) else {
            generationStatus = "画像の読み込みに失敗しました"
            return
        }

        let aspectRatio = ScreenAspectRatio.value(for: screenAspectRatioRawValue).ratio
        let croppedData = ImageHelpers.pngDataByCropping(data, toAspectRatio: aspectRatio)
        let fileName = "Images/\(cutID.uuidString).png"
        document.imageData[fileName] = croppedData
        document.project.cuts[cutIndex].imageFileName = fileName
        generationStatus = "カット\(document.project.cuts[cutIndex].cutNumber)に画像を読み込みました"
    }

    private func formattedErrorMessage(_ error: Error) -> String {
        let rawMessage = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = rawMessage.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return formattedPlainErrorMessage(rawMessage)
        }

        if let errorObject = json["error"] as? [String: Any] {
            let message = stringValue(errorObject["message"])
            let status = stringValue(errorObject["status"])
            let code = stringValue(errorObject["code"])
            let type = stringValue(errorObject["type"])
            let formatted = [
                message,
                labeledErrorLine("Status", status),
                labeledErrorLine("Code", code),
                labeledErrorLine("Type", type)
            ]
            .compactMap { $0 }
            .joined(separator: "\n")
            return formattedPlainErrorMessage(formatted)
        }

        if let message = stringValue(json["message"]) {
            return formattedPlainErrorMessage(message)
        }

        return formattedPlainErrorMessage(rawMessage)
    }

    private func formattedPlainErrorMessage(_ rawMessage: String) -> String {
        guard !rawMessage.isEmpty else { return "原因不明のエラーです。" }

        let status = valueAfterLabel("Status:", in: rawMessage)
        let code = valueAfterLabel("Code:", in: rawMessage)
        let retryText = retryDelayText(in: rawMessage)
        if status == "RESOURCE_EXHAUSTED" || code == "429" || rawMessage.localizedCaseInsensitiveContains("quota exceeded") {
            return [
                "Gemini APIの無料枠またはレート制限に達しました。",
                retryText.map { "少し待ってから再試行してください（目安: \($0)）。" },
                "AI Studioで現在の利用状況と課金設定を確認できます。",
                "",
                rawMessage
            ]
            .compactMap { $0 }
            .joined(separator: "\n")
        }

        return rawMessage
    }

    private func valueAfterLabel(_ label: String, in text: String) -> String? {
        text
            .components(separatedBy: .newlines)
            .first { $0.trimmingCharacters(in: .whitespaces).hasPrefix(label) }?
            .replacingOccurrences(of: label, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func retryDelayText(in text: String) -> String? {
        guard let range = text.range(of: #"Please retry in ([0-9.]+)s"#, options: .regularExpression) else { return nil }
        let matched = String(text[range])
        guard let secondsRange = matched.range(of: #"[0-9.]+"#, options: .regularExpression),
              let seconds = Double(matched[secondsRange]) else {
            return nil
        }
        return "\(Int(ceil(seconds)))秒後"
    }

    private func stringValue(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let value as NSNumber:
            return value.stringValue
        default:
            return nil
        }
    }

    private func labeledErrorLine(_ label: String, _ value: String?) -> String? {
        guard let value else { return nil }
        return "\(label): \(value)"
    }

    private func migrateGeminiImageModelIfNeeded() {
        if geminiModelName.trimmingCharacters(in: .whitespacesAndNewlines) == "nano-banana-2" {
            geminiModelName = "gemini-2.5-flash-image"
        }
    }

    private func cutPrompt(for cut: StoryboardCut) -> String {
        [
            labeledPrompt("Scene content", cut.situation),
            labeledPrompt("Action direction", cut.action),
            labeledPrompt("Names and dialogue", dialoguePrompt(for: cut)),
            labeledPrompt("Additional cut direction", cut.generationPrompt)
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: "\n\n")
    }

    private func labeledPrompt(_ label: String, _ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return "\(label):\n\(trimmed)"
    }

    private func dialoguePrompt(for cut: StoryboardCut) -> String {
        let dialogue = cut.dialogueLines
            .map { line -> String in
                let speaker = line.speaker.trimmingCharacters(in: .whitespacesAndNewlines)
                let text = line.dialogue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !speaker.isEmpty || !text.isEmpty else { return "" }
                return speaker.isEmpty ? text : "\(speaker): \(text)"
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        if !dialogue.isEmpty {
            return dialogue
        }

        return cut.action
    }

    private func referenceImagesForGeneration(for cut: StoryboardCut) -> [GeminiReferenceImage] {
        referencesForCut(cut).compactMap { reference in
            guard let data = document.imageData[reference.imageFileName] else { return nil }
            return GeminiReferenceImage(mimeType: mimeType(for: reference.imageFileName), data: data)
        }
    }

    private func referencesForCut(_ cut: StoryboardCut) -> [ReferenceImage] {
        cut.referenceImageIDs.compactMap { id in
            document.project.referenceImages.first { $0.id == id }
        }
    }

    private func drawingPromptForGeneration(references: [ReferenceImage]) -> String {
        [
            document.project.drawingSettings.promptText(),
            referenceImagePrompt(references: references)
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: "\n\n")
    }

    private func referenceImagePrompt(references: [ReferenceImage]) -> String {
        let details = references.enumerated().map { index, reference in
            let prompt = reference.promptText().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prompt.isEmpty else { return "" }
            return "Reference image \(index + 1):\n\(prompt)"
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")

        guard !details.isEmpty else { return "" }
        return "Reference image details:\n\(details)"
    }

    private func mimeType(for fileName: String) -> String {
        switch URL(fileURLWithPath: fileName).pathExtension.lowercased() {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "webp":
            return "image/webp"
        default:
            return "image/png"
        }
    }

    private enum AIUsageKind {
        case image(provider: String)
        case video(provider: String, seconds: Int)
    }

    private func canStartAIGeneration() -> Bool {
        guard !isAICostLimitExceeded else {
            generationStatus = "推定料金が上限を超えています。設定で上限を変更してください。"
            return false
        }
        return true
    }

    private func recordAIUsage(prompt: String, kind: AIUsageKind) {
        let tokens = max(1, Int(ceil(Double(prompt.count) / 4.0)))
        aiEstimatedTokensUsed += tokens
        aiEstimatedCostUSD += estimatedCostUSD(tokens: tokens, kind: kind)
    }

    private func estimatedCostUSD(tokens: Int, kind: AIUsageKind) -> Double {
        switch kind {
        case .image(let provider):
            if provider == "openai" {
                return (Double(tokens) / 1_000_000.0) * 5.0 + 0.08
            }
            return (Double(tokens) / 1_000_000.0) * 0.30 + 0.04
        case .video(let provider, let seconds):
            if provider == AIVideoGenerationProvider.openAI.rawValue {
                return (Double(tokens) / 1_000_000.0) * 5.0 + (Double(seconds) * 0.10)
            }
            return (Double(tokens) / 1_000_000.0) * 0.30 + (Double(seconds) * 0.60)
        }
    }
}

private struct MainWindowConfigurator: NSViewRepresentable {
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
        guard let window, !coordinator.didConfigure else { return }
        let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame
        guard let visibleFrame else { return }
        window.setFrame(visibleFrame, display: true, animate: false)
        coordinator.didConfigure = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationCenter.default.post(name: .mainWindowDidApplyInitialFrame, object: nil)
        }
    }

    final class Coordinator {
        var didConfigure = false
    }
}

private extension Notification.Name {
    static let mainWindowDidApplyInitialFrame = Notification.Name("mainWindowDidApplyInitialFrame")
}
