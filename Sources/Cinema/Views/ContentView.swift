import SwiftUI

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

struct ContentView: View {
    @Binding var document: StoryboardDocument

    @AppStorage("geminiAPIKey") private var geminiAPIKey = ""
    @AppStorage("geminiModelName") private var geminiModelName = "nano-banana-2"
    @AppStorage("geminiSystemPrompt") private var geminiSystemPrompt = ""
    @AppStorage("imageGenerationProvider") private var imageGenerationProvider = "gemini"
    @AppStorage("openAIAPIKey") private var openAIAPIKey = ""
    @AppStorage("openAIModelName") private var openAIModelName = "gpt-image-1"
    @AppStorage("screenAspectRatio") private var screenAspectRatioRawValue = ScreenAspectRatio.television169.rawValue
    @AppStorage("showsGeneratePlaceholder") private var showsGeneratePlaceholder = true
    @AppStorage("showsCutActionControls") private var showsCutActionControls = true
    @AppStorage("screenBackgroundBrightness") private var screenBackgroundBrightness = 0.0
    @AppStorage("storyboardTextColumnWidth") private var storyboardTextColumnWidth = Double(StoryboardPageLayout.mainColumnWidth)
    @AppStorage("storyboardTextBaseFontSize") private var storyboardTextBaseFontSize = 11.0

    @State private var pageIndex = 0
    @State private var generationStatus: String?
    @State private var generatingCutID: StoryboardCut.ID?
    @State private var zoomScale: CGFloat = 1.0
    @State private var pinchStartZoomScale: CGFloat?
    @State private var displayMode: DocumentDisplayMode = .storyboard

    private let cutsPerPage = 5
    private let minimumZoomScale: CGFloat = 0.5
    private let maximumZoomScale: CGFloat = 2.5
    private let zoomStep: CGFloat = 0.1

