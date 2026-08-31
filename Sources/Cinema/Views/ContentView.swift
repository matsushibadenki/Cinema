// file:///Users/Shared/Program/Xcode/Cinema/Sources/Cinema/Views/ContentView.swift
// ContentView.swift
// 絵コンテアプリのメインビュー。ドキュメントキャンバス、ツールバー、サイドバー、各種モーダル・アラートの調整を行います。

import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum DocumentDisplayMode: String, CaseIterable, Identifiable {
    case cutFocus
    case storyboard
    case script

    var id: String { rawValue }

}

private enum CinemaWorkspace: String, CaseIterable, Identifiable {
    case scenario
    case editor
    case browser

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scenario: "Scenario"
        case .editor: "Editor"
        case .browser: "Browser"
        }
    }

    var symbolName: String {
        switch self {
        case .scenario: "text.book.closed"
        case .editor: "timeline.selection"
        case .browser: "rectangle.grid.2x2"
        }
    }
}

private struct GenerationErrorAlert: Identifiable {
    let id = UUID()
    var title: String
    var message: String
}

private struct WorkspaceTabButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            .foregroundStyle(isSelected ? CinemaDesign.ink : CinemaDesign.controlInactiveInk)
            .lineLimit(1)
            .padding(.horizontal, 18)
            .frame(height: 42)
            .background(Color.clear)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(isSelected ? CinemaDesign.ink : Color.clear)
                    .frame(height: 2)
            }
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(CinemaDesign.fineBorder)
                    .frame(width: 1, height: 20)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
            .contentShape(Rectangle())
    }
}

private enum SceneVideoStorageError: LocalizedError {
    case documentMustBeSaved

    var errorDescription: String? {
        switch self {
        case .documentMustBeSaved:
            return "動画を書き出す前に、ドキュメントを保存してください。"
        }
    }
}

struct ContentView: View {
    @Binding var document: StoryboardDocument
    var documentURL: URL?

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
    @AppStorage("customScreenWidth") private var customScreenWidth = 1920
    @AppStorage("customScreenHeight") private var customScreenHeight = 1080
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
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.japanese.rawValue

    @State private var pageIndex = 0
    @State private var focusedCutScrollPosition: Int? = 0
    @State private var generationStatus: String?
    @State private var generatingCutID: StoryboardCut.ID?
    @State private var generatingSceneTitle: String?
    @State private var generationErrorAlert: GenerationErrorAlert?
    @State private var selectedVideoSceneTitle: String?
    @State private var selectedVideoCutIDs: Set<StoryboardCut.ID> = []
    @State private var zoomScale: CGFloat = 1.0
    @State private var pinchStartZoomScale: CGFloat?
    @State private var displayMode: DocumentDisplayMode = .cutFocus
    @State private var showsDrawingSettings = false
    @State private var showsSceneStateEditor = false
    @State private var showsProjectSettings = false
    @State private var showsFullCanvas = false
    @State private var isInitialStoryboardFitPending = true
    @State private var storyboardCanvasHeight: CGFloat = 0
    @State private var selectedWorkspace: CinemaWorkspace = .scenario

    private let cutsPerPage = 5
    private let minimumZoomScale: CGFloat = 0.5
    private let maximumZoomScale: CGFloat = 2.5
    private let zoomStep: CGFloat = 0.1
    private let pageCanvasPadding: CGFloat = 16

    private var currentReferenceCutID: StoryboardCut.ID? {
        let index = displayMode == .cutFocus ? pageIndex : (focusedCutScrollPosition ?? pageIndex)
        guard document.project.cuts.indices.contains(index) else { return nil }
        return document.project.cuts[index].id
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if selectedWorkspace == .scenario {
                    NavigationSplitView {
            SidebarView(
                title: $document.project.title,
                drawingSettings: $document.project.drawingSettings,
                sceneStates: $document.project.sceneStates,
                showsDrawingSettings: showsDrawingSettings,
                toggleDrawingSettings: toggleDrawingSettings,
                printCurrentPage: printCurrentPage,
                cuts: document.project.cuts,
                referenceImages: document.project.referenceImages,
                imageData: document.imageData,
                pageIndex: $pageIndex,
                pageCount: currentPageCount,
                navigationSectionTitle: navigationSectionTitle,
                navigationSummaries: navigationSummaries,
                allowsDeleteNavigationItems: displayMode == .storyboard,
                addCut: addCutAtEnd,
                addSubtitle: addSubtitleAtEnd,
                addBlockAfterSection: addBlockAfterSection,
                deleteBlockSection: deleteBlockSection,
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
                isAICostLimitExceeded: isAICostLimitExceeded,
                appLanguage: appLanguage
            )
        } detail: {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    toolbar
                    detailCanvas
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
                .clipped()

                if showsReferenceSidebar {
                    Divider()
                    ReferenceSidebarView(
                        document: $document,
                        currentCutID: currentReferenceCutID,
                        appLanguage: appLanguage
                    )
                        .fixedSize(horizontal: false, vertical: false)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CinemaDesign.canvasBackground)
            .animation(.easeInOut(duration: 0.18), value: showsReferenceSidebar)
                    }
                } else {
                    workspacePlaceholder
                }
            }