    var body: some View {
        NavigationSplitView {
            SidebarView(
                title: $document.project.title,
                documentPrompt: $document.project.documentPrompt,
                cuts: document.project.cuts,
                pageIndex: $pageIndex,
                pageCount: currentPageCount,
                addCut: addCutAtEnd,
                deleteCut: deleteCut,
                deletePage: deletePage,
                jumpToCut: jumpToCut
            )
        } detail: {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    toolbar
                    ScrollView([.horizontal, .vertical]) {
                        zoomablePage
                    }
                    .background(Color(nsColor: .underPageBackgroundColor))
                }

                Divider()

                ReferenceSidebarView(document: $document)
            }
        }
        .navigationTitle(document.project.title)
        .onReceive(NotificationCenter.default.publisher(for: .printCurrentStoryboardPage)) { _ in
            PrintService.printPage(document: document, pageIndex: pageIndex)
        }
        .onChange(of: document.project.cuts.count) { _, _ in
            pageIndex = min(pageIndex, max(currentPageCount - 1, 0))
        }
        .onChange(of: displayMode) { _, _ in
            pageIndex = min(pageIndex, max(currentPageCount - 1, 0))
        }
    }

    private var pageCount: Int {
        max(1, Int(ceil(Double(document.project.cuts.count) / Double(cutsPerPage))))
    }

    private var scriptPageCount: Int {
        ScriptPageView.pageCount(for: document.project.cuts)
    }

    private var currentPageCount: Int {
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

    private var zoomablePage: some View {
        ZStack(alignment: .topLeading) {
            currentPage
                .frame(width: currentPageSize.width, height: currentPageSize.height)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
            .scaleEffect(zoomScale, anchor: .topLeading)
        }
        .frame(
            width: currentPageSize.width * zoomScale,
            height: currentPageSize.height * zoomScale,
            alignment: .topLeading
        )
        .padding(32)
        .gesture(zoomGesture)
    }

    @ViewBuilder
    private var currentPage: some View {
        switch displayMode {
        case .storyboard:
            StoryboardPageView(
                document: $document,
                pageIndex: pageIndex,
                cutsPerPage: cutsPerPage,
                generatingCutID: generatingCutID,
                generate: generateImage,
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
            ScriptPageView(cuts: document.project.cuts, pageIndex: pageIndex)
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
        HStack(spacing: 12) {
            Button {
                pageIndex = max(pageIndex - 1, 0)
            } label: {
                Label("前ページ", systemImage: "chevron.left")
            }
            .disabled(pageIndex == 0)

            Text("\(pageIndex + 1) / \(currentPageCount)")
                .font(.headline.monospacedDigit())
                .frame(minWidth: 72)

            Button {
                pageIndex = min(pageIndex + 1, currentPageCount - 1)
            } label: {
                Label("次ページ", systemImage: "chevron.right")
            }
            .disabled(pageIndex >= currentPageCount - 1)

            Picker("", selection: $displayMode) {
                ForEach(DocumentDisplayMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 150)

            Divider()
                .frame(height: 22)

            Button {
                changeZoom(by: -zoomStep)
            } label: {
                Label("縮小", systemImage: "minus.magnifyingglass")
            }
            .disabled(zoomScale <= minimumZoomScale)

            Text(zoomPercentageText)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 52)

            Button {
                changeZoom(by: zoomStep)
            } label: {
                Label("拡大", systemImage: "plus.magnifyingglass")
            }
            .disabled(zoomScale >= maximumZoomScale)

            Button {
                zoomScale = 1.0
            } label: {
                Label("実寸", systemImage: "1.magnifyingglass")
            }
            .disabled(abs(zoomScale - 1.0) < 0.001)

            Divider()
                .frame(height: 22)

            Button {
                addCutAtEnd()
            } label: {
                Label("カット追加", systemImage: "plus")
            }
            .disabled(displayMode == .script)

            Button {
                PrintService.printPage(document: document, pageIndex: pageIndex)
            } label: {
                Label("プリント", systemImage: "printer")
            }
            .disabled(displayMode == .script)

            Spacer()

            if let generationStatus {
                Text(generationStatus)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var zoomPercentageText: String {
        "\(Int((zoomScale * 100).rounded()))%"
    }

    private func changeZoom(by delta: CGFloat) {
        zoomScale = clampedZoomScale(zoomScale + delta)
    }

    private func clampedZoomScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minimumZoomScale), maximumZoomScale)
    }

    private func addCutAtEnd() {
        document.project.cuts.append(StoryboardCut(cutNumber: document.project.cuts.count + 1))
        document.renumberCuts()
        pageIndex = pageCount - 1
    }

    private func addCutAfter(_ cutID: StoryboardCut.ID) {
        guard let index = document.project.cuts.firstIndex(where: { $0.id == cutID }) else { return }
        document.project.cuts.insert(StoryboardCut(cutNumber: index + 2), at: index + 1)
        document.renumberCuts()
        pageIndex = (index + 1) / cutsPerPage
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

        let start = page * cutsPerPage
        guard start < document.project.cuts.count else { return }

        let end = min(start + cutsPerPage, document.project.cuts.count)
        let removedCuts = document.project.cuts[start..<end]
        for cut in removedCuts {
            if let imageFileName = cut.imageFileName {
                document.imageData[imageFileName] = nil
            }
        }

        document.project.cuts.removeSubrange(start..<end)
        if document.project.cuts.isEmpty {
            document.project.cuts.append(StoryboardCut(cutNumber: 1))
        }
        document.renumberCuts()
        pageIndex = min(page, max(pageCount - 1, 0))
    }

    private func jumpToCut(_ cutID: StoryboardCut.ID) {
        guard let index = document.project.cuts.firstIndex(where: { $0.id == cutID }) else { return }
        pageIndex = index / cutsPerPage
    }

    private func generateImage(for cutID: StoryboardCut.ID) {
        guard let index = document.project.cuts.firstIndex(where: { $0.id == cutID }) else { return }
        let cut = document.project.cuts[index]
        let prompt = cutPrompt(for: cut)
        let aspectRatio = ScreenAspectRatio.value(for: screenAspectRatioRawValue).ratio

        guard !prompt.isEmpty else {
            generationStatus = "内容かト書きを入力してください"
            return
        }

        generatingCutID = cutID
        generationStatus = "カット\(cut.cutNumber)を生成中..."

        Task {
            do {
                let data: Data
                if imageGenerationProvider == "openai" {
                    let service = OpenAIImageService(apiKey: openAIAPIKey, model: openAIModelName)
                    data = try await service.generateStoryboardImage(
                        systemPrompt: geminiSystemPrompt,
                        documentPrompt: document.project.documentPrompt,
                        cutPrompt: prompt,
                        aspectRatio: aspectRatio
                    )
                } else {
                    let service = GeminiImageService(apiKey: geminiAPIKey, model: geminiModelName)
                    data = try await service.generateStoryboardImage(
                        systemPrompt: geminiSystemPrompt,
                        documentPrompt: document.project.documentPrompt,
                        cutPrompt: prompt,
                        aspectRatio: aspectRatio,
                        referenceImages: referenceImagesForGeneration()
                    )
                }
                let fittedData = ImageHelpers.pngDataByCropping(data, toAspectRatio: aspectRatio)
                await MainActor.run {
                    let fileName = "Images/\(cutID.uuidString).png"
                    document.imageData[fileName] = fittedData
                    if let updateIndex = document.project.cuts.firstIndex(where: { $0.id == cutID }) {
                        document.project.cuts[updateIndex].imageFileName = fileName
                    }
                    generationStatus = "カット\(cut.cutNumber)を生成しました"
                    generatingCutID = nil
                }
            } catch {
                await MainActor.run {
                    generationStatus = error.localizedDescription
                    generatingCutID = nil
                }
            }
        }
    }

    private func cutPrompt(for cut: StoryboardCut) -> String {
        [
            labeledPrompt("Scene content", cut.situation),
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

    private func referenceImagesForGeneration() -> [GeminiReferenceImage] {
        document.project.referenceImages.compactMap { reference in
            guard let data = document.imageData[reference.imageFileName] else { return nil }
            return GeminiReferenceImage(mimeType: mimeType(for: reference.imageFileName), data: data)
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
}