            workspaceTabBar
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
        .sheet(isPresented: $showsSceneStateEditor) {
            if let sceneTitle = selectedVideoSceneTitle {
                SceneStateWorkspaceView(
                    sceneTitle: sceneTitle,
                    sceneState: sceneStateBinding(for: sceneTitle),
                    cuts: selectedAISceneCuts,
                    references: document.project.referenceImages,
                    imageData: document.imageData,
                    appLanguage: appLanguage
                )
            }
        }
        .sheet(isPresented: $showsProjectSettings) {
            ProjectSettingsView(
                context: $document.project.projectContext,
                appLanguage: appLanguage
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
            if displayMode == .cutFocus {
                focusedCutScrollPosition = pageIndex
            }
            ensureSelectedVideoScene()
            ensureSelectedVideoCuts()
        }
        .onChange(of: displayMode) { _, _ in
            pageIndex = min(pageIndex, max(currentPageCount - 1, 0))
            if displayMode == .cutFocus {
                focusedCutScrollPosition = pageIndex
                showsFullCanvas = false
            }
        }
        .onChange(of: pageIndex) { _, newValue in
            if displayMode == .cutFocus, focusedCutScrollPosition != newValue {
                focusedCutScrollPosition = newValue
            }
        }
        .onChange(of: selectedVideoSceneTitle) { _, _ in
            ensureSelectedVideoCuts(reset: true)
        }
        .onAppear {
            migrateAIModelsIfNeeded()
            document.project.drawingSettings.ensureSelection()
            ensureSelectedVideoScene()
            ensureSelectedVideoCuts()
        }
    }

    private var workspaceTabBar: some View {
        HStack(spacing: 0) {
            ForEach(CinemaWorkspace.allCases) { workspace in
                Button {
                    selectedWorkspace = workspace
                } label: {
                    Label(workspace.title, systemImage: workspace.symbolName)
                }
                .buttonStyle(WorkspaceTabButtonStyle(isSelected: selectedWorkspace == workspace))
                .help(workspace.title)
            }

            Spacer(minLength: 0)

            Text("CINEMA")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(CinemaDesign.quietInk)
                .padding(.trailing, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .background(CinemaDesign.panelBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(CinemaDesign.strongBorder)
                .frame(height: 1)
        }
    }

    private var workspacePlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: selectedWorkspace.symbolName)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(CinemaDesign.quietInk)

            Text(selectedWorkspace.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CinemaDesign.ink)

            Text("このワークスペースは準備中です。")
                .font(.system(size: 12))
                .foregroundStyle(CinemaDesign.mutedInk)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CinemaDesign.canvasBackground)
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
        case .cutFocus:
            return max(document.project.cuts.count, 1)
        case .storyboard:
            return pageCount
        case .script:
            return scriptPageCount
        }
    }

    private var currentPageSize: CGSize {
        switch displayMode {
        case .cutFocus:
            return .zero
        case .storyboard:
            return StoryboardPageLayout.pageSize
        case .script:
            return ScriptPageLayout.pageSize
        }
    }

    private var navigationSectionTitle: String {
        displayMode == .cutFocus ? t(.cut) : t(.page)
    }

    private var navigationSummaries: [String] {
        switch displayMode {
        case .cutFocus:
            return document.project.cuts.map { cut in
                let name = cut.cutName.trimmingCharacters(in: .whitespacesAndNewlines)
                let scene = cut.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let title = name.isEmpty ? "Cut \(cut.cutNumber)" : "Cut \(cut.cutNumber) / \(name)"
                return scene.isEmpty ? title : "\(title) / \(scene)"
            }
        case .storyboard:
            return storyboardPageCutIDs.enumerated().map { index, ids in
                let pageCuts = ids.compactMap { id in document.project.cuts.first(where: { $0.id == id }) }
                let numbers = pageCuts.map(\.cutNumber)
                let rangeText: String
                if let first = numbers.first, let last = numbers.last {
                    rangeText = first == last ? "Cut \(first)" : "Cut \(first)-\(last)"
                } else {
                    rangeText = "空き"
                }
                let sceneTitle = pageCuts.first?.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if let sceneTitle, !sceneTitle.isEmpty {
                    return CinemaStrings.pageSummary(page: index + 1, rangeText: rangeText, sceneTitle: sceneTitle, language: appLanguage)
                }
                return CinemaStrings.pageSummary(page: index + 1, rangeText: rangeText, sceneTitle: nil, language: appLanguage)
            }
        case .script:
            return (0..<scriptPageCount).map { "Page \($0 + 1)" }
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
                            .stroke(CinemaDesign.fineBorder.opacity(0.72), lineWidth: 0.6)
                    }
                }
                .shadow(color: CinemaDesign.pageShadow.opacity(showsFullCanvas ? 0 : 0.72), radius: 18, x: 0, y: 10)
                .shadow(color: Color.white.opacity(showsFullCanvas ? 0 : 0.50), radius: 1, x: 0, y: -1)
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
                    .background(CinemaDesign.canvasBackground)
            } else if displayMode == .cutFocus {
                FocusedStoryboardCutScroller(
                    cuts: $document.project.cuts,
                    currentIndex: $pageIndex,
                    scrollPosition: $focusedCutScrollPosition,
                    generatedVideoColumns: generatedVideoStripColumns,
                    selectedVideoSceneTitle: selectedVideoSceneTitle,
                    referenceImages: document.project.referenceImages,
                    imageData: document.imageData,
                    screenAspectRatio: screenAspectRatioValue,
                    showsGeneratePlaceholder: showsGeneratePlaceholder,
                    screenBackgroundBrightness: CGFloat(screenBackgroundBrightness),
                    textBaseFontSize: CGFloat(storyboardTextBaseFontSize),
                    generatingCutID: generatingCutID,
                    deleteImageData: { fileName in document.imageData[fileName] = nil },
                    generate: generateImage,
                    importImage: importImage,
                    addAfter: addCutAfter,
                    delete: deleteCut,
                    appLanguage: appLanguage
                )
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
        showsFullCanvas ? .clear : CinemaDesign.editorSurface
    }

    private var screenAspectRatioValue: CGFloat {
        ScreenAspectRatio.value(for: screenAspectRatioRawValue).ratio(
            customWidth: customScreenWidth,
            customHeight: customScreenHeight
        )
    }

    private func fullCanvasPage(availableSize: CGSize) -> some View {
        let horizontalPadding: CGFloat = 16
        let verticalPadding: CGFloat = 16

        return currentPage
            .frame(width: currentPageSize.width, height: currentPageSize.height)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(minHeight: max(availableSize.height, currentPageSize.height + (verticalPadding * 2)), alignment: .topLeading)
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
        zoomScale = clampedZoomScale(pixelAlignedScale(availablePageHeight / StoryboardPageLayout.pageSize.height))
        if finalize {
            isInitialStoryboardFitPending = false
        }
    }

    private func pixelAlignedScale(_ scale: CGFloat) -> CGFloat {
        let backingScale = NSScreen.main?.backingScaleFactor ?? 2
        let stepsPerPoint: CGFloat = 20
        return (scale * backingScale * stepsPerPoint).rounded() / (backingScale * stepsPerPoint)
    }

    @ViewBuilder
    private var currentPage: some View {
        switch displayMode {
        case .cutFocus:
            Color.clear
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
                delete: deleteCut,
                appLanguage: appLanguage
            )
            .screenAspectRatio(screenAspectRatioValue)
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
        VStack(alignment: .leading, spacing: 0) {
            aiControlBar

            CinemaDesign.toolbarSeparator
                .frame(height: 1)

            HStack(spacing: 14) {
                // Left group: display mode
                HStack(spacing: 10) {
                    HStack(spacing: 2) {
                        Button {
                            displayMode = .cutFocus
                        } label: {
                            Label(t(.focusMode), systemImage: "rectangle.portrait.on.rectangle.portrait")
                        }
                        .buttonStyle(CinemaStateButtonStyle(isActive: displayMode == .cutFocus, expands: true))

                        Button {
                            displayMode = .storyboard
                        } label: {
                            Label(t(.storyboard), systemImage: "rectangle.grid.1x2")
                        }
                        .buttonStyle(CinemaStateButtonStyle(isActive: displayMode == .storyboard, expands: true))
                    }
                    .frame(width: 250)
                }

                Spacer(minLength: 12)

                // Center group: pagination & zoom
                HStack(spacing: 10) {
                    Button {
                        pageIndex = max(pageIndex - 1, 0)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .help(t(.previousPage))
                    .disabled(showsDrawingSettings || pageIndex == 0)

                    Text("\(pageIndex + 1) / \(currentPageCount)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(CinemaDesign.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background {
                            Capsule(style: .continuous)
                                .fill(CinemaDesign.insetSurface.opacity(0.96))
                        }
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(CinemaDesign.fineBorder, lineWidth: 0.6)
                        }

                    Button {
                        pageIndex = min(pageIndex + 1, currentPageCount - 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .help(t(.nextPage))
                    .disabled(showsDrawingSettings || pageIndex >= currentPageCount - 1)

                    if displayMode == .storyboard {
                        Button {
                            toggleFullCanvas()
                        } label: {
                            Label(t(.fullCanvas), systemImage: showsFullCanvas ? "rectangle.inset.filled" : "rectangle.expand.vertical")
                        }
                        .buttonStyle(CinemaToolbarButtonStyle(isActive: showsFullCanvas))
                        .disabled(showsDrawingSettings)
                    }

                    if displayMode == .storyboard && !showsFullCanvas {
                        Rectangle()
                            .fill(CinemaDesign.fineBorder)
                            .frame(width: 1, height: 20)
                            .padding(.horizontal, 2)

                        Button {
                            changeZoom(by: -zoomStep)
                        } label: {
                            Image(systemName: "minus.magnifyingglass")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.borderless)
                        .help(t(.zoomOut))
                        .disabled(showsDrawingSettings || zoomScale <= minimumZoomScale)

                        Text(zoomPercentageText)
                            .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundStyle(CinemaDesign.mutedInk)
                            .frame(width: 44)

                        Button {
                            changeZoom(by: zoomStep)
                        } label: {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.borderless)
                        .help(t(.zoomIn))
                        .disabled(showsDrawingSettings || zoomScale >= maximumZoomScale)

                        Button {
                            zoomScale = 1.0
                        } label: {
                            Text("1:1")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .buttonStyle(CinemaToolbarButtonStyle())
                        .disabled(showsDrawingSettings || abs(zoomScale - 1.0) < 0.001)
                    }
                }

                Spacer(minLength: 12)

                // Right group: reference
                HStack(spacing: 8) {
                    Button {
                        showsReferenceSidebar.toggle()
                    } label: {
                        Image(systemName: "sidebar.right")
                    }
                    .buttonStyle(CinemaToolbarButtonStyle(isActive: showsReferenceSidebar))
                    .help(showsReferenceSidebar ? t(.hideReference) : t(.showReference))

                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)

            if let generationStatus {
                CinemaStatusPill(
                    text: generationStatus,
                    isAnimating: generatingCutID != nil || generatingSceneTitle != nil
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .background(CinemaDesign.toolbarBackground)
        .overlay(alignment: .bottom) {
            CinemaDesign.toolbarSeparator
                .frame(height: 1)
        }
    }

    private var aiControlBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Label(t(.ai), systemImage: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(CinemaDesign.ink)

                aiMetric(title: t(.estimatedTokens), value: "\(aiEstimatedTokensUsed)")
                aiMetric(title: t(.estimatedCost), value: aiCostText(aiEstimatedCostUSD))

                if isAICostLimitExceeded {
                    Label(t(.costLimitExceeded), systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.red)
                }

                Divider().frame(height: 24)

                Picker(t(.drawingPreset), selection: $document.project.drawingSettings.selectedPresetID) {
                    ForEach(document.project.drawingSettings.presets) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 150)

                Picker(t(.screenSize), selection: $screenAspectRatioRawValue) {
                    ForEach(ScreenAspectRatio.allCases) { ratio in
                        Text(ratio.label(language: appLanguage))
                            .tag(ratio.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 150)
                .help(t(.screenSize))

                Button {
                    showsProjectSettings = true
                } label: {
                    Label(t(.projectSettings), systemImage: "slider.horizontal.3")
                }
                .buttonStyle(CinemaToolbarButtonStyle(
                    isActive: !document.project.projectContext.productionDirective
                        .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ))
                .help(t(.projectSettingsHelp))

                if ScreenAspectRatio.value(for: screenAspectRatioRawValue) == .custom {
                    HStack(spacing: 4) {
                        TextField("W", value: $customScreenWidth, format: .number)
                            .frame(width: 58)
                        Text("×")
                            .foregroundStyle(CinemaDesign.mutedInk)
                        TextField("H", value: $customScreenHeight, format: .number)
                            .frame(width: 58)
                    }
                    .textFieldStyle(.roundedBorder)
                    .help(ScreenAspectRatio.custom.detail(language: appLanguage))
                }

                Divider().frame(height: 24)

                if let sceneTitle = selectedVideoSceneTitle {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sceneTitle)
                            .font(.system(size: 11, weight: .semibold))
                        Text("対象: Cut \(selectedAISceneCuts.map(\.cutNumber).map(String.init).joined(separator: ", "))")
                            .font(.system(size: 9))
                            .foregroundStyle(CinemaDesign.mutedInk)
                    }
                    .lineLimit(1)

                    Button(sceneStateButtonTitle) {
                        ensureSceneState(for: sceneTitle)
                        showsSceneStateEditor = true
                    }
                    .buttonStyle(CinemaToolbarButtonStyle())

                    Button(t(.exportPrompt)) {
                        exportScenePrompts(for: sceneTitle)
                    }
                    .buttonStyle(CinemaToolbarButtonStyle())

                    Button(generatingSceneTitle == sceneTitle ? t(.generating) : t(.createSelectedSceneVideo)) {
                        generateSceneVideo(for: sceneTitle)
                    }
                    .buttonStyle(CinemaActionButtonStyle())
                    .disabled(generatingSceneTitle != nil)

                    if let video = document.project.sceneVideos.first(where: { $0.title == sceneTitle }) {
                        Button {
                            saveSceneVideo(video)
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .buttonStyle(CinemaToolbarButtonStyle())
                        .help(t(.saveGeneratedVideo))
                    }
                } else {
                    Text(t(.selectScene))
                        .font(.system(size: 11))
                        .foregroundStyle(CinemaDesign.mutedInk)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .background(
            isAICostLimitExceeded
                ? AnyShapeStyle(Color.red.opacity(0.05))
                : AnyShapeStyle(CinemaDesign.toolbarBackground)
        )
    }

    private func aiMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(CinemaDesign.mutedInk)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(isAICostLimitExceeded ? .red : CinemaDesign.ink)
        }
    }

    private var selectedAISceneCuts: [StoryboardCut] {
        guard let sceneTitle = selectedVideoSceneTitle else { return [] }
        return cutsForScene(title: sceneTitle).filter { selectedVideoCutIDs.contains($0.id) }
    }

    private var sceneStateButtonTitle: String {
        switch AppLanguage.value(for: appLanguage) {
        case .japanese: return "Scene State / 書き出し確認"
        case .english: return "Scene State / Export Preview"
        case .simplifiedChinese: return "Scene State / 导出预览"
        }
    }

    private func ensureSceneState(for sceneTitle: String) {
        guard !document.project.sceneStates.contains(where: { $0.sceneKey == sceneTitle || $0.title == sceneTitle }) else { return }
        document.project.sceneStates.append(SceneState(sceneKey: sceneTitle, title: sceneTitle))
    }

    private func sceneStateBinding(for sceneTitle: String) -> Binding<SceneState> {
        Binding(
            get: {
                document.project.sceneStates.first(where: { $0.sceneKey == sceneTitle || $0.title == sceneTitle })
                    ?? SceneState(sceneKey: sceneTitle, title: sceneTitle)
            },
            set: { newValue in
                if let index = document.project.sceneStates.firstIndex(where: { $0.id == newValue.id }) {
                    document.project.sceneStates[index] = newValue
                } else {
                    document.project.sceneStates.append(newValue)
                }
            }
        )
    }

    private func aiCostText(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 4
        return formatter.string(from: NSNumber(value: value)) ?? "$0.0000"
    }

    private func toggleDrawingSettings() {
        showsDrawingSettings.toggle()
        if showsDrawingSettings {
            showsFullCanvas = false
            zoomScale = 1.0
            focusedCutScrollPosition = displayMode == .cutFocus ? pageIndex : focusedCutScrollPosition
        }
    }

    private var zoomPercentageText: String {
        "\(Int((zoomScale * 100).rounded()))%"
    }

    private func t(_ key: CinemaTextKey) -> String {
        CinemaStrings.text(key, language: appLanguage)
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
        case .cutFocus:
            if let storyboardPage = storyboardPageIndex(containingCutAt: pageIndex) {
                PrintService.printPage(document: document, pageIndex: storyboardPage)
            }
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

    private func addBlockAfterSection(_ title: String) {
        let sections = sceneSections()
        guard let section = sections.first(where: { $0.title == title }),
              let lastCut = section.cuts.last,
              let index = document.project.cuts.firstIndex(where: { $0.id == lastCut.id }) else {
            addSubtitleAtEnd()
            return
        }

        let cut = StoryboardCut(
            cutNumber: index + 2,
            subtitle: nextSubtitleName()
        )
        document.project.cuts.insert(cut, at: index + 1)
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
        document.project.generatedCutVideos.removeAll { $0.cutID == cutID }
        document.renumberCuts()
    }

    private func deleteBlockSection(_ title: String) {
        let sections = sceneSections()
        guard sections.count > 1,
              let section = sections.first(where: { $0.title == title }) else { return }

        let removedIDs = Set(section.cuts.map(\.id))
        for cut in section.cuts {
            if let imageFileName = cut.imageFileName {
                document.imageData[imageFileName] = nil
            }
        }

        document.project.cuts.removeAll { removedIDs.contains($0.id) }
        document.project.generatedCutVideos.removeAll { removedIDs.contains($0.cutID) }

        if document.project.cuts.isEmpty {
            document.project.cuts.append(StoryboardCut(cutNumber: 1))
        }

        document.renumberCuts()
        ensureSelectedVideoScene()
        ensureSelectedVideoCuts(reset: true)
    }

    private func deletePage(_ page: Int) {
        guard displayMode == .storyboard else { return }
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
        document.project.generatedCutVideos.removeAll { removedCutIDs.contains($0.cutID) }
        if document.project.cuts.isEmpty {
            document.project.cuts.append(StoryboardCut(cutNumber: 1))
        }
        document.renumberCuts()
        pageIndex = min(page, max(pageCount - 1, 0))
    }

    private func jumpToCut(_ cutID: StoryboardCut.ID) {
        guard let cutIndex = document.project.cuts.firstIndex(where: { $0.id == cutID }) else { return }
        switch displayMode {
        case .cutFocus:
            pageIndex = cutIndex
            focusedCutScrollPosition = cutIndex
        case .storyboard, .script:
            guard let page = storyboardPageCutIDs.firstIndex(where: { $0.contains(cutID) }) else { return }
            pageIndex = page
        }
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
        return CinemaStrings.blockName(count, language: appLanguage)
    }

    private func storyboardPageIndex(containingCutAt cutIndex: Int) -> Int? {
        guard document.project.cuts.indices.contains(cutIndex) else { return nil }
        let cutID = document.project.cuts[cutIndex].id
        return storyboardPageCutIDs.firstIndex(where: { $0.contains(cutID) })
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
                var clips: [Data] = []
                var previousLastFrame: GeminiReferenceImage?
                var totalDurationSeconds = 0

                for (index, cut) in cuts.enumerated() {
                    await MainActor.run {
                        generationStatus = "シーン「\(title)」のカット \(index + 1)/\(cuts.count) を生成中..."
                    }

                    let cutReferences = sceneReferenceImages(for: [cut])
                    let orderedReferences = ([previousLastFrame].compactMap { $0 } + cutReferences)
                    let capabilities = AIProviderCapabilities.video(
                        provider: provider,
                        hasReferenceImages: !orderedReferences.isEmpty
                    )
                    let references = Array(orderedReferences.prefix(capabilities.maximumReferenceImages))
                    let durationSeconds = videoDurationSeconds(
                        for: [cut],
                        provider: provider,
                        hasReferenceImages: !references.isEmpty
                    )
                    let cutPrompt = AIPromptBuilder.scenePrompt(
                        title: title,
                        cuts: [cut],
                        drawingPrompt: drawingPromptForGeneration(references: referencesForCut(cut)),
                        isSingleCutGeneration: true,
                        previousCut: index > 0 ? cuts[index - 1] : nil
                    )
                    let clip: Data

                    switch provider {
                    case .gemini:
                        let service = GeminiVideoService(apiKey: geminiAPIKey, model: geminiVideoModelName)
                        clip = try await service.generateSceneVideo(
                            prompt: cutPrompt,
                            durationSeconds: durationSeconds,
                            aspectRatio: videoAspectRatio,
                            referenceImages: references,
                            negativePrompt: cut.aiShotSettings.negativePrompt,
                            seed: cut.aiShotSettings.seed
                        )
                    case .openAI:
                        let service = OpenAIVideoService(apiKey: openAIAPIKey, model: openAIVideoModelName)
                        clip = try await service.generateSceneVideo(
                            prompt: cutPrompt,
                            durationSeconds: durationSeconds,
                            aspectRatio: videoAspectRatio,
                            inputReference: openAIVideoReferenceImage(
                                from: references.first,
                                aspectRatio: videoAspectRatio
                            )
                        )
                    case .deepInfra:
                        let service = DeepInfraVideoService(apiKey: deepInfraAPIKey, model: deepInfraVideoModelName)
                        clip = try await service.generateSceneVideo(prompt: cutPrompt)
                    case .novita:
                        let service = NovitaVideoService(apiKey: novitaAPIKey, model: novitaVideoModelName)
                        clip = try await service.generateSceneVideo(
                            prompt: cutPrompt,
                            durationSeconds: durationSeconds,
                            aspectRatio: videoAspectRatio
                        )
                    }

                    clips.append(clip)
                    totalDurationSeconds += durationSeconds
                    if index < cuts.count - 1,
                       let frameData = try? await VideoAssemblyService.lastFramePNG(from: clip) {
                        previousLastFrame = GeminiReferenceImage(mimeType: "image/png", data: frameData)
                    }
                }
                let videoData = try await VideoAssemblyService.concatenate(clips)
                let generatedAt = Date()
                let storedVideos = try persistGeneratedSceneVideos(
                    sceneTitle: title,
                    cuts: cuts,
                    clips: clips,
                    combinedVideoData: videoData,
                    generatedAt: generatedAt
                )

                await MainActor.run {
                    document.project.sceneVideos.removeAll { $0.title == title }
                    document.project.sceneVideos.append(
                        SceneVideo(
                            title: title,
                            videoFileName: storedVideos.sceneVideoPath,
                            generatedAt: generatedAt
                        )
                    )
                    document.project.generatedCutVideos.append(contentsOf: storedVideos.cutVideos)
                    recordAIUsage(
                        prompt: prompt,
                        kind: .video(
                            provider: provider.rawValue,
                            model: currentVideoModelName(for: provider),
                            seconds: totalDurationSeconds
                        )
                    )
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
        var currentTitle = CinemaStrings.blockName(1, language: appLanguage)
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
        AIPromptBuilder.scenePrompt(
            title: title,
            cuts: cuts,
            drawingPrompt: drawingPromptForGeneration(references: referencesForCuts(cuts)),
            isSingleCutGeneration: cuts.count == 1
        )
    }

    private func sceneReferenceImages(for cuts: [StoryboardCut]) -> [GeminiReferenceImage] {
        let storyboardImages = storyboardReferenceImages(for: cuts)
        let linkedReferences = referencesForCuts(cuts).compactMap { reference -> GeminiReferenceImage? in
            guard let data = document.imageData[reference.imageFileName] else { return nil }
            return GeminiReferenceImage(mimeType: mimeType(for: reference.imageFileName), data: data)
        }

        return storyboardImages + linkedReferences
    }

    private func storyboardReferenceImages(for cuts: [StoryboardCut]) -> [GeminiReferenceImage] {
        cuts.compactMap { cut -> GeminiReferenceImage? in
            guard let fileName = cut.imageFileName, let data = document.imageData[fileName] else { return nil }
            return GeminiReferenceImage(mimeType: mimeType(for: fileName), data: data)
        }
    }

    private func referencesForCuts(_ cuts: [StoryboardCut]) -> [ReferenceImage] {
        var seenIDs = Set<ReferenceImage.ID>()
        let ids = cuts.flatMap(\.enabledReferenceImageIDs)
        return ids.compactMap { id in
            guard !seenIDs.contains(id),
                  let reference = document.project.referenceImages.first(where: { $0.id == id }) else {
                return nil
            }
            seenIDs.insert(id)
            return reference
        }
    }

    private func videoDurationSeconds(
        for cuts: [StoryboardCut],
        provider: AIVideoGenerationProvider,
        hasReferenceImages: Bool
    ) -> Int {
        let total = cuts
            .compactMap { Double($0.duration.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")) }
            .reduce(0, +)
        let requested = total > 0 ? total : 4
        return AIProviderCapabilities.video(
            provider: provider,
            hasReferenceImages: hasReferenceImages
        )
        .normalizedDuration(requested)
    }

    private var videoAspectRatio: String {
        let ratio = screenAspectRatioValue
        return ratio < 1 ? "9:16" : "16:9"
    }

    private var generatedVideoStripColumns: [GeneratedVideoStripColumn] {
        guard let selectedVideoSceneTitle else { return [] }

        return cutsForScene(title: selectedVideoSceneTitle).map { cut in
            let versions = document.project.generatedCutVideos
                .filter { $0.sceneTitle == selectedVideoSceneTitle && $0.cutID == cut.id }
                .sorted { $0.generatedAt > $1.generatedAt }
                .compactMap { video -> GeneratedVideoStripVersion? in
                    guard let fileURL = movieFileURL(for: video.videoFileName),
                          FileManager.default.fileExists(atPath: fileURL.path) else {
                        return nil
                    }
                    return GeneratedVideoStripVersion(
                        id: video.id,
                        generatedAt: video.generatedAt,
                        fileURL: fileURL
                    )
                }

            return GeneratedVideoStripColumn(
                cutID: cut.id,
                cutNumber: cut.cutNumber,
                cutName: cut.cutName.trimmingCharacters(in: .whitespacesAndNewlines),
                versions: versions
            )
        }
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

    private func sanitizedPathComponent(_ value: String, fallback: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let sanitized = value
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? fallback : sanitized
    }

    private func timestampFileComponent(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    private func moviesDirectoryURL() -> URL? {
        guard let documentURL else { return nil }
        return documentURL.deletingLastPathComponent().appendingPathComponent("movies", isDirectory: true)
    }

    private func movieFileURL(for storedPath: String) -> URL? {
        let moviePath = storedPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !moviePath.isEmpty else { return nil }
        guard let moviesDirectoryURL = moviesDirectoryURL() else { return nil }
        return moviesDirectoryURL.appendingPathComponent(moviePath)
    }

    private func persistGeneratedSceneVideos(
        sceneTitle: String,
        cuts: [StoryboardCut],
        clips: [Data],
        combinedVideoData: Data,
        generatedAt: Date
    ) throws -> (sceneVideoPath: String, cutVideos: [GeneratedCutVideo]) {
        guard let moviesDirectoryURL = moviesDirectoryURL() else {
            throw SceneVideoStorageError.documentMustBeSaved
        }

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: moviesDirectoryURL, withIntermediateDirectories: true)

        let sceneFolderName = sanitizedPathComponent(sceneTitle, fallback: "scene")
        let sceneDirectoryURL = moviesDirectoryURL.appendingPathComponent(sceneFolderName, isDirectory: true)
        try fileManager.createDirectory(at: sceneDirectoryURL, withIntermediateDirectories: true)

        let timestamp = timestampFileComponent(generatedAt)
        var cutVideos: [GeneratedCutVideo] = []

        for (cut, clip) in zip(cuts, clips) {
            let fileName = "cut-\(String(format: "%03d", cut.cutNumber))-\(timestamp)-\(UUID().uuidString).mp4"
            let fileURL = sceneDirectoryURL.appendingPathComponent(fileName)
            try clip.write(to: fileURL, options: .atomic)
            cutVideos.append(
                GeneratedCutVideo(
                    sceneTitle: sceneTitle,
                    cutID: cut.id,
                    videoFileName: "\(sceneFolderName)/\(fileName)",
                    generatedAt: generatedAt
                )
            )
        }

        let sceneFileName = "scene-\(timestamp)-\(UUID().uuidString).mp4"
        let sceneFileURL = sceneDirectoryURL.appendingPathComponent(sceneFileName)
        try combinedVideoData.write(to: sceneFileURL, options: .atomic)

        return ("\(sceneFolderName)/\(sceneFileName)", cutVideos)
    }

    private func saveSceneVideo(_ video: SceneVideo) {
        let data: Data
        if let externalURL = movieFileURL(for: video.videoFileName),
           let externalData = try? Data(contentsOf: externalURL) {
            data = externalData
        } else if let embeddedData = document.videoData[video.videoFileName] {
            data = embeddedData
        } else {
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
        let selectedCuts = selectedVideoCuts(for: title)
        
        guard !selectedCuts.isEmpty else {
            generationStatus = CinemaStrings.noCutsForSceneBundle(language: appLanguage)
            return
        }

        let sceneState = document.project.sceneStates.first {
            $0.sceneKey == title || $0.title == title
        }
        let validation = CinemaSceneBundleValidator.validate(
            sceneTitle: title,
            sceneState: sceneState,
            cuts: selectedCuts,
            references: document.project.referenceImages,
            imageData: document.imageData,
            language: appLanguage
        )
        guard validation.canExport else {
            generationStatus = CinemaStrings.sceneBundleHasErrors(
                count: validation.errorCount,
                language: appLanguage
            )
            return
        }
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = CinemaStrings.chooseFolder(language: appLanguage)
        panel.message = CinemaStrings.sceneBundleFolderMessage(language: appLanguage)
        
        let response = panel.runModal()
        guard response == .OK, let baseURL = panel.url else { return }
        
        do {
            let videoProvider = AIVideoGenerationProvider.value(for: videoGenerationProvider)
            let configuration = CinemaSceneExportConfiguration(
                aspectRatio: ScreenAspectRatio.value(for: screenAspectRatioRawValue),
                aspectRatioLanguage: appLanguage,
                imageProvider: AIImageGenerationProvider.value(for: imageGenerationProvider).rawValue,
                imageModel: currentImageModelName(),
                videoProvider: videoProvider.rawValue,
                videoModel: currentVideoModelName(for: videoProvider),
                applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
            )
            let bundleURL = try CinemaSceneBundleExporter.export(
                project: document.project,
                sceneTitle: title,
                cuts: selectedCuts,
                imageData: document.imageData,
                configuration: configuration,
                to: baseURL
            )
            generationStatus = CinemaStrings.sceneBundleExported(
                scene: title,
                folder: bundleURL.lastPathComponent,
                language: appLanguage
            )
        } catch {
            generationStatus = CinemaStrings.sceneBundleExportFailed(
                error: error.localizedDescription,
                language: appLanguage
            )
        }
    }

    private func generateImage(for cutID: StoryboardCut.ID) {
        guard canStartAIGeneration() else { return }

        guard let index = document.project.cuts.firstIndex(where: { $0.id == cutID }) else { return }
        let cut = document.project.cuts[index]
        let prompt = cutPrompt(for: cut)
        let aspectRatio = screenAspectRatioValue

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
                        aspectRatio: aspectRatio,
                        referenceImages: openAIImageReferencesForGeneration(for: cut)
                    )
                case .gemini:
                    let service = GeminiImageService(apiKey: geminiAPIKey, model: geminiModelName)
                    data = try await service.generateStoryboardImage(
                        drawingPrompt: drawingPromptForGeneration(references: referencesForCut(cut)),
                        cutPrompt: prompt,
                        aspectRatio: aspectRatio,
                        referenceImages: referenceImagesForGeneration(for: cut)
                    )
                case .deepInfra:
                    let service = OpenAICompatibleImageService(
                        providerName: "DeepInfra",
                        apiKey: deepInfraAPIKey,
                        model: deepInfraModelName,
                        baseURL: "https://api.deepinfra.com/v1/openai"
                    )
                    data = try await service.generateStoryboardImage(
                        drawingPrompt: drawingPromptForGeneration(references: referencesForCut(cut)),
                        cutPrompt: prompt,
                        aspectRatio: aspectRatio
                    )
                case .novita:
                    let service = NovitaImageService(apiKey: novitaAPIKey, model: novitaModelName)
                    data = try await service.generateStoryboardImage(
                        drawingPrompt: drawingPromptForGeneration(references: referencesForCut(cut)),
                        cutPrompt: prompt,
                        aspectRatio: aspectRatio
                    )
                case .hyperbolic:
                    let service = HyperbolicImageService(apiKey: hyperbolicAPIKey, model: hyperbolicModelName)
                    data = try await service.generateStoryboardImage(
                        drawingPrompt: drawingPromptForGeneration(references: referencesForCut(cut)),
                        cutPrompt: prompt,
                        aspectRatio: aspectRatio
                    )
                }
                let fittedData = ImageHelpers.pngDataByCropping(data, toAspectRatio: aspectRatio)
                await MainActor.run {
                    let fileName = "Images/\(cutID.uuidString).png"
                    document.imageData[fileName] = fittedData
                    if let updateIndex = document.project.cuts.firstIndex(where: { $0.id == cutID }) {
                        document.project.cuts[updateIndex].imageFileName = fileName
                    }
                    recordAIUsage(
                        prompt: [
                            drawingPromptForGeneration(references: referencesForCut(cut)),
                            prompt
                        ].joined(separator: "\n"),
                        kind: .image(
                            provider: imageGenerationProvider,
                            model: currentImageModelName(),
                            referenceCount: referencesForCut(cut).count
                        )
                    )
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

        let aspectRatio = screenAspectRatioValue
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

    private func migrateAIModelsIfNeeded() {
        let currentGeminiImageModel = geminiModelName.trimmingCharacters(in: .whitespacesAndNewlines)
        if [
            "nano-banana-2",
            "gemini-2.5-flash-image",
            "imagen-4.0-generate-001",
            "imagen-4.0-ultra-generate-001",
            "imagen-4.0-fast-generate-001"
        ].contains(currentGeminiImageModel) {
            geminiModelName = "gemini-3.1-flash-image"
        }
        if ["dall-e-2", "dall-e-3"].contains(openAIModelName.trimmingCharacters(in: .whitespacesAndNewlines)) {
            openAIModelName = "gpt-image-2"
        }
        if openAIVideoModelName.trimmingCharacters(in: .whitespacesAndNewlines) == "sora-1" {
            openAIVideoModelName = "sora-2"
        }
    }

    private func cutPrompt(for cut: StoryboardCut) -> String {
        AIPromptBuilder.cutPrompt(for: cut, previousCut: previousCutForContinuity(before: cut))
    }

    private func labeledPrompt(_ label: String, _ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return "\(label):\n\(trimmed)"
    }

    private func dialoguePrompt(for cut: StoryboardCut) -> String {
        AIPromptBuilder.dialoguePrompt(for: cut)
    }

    private func referenceImagesForGeneration(for cut: StoryboardCut) -> [GeminiReferenceImage] {
        let previousFrame = previousCutForContinuity(before: cut).flatMap { previousCut -> GeminiReferenceImage? in
            guard let fileName = previousCut.imageFileName,
                  let data = document.imageData[fileName] else {
                return nil
            }
            return GeminiReferenceImage(mimeType: mimeType(for: fileName), data: data)
        }
        let selectedReferences: [GeminiReferenceImage] = referencesForCut(cut).compactMap { reference in
            guard let data = document.imageData[reference.imageFileName] else { return nil }
            return GeminiReferenceImage(mimeType: mimeType(for: reference.imageFileName), data: data)
        }
        return Array(([previousFrame].compactMap { $0 } + selectedReferences).prefix(5))
    }

    private func openAIImageReferencesForGeneration(for cut: StoryboardCut) -> [OpenAIImageReference] {
        referenceImagesForGeneration(for: cut).map {
            OpenAIImageReference(mimeType: $0.mimeType, data: $0.data)
        }
    }

    private func previousCutForContinuity(before cut: StoryboardCut) -> StoryboardCut? {
        guard cut.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let index = document.project.cuts.firstIndex(where: { $0.id == cut.id }),
              index > 0,
              !requestsContinuityReset(cut) else {
            return nil
        }
        return document.project.cuts[index - 1]
    }

    private func requestsContinuityReset(_ cut: StoryboardCut) -> Bool {
        let transition = cut.aiShotSettings.transition.lowercased()
        let resetMarkers = [
            "scene change", "new scene", "hard cut to", "time jump", "location change",
            "場面転換", "新しい場面", "別の場所", "場所転換", "時間経過", "タイムジャンプ",
            "场景切换", "新场景", "地点切换", "时间跳跃"
        ]
        return resetMarkers.contains { transition.contains($0) }
    }

    private func referencesForCut(_ cut: StoryboardCut) -> [ReferenceImage] {
        cut.enabledReferenceImageIDs.compactMap { id in
            document.project.referenceImages.first { $0.id == id }
        }
    }

    private func drawingPromptForGeneration(references: [ReferenceImage]) -> String {
        [
            document.project.projectContext.promptText,
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

    private func currentImageModelName() -> String {
        switch AIImageGenerationProvider.value(for: imageGenerationProvider) {
        case .gemini:
            return geminiModelName
        case .openAI:
            return openAIModelName
        case .deepInfra:
            return deepInfraModelName
        case .novita:
            return novitaModelName
        case .hyperbolic:
            return hyperbolicModelName
        }
    }

    private func currentVideoModelName(for provider: AIVideoGenerationProvider) -> String {
        switch provider {
        case .gemini:
            return geminiVideoModelName
        case .openAI:
            return openAIVideoModelName
        case .deepInfra:
            return deepInfraVideoModelName
        case .novita:
            return novitaVideoModelName
        }
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
        case image(provider: String, model: String, referenceCount: Int)
        case video(provider: String, model: String, seconds: Int)
    }

    private func canStartAIGeneration() -> Bool {
        guard !isAICostLimitExceeded else {
            generationStatus = "推定料金が上限を超えています。設定で上限を変更してください。"
            return false
        }
        return true
    }

    private func recordAIUsage(prompt: String, kind: AIUsageKind) {
        let tokens = max(1, Int(ceil(Double(prompt.utf8.count) / 4.0)))
        aiEstimatedTokensUsed += tokens
        aiEstimatedCostUSD += estimatedCostUSD(tokens: tokens, kind: kind)
    }

    private func estimatedCostUSD(tokens: Int, kind: AIUsageKind) -> Double {
        switch kind {
        case .image(let provider, let model, let referenceCount):
            if provider == "openai" {
                let outputCost: Double
                if model.contains("mini") {
                    outputCost = 0.052
                } else if model.contains("gpt-image-1") {
                    outputCost = 0.20
                } else {
                    outputCost = 0.20
                }
                let referenceInputCost = Double(referenceCount) * 0.012
                return (Double(tokens) / 1_000_000.0) * 5.0 + referenceInputCost + outputCost
            }
            return (Double(tokens) / 1_000_000.0) * 0.30 + (Double(referenceCount) * 0.0004) + 0.039
        case .video(let provider, let model, let seconds):
            if provider == AIVideoGenerationProvider.openAI.rawValue {
                let perSecond = model.contains("pro") ? 0.30 : 0.10
                return (Double(tokens) / 1_000_000.0) * 5.0 + (Double(seconds) * perSecond)
            }
            let perSecond = model.contains("fast") ? 0.15 : 0.40
            return (Double(tokens) / 1_000_000.0) * 0.30 + (Double(seconds) * perSecond)
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
