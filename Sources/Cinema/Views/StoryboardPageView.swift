import AppKit
import SwiftUI

enum StoryboardPageLayout {
    static let pageSize = CGSize(width: 595, height: 842)
    static let pageMargin: CGFloat = 42.52
    static let titleHeight: CGFloat = 28
    static let headerHeight: CGFloat = 28
    static let footerHeight: CGFloat = 24
    static let sideColumnWidth: CGFloat = 32
    static let cutImageGap: CGFloat = 3
    static let tableLineWidth: CGFloat = 0.8
    static let tableWidth: CGFloat = pageSize.width - (pageMargin * 2)
    static let adjustableColumnSpace: CGFloat = tableWidth - (sideColumnWidth * 2) - cutImageGap
    static let mainColumnWidth: CGFloat = adjustableColumnSpace * 3 / 5
    static let defaultContentColumnWidth: CGFloat = adjustableColumnSpace / 5
    static let minimumTextColumnWidth: CGFloat = 160
    static let maximumTextColumnWidth: CGFloat = adjustableColumnSpace - 150
    static let minimumImageColumnWidth: CGFloat = 120
    static let minimumContentColumnWidth: CGFloat = 70
    static let minimumActionColumnWidth: CGFloat = 70
    static let rowHeight: CGFloat = (pageSize.height - (pageMargin * 2) - titleHeight - headerHeight - footerHeight) / 5

    static func clampedTextColumnWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, minimumTextColumnWidth), maximumTextColumnWidth)
    }

    static func imageColumnWidth(for textColumnWidth: CGFloat) -> CGFloat {
        adjustableColumnSpace - clampedTextColumnWidth(textColumnWidth)
    }

    static func clampedContentColumnWidth(_ width: CGFloat, textColumnWidth: CGFloat) -> CGFloat {
        let textWidth = clampedTextColumnWidth(textColumnWidth)
        let maximumContentWidth = max(minimumContentColumnWidth, textWidth - minimumActionColumnWidth)
        return min(max(width, minimumContentColumnWidth), maximumContentWidth)
    }

    static func actionColumnWidth(for textColumnWidth: CGFloat, contentColumnWidth: CGFloat) -> CGFloat {
        let textWidth = clampedTextColumnWidth(textColumnWidth)
        return max(textWidth - clampedContentColumnWidth(contentColumnWidth, textColumnWidth: textWidth), minimumActionColumnWidth)
    }
}

struct StoryboardPageView: View {
    @Binding var document: StoryboardDocument
    @Environment(\.screenAspectRatio) private var screenAspectRatio
    @Environment(\.showsGeneratePlaceholder) private var showsGeneratePlaceholder
    @Environment(\.showsCutActionControls) private var showsCutActionControls
    @Environment(\.screenBackgroundBrightness) private var screenBackgroundBrightness
    @Environment(\.storyboardTextColumnWidth) private var textColumnWidth
    @Environment(\.storyboardTextBaseFontSize) private var textBaseFontSize
    @AppStorage("storyboardTextColumnWidth") private var storedTextColumnWidth = Double(StoryboardPageLayout.mainColumnWidth)
    @AppStorage("storyboardContentColumnWidth") private var storedContentColumnWidth = Double(StoryboardPageLayout.defaultContentColumnWidth)
    @AppStorage("storyboardColumnDefaultsVersion") private var columnDefaultsVersion = 0
    @State private var textColumnDragStartWidth: CGFloat?
    @State private var contentColumnDragStartWidth: CGFloat?

    var pageIndex: Int
    var cutsPerPage: Int
    var pageCutIDs: [StoryboardCut.ID]? = nil
    var generatingCutID: StoryboardCut.ID?
    var generate: (StoryboardCut.ID) -> Void
    var importImage: (StoryboardCut.ID) -> Void
    var addAfter: (StoryboardCut.ID) -> Void
    var delete: (StoryboardCut.ID) -> Void

    private var pageCuts: [Binding<StoryboardCut>] {
        if let pageCutIDs {
            return pageCutIDs.compactMap { id in
                guard let index = document.project.cuts.firstIndex(where: { $0.id == id }) else { return nil }
                return $document.project.cuts[index]
            }
        } else {
            let start = pageIndex * cutsPerPage
            let end = min(start + cutsPerPage, document.project.cuts.count)
            guard start < end else { return [] }
            return Array($document.project.cuts[start..<end])
        }
    }

    static func pageCutIDs(for cuts: [StoryboardCut], cutsPerPage: Int = 5) -> [[StoryboardCut.ID]] {
        var pages: [[StoryboardCut.ID]] = []
        var currentPage: [StoryboardCut.ID] = []

        for cut in cuts {
            let startsNewScene = !cut.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if startsNewScene, !currentPage.isEmpty {
                pages.append(currentPage)
                currentPage = []
            }

            if currentPage.count == cutsPerPage {
                pages.append(currentPage)
                currentPage = []
            }

            currentPage.append(cut.id)
        }

        if !currentPage.isEmpty {
            pages.append(currentPage)
        }

        return pages.isEmpty ? [[]] : pages
    }

    var body: some View {
        VStack(spacing: 0) {
            pageTitle
            table

            HStack {
                Spacer()
                Text("\(pageIndex + 1)")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(.black)
                Spacer()
            }
            .frame(height: StoryboardPageLayout.footerHeight)
        }
        .padding(StoryboardPageLayout.pageMargin)
        .background(
            LinearGradient(
                colors: [.white, Color(red: 0.995, green: 0.992, blue: 0.982)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear(perform: applyDefaultColumnWidthsIfNeeded)
    }

    private var pageTitle: some View {
        HStack {
            CompactPageTextField(
                text: $document.project.title,
                placeholder: "タイトル",
                font: .systemFont(ofSize: 15, weight: .semibold)
            )
                .frame(minWidth: 120, maxWidth: 160)

            CompactPageTextField(
                text: pageSubtitle,
                placeholder: "ブロック",
                font: .systemFont(ofSize: 12, weight: .medium)
            )
                .frame(width: 120)
                .padding(.leading, 8)

            CompactPageTextField(
                text: pageScriptHeading,
                placeholder: "シーケンス",
                font: .systemFont(ofSize: 12, weight: .medium)
            )
                .frame(width: 120)
                .padding(.leading, 8)

            CompactPageTextField(
                text: pageSceneName,
                placeholder: "シーン",
                font: .systemFont(ofSize: 12, weight: .medium)
            )
                .frame(width: 110)
                .padding(.leading, 8)

            Spacer()
        }
        .frame(height: StoryboardPageLayout.titleHeight)
        .foregroundStyle(CinemaDesign.ink)
    }

    private var pageSubtitle: Binding<String> {
        Binding {
            guard document.project.cuts.indices.contains(pageStartIndex) else { return "" }
            return document.project.cuts[pageStartIndex].subtitle
        } set: { newValue in
            guard document.project.cuts.indices.contains(pageStartIndex) else { return }
            document.project.cuts[pageStartIndex].subtitle = newValue
        }
    }

    private var pageScriptHeading: Binding<String> {
        Binding {
            guard document.project.cuts.indices.contains(pageStartIndex) else { return "" }
            return document.project.cuts[pageStartIndex].scriptHeading
        } set: { newValue in
            guard document.project.cuts.indices.contains(pageStartIndex) else { return }
            document.project.cuts[pageStartIndex].scriptHeading = newValue
        }
    }

    private var pageSceneName: Binding<String> {
        Binding {
            guard document.project.cuts.indices.contains(pageStartIndex) else { return "" }
            return document.project.cuts[pageStartIndex].sceneName
        } set: { newValue in
            guard document.project.cuts.indices.contains(pageStartIndex) else { return }
            document.project.cuts[pageStartIndex].sceneName = newValue
        }
    }

    private var pageStartIndex: Int {
        if let firstID = pageCutIDs?.first,
           let index = document.project.cuts.firstIndex(where: { $0.id == firstID }) {
            return index
        }
        return min(pageIndex * cutsPerPage, max(document.project.cuts.count - 1, 0))
    }

    private var clampedTextColumnWidth: CGFloat {
        StoryboardPageLayout.clampedTextColumnWidth(textColumnWidth)
    }

    private var imageColumnWidth: CGFloat {
        StoryboardPageLayout.imageColumnWidth(for: textColumnWidth)
    }

    private var contentColumnWidth: CGFloat {
        StoryboardPageLayout.clampedContentColumnWidth(CGFloat(storedContentColumnWidth), textColumnWidth: clampedTextColumnWidth)
    }

    private var actionColumnWidth: CGFloat {
        StoryboardPageLayout.actionColumnWidth(for: clampedTextColumnWidth, contentColumnWidth: contentColumnWidth)
    }

    private var table: some View {
        ZStack {
            VStack(spacing: 0) {
                header

                ForEach(Array(pageCuts.indices), id: \.self) { index in
                    let cut = pageCuts[index]
                    StoryboardCutRow(
                        cut: cut,
                        imageData: cut.wrappedValue.imageFileName.flatMap { document.imageData[$0] },
                        image: ImageHelpers.nsImage(from: cut.wrappedValue.imageFileName.flatMap { document.imageData[$0] }),
                        referenceImages: document.project.referenceImages,
                        screenAspectRatio: screenAspectRatio,
                        showsGeneratePlaceholder: showsGeneratePlaceholder,
                        showsCutActionControls: showsCutActionControls,
                        screenBackgroundBrightness: screenBackgroundBrightness,
                        imageColumnWidth: imageColumnWidth,
                        contentColumnWidth: contentColumnWidth,
                        actionColumnWidth: actionColumnWidth,
                        textBaseFontSize: textBaseFontSize,
                        isGenerating: generatingCutID == cut.wrappedValue.id,
                        generate: { generate(cut.wrappedValue.id) },
                        importImage: { importImage(cut.wrappedValue.id) },
                        addAfter: { addAfter(cut.wrappedValue.id) },
                        delete: { delete(cut.wrappedValue.id) }
                    )
                }

                ForEach(0..<max(0, cutsPerPage - pageCuts.count), id: \.self) { emptyIndex in
                    EmptyCutRow(
                        imageColumnWidth: imageColumnWidth,
                        contentColumnWidth: contentColumnWidth,
                        actionColumnWidth: actionColumnWidth,
                        screenBackgroundBrightness: screenBackgroundBrightness
                    )
                }
            }

            StoryboardTableGrid(
                imageColumnWidth: imageColumnWidth,
                contentColumnWidth: contentColumnWidth,
                actionColumnWidth: actionColumnWidth
            )

            columnResizeHandles
        }
        .frame(height: StoryboardPageLayout.headerHeight + (StoryboardPageLayout.rowHeight * CGFloat(cutsPerPage)))
    }

    private var header: some View {
        HStack(spacing: 0) {
            HeaderCell("カット", width: StoryboardPageLayout.sideColumnWidth)
            GapCell()
            HeaderCell("画面", width: imageColumnWidth)
            HeaderCell("内容", width: contentColumnWidth)
            HeaderCell("セリフ", width: actionColumnWidth)
            HeaderCell("秒", width: StoryboardPageLayout.sideColumnWidth)
        }
        .frame(height: StoryboardPageLayout.headerHeight)
    }

    private var columnResizeHandles: some View {
        let tableHeight = StoryboardPageLayout.headerHeight + (StoryboardPageLayout.rowHeight * CGFloat(cutsPerPage))
        let screenContentX = StoryboardPageLayout.sideColumnWidth + StoryboardPageLayout.cutImageGap + imageColumnWidth
        let contentActionX = screenContentX + contentColumnWidth

        return ZStack(alignment: .topLeading) {
            ColumnResizeHandle(help: "ドラッグして画面と内容の幅を調整")
                .frame(width: 10, height: tableHeight)
                .offset(x: screenContentX - 5)
                .gesture(textColumnResizeGesture)

            ColumnResizeHandle(help: "ドラッグして内容とセリフの幅を調整")
                .frame(width: 10, height: tableHeight)
                .offset(x: contentActionX - 5)
                .gesture(contentColumnResizeGesture)
        }
        .frame(width: StoryboardPageLayout.tableWidth, height: tableHeight, alignment: .topLeading)
    }

    private var textColumnResizeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if textColumnDragStartWidth == nil {
                    textColumnDragStartWidth = clampedTextColumnWidth
                }

                let start = textColumnDragStartWidth ?? clampedTextColumnWidth
                let next = start - value.translation.width
                storedTextColumnWidth = Double(StoryboardPageLayout.clampedTextColumnWidth(next))
            }
            .onEnded { _ in
                textColumnDragStartWidth = nil
            }
    }

    private var contentColumnResizeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if contentColumnDragStartWidth == nil {
                    contentColumnDragStartWidth = contentColumnWidth
                }

                let start = contentColumnDragStartWidth ?? contentColumnWidth
                let next = start + value.translation.width
                storedContentColumnWidth = Double(StoryboardPageLayout.clampedContentColumnWidth(next, textColumnWidth: clampedTextColumnWidth))
            }
            .onEnded { _ in
                contentColumnDragStartWidth = nil
            }
    }

    private func applyDefaultColumnWidthsIfNeeded() {
        guard columnDefaultsVersion < 1 else { return }
        storedTextColumnWidth = Double(StoryboardPageLayout.mainColumnWidth)
        storedContentColumnWidth = Double(StoryboardPageLayout.defaultContentColumnWidth)
        columnDefaultsVersion = 1
    }
}

private struct GapCell: View {
    var body: some View {
        Rectangle()
            .fill(Color(red: 0.98, green: 0.975, blue: 0.955))
            .frame(width: StoryboardPageLayout.cutImageGap)
    }
}

private struct ColumnResizeHandle: View {
    @State private var isHovering = false

    var help: String

    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.001))
            .contentShape(Rectangle())
            .onHover { hovering in
                guard hovering != isHovering else { return }
                isHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .help(help)
    }
}

private struct CompactPageTextField: NSViewRepresentable {
    @Binding var text: String

    var placeholder: String
    var font: NSFont

    func makeNSView(context: Context) -> CompactPageNSTextField {
        let field = CompactPageNSTextField(frame: .zero)
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = context.coordinator
        field.lineBreakMode = .byTruncatingTail
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        return field
    }

    func updateNSView(_ nsView: CompactPageNSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
        nsView.font = font
        nsView.textColor = .black
        nsView.alignment = .left
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text = field.stringValue
        }
    }
}

private final class CompactPageNSTextField: NSTextField {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}

private struct ScreenAspectRatioKey: EnvironmentKey {
    static let defaultValue: CGFloat = ScreenAspectRatio.television169.ratio
}

private struct ShowsGeneratePlaceholderKey: EnvironmentKey {
    static let defaultValue = true
}

private struct ShowsCutActionControlsKey: EnvironmentKey {
    static let defaultValue = true
}

private struct ScreenBackgroundBrightnessKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct StoryboardTextColumnWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = StoryboardPageLayout.mainColumnWidth
}

private struct StoryboardTextBaseFontSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat = 11
}

private struct IsPrintingStoryboardKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var screenAspectRatio: CGFloat {
        get { self[ScreenAspectRatioKey.self] }
        set { self[ScreenAspectRatioKey.self] = newValue }
    }

    var showsGeneratePlaceholder: Bool {
        get { self[ShowsGeneratePlaceholderKey.self] }
        set { self[ShowsGeneratePlaceholderKey.self] = newValue }
    }

    var showsCutActionControls: Bool {
        get { self[ShowsCutActionControlsKey.self] }
        set { self[ShowsCutActionControlsKey.self] = newValue }
    }

    var screenBackgroundBrightness: CGFloat {
        get { self[ScreenBackgroundBrightnessKey.self] }
        set { self[ScreenBackgroundBrightnessKey.self] = newValue }
    }

    var storyboardTextColumnWidth: CGFloat {
        get { self[StoryboardTextColumnWidthKey.self] }
        set { self[StoryboardTextColumnWidthKey.self] = newValue }
    }

    var storyboardTextBaseFontSize: CGFloat {
        get { self[StoryboardTextBaseFontSizeKey.self] }
        set { self[StoryboardTextBaseFontSizeKey.self] = newValue }
    }

    var isPrintingStoryboard: Bool {
        get { self[IsPrintingStoryboardKey.self] }
        set { self[IsPrintingStoryboardKey.self] = newValue }
    }
}

extension View {
    func screenAspectRatio(_ ratio: CGFloat) -> some View {
        environment(\.screenAspectRatio, ratio)
    }

    func showsGeneratePlaceholder(_ isVisible: Bool) -> some View {
        environment(\.showsGeneratePlaceholder, isVisible)
    }

    func showsCutActionControls(_ isVisible: Bool) -> some View {
        environment(\.showsCutActionControls, isVisible)
    }

    func screenBackgroundBrightness(_ brightness: CGFloat) -> some View {
        environment(\.screenBackgroundBrightness, min(max(brightness, 0), 1))
    }

    func storyboardTextColumnWidth(_ width: CGFloat) -> some View {
        environment(\.storyboardTextColumnWidth, width)
    }

    func storyboardTextBaseFontSize(_ size: CGFloat) -> some View {
        environment(\.storyboardTextBaseFontSize, size)
    }

    func printingStoryboard(_ isPrinting: Bool) -> some View {
        environment(\.isPrintingStoryboard, isPrinting)
    }
}

struct StoryboardTableGrid: View {
    var imageColumnWidth: CGFloat
    var contentColumnWidth: CGFloat
    var actionColumnWidth: CGFloat
    var color: Color = .black
    var lineWidth: CGFloat = StoryboardPageLayout.tableLineWidth

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let bottomY = max(proxy.size.height - (lineWidth / 2), 0)
                let cutColumnEnd = StoryboardPageLayout.sideColumnWidth
                let screenColumnStart = cutColumnEnd + StoryboardPageLayout.cutImageGap
                let screenColumnEnd = screenColumnStart + imageColumnWidth
                let contentColumnEnd = screenColumnEnd + contentColumnWidth
                let actionColumnEnd = contentColumnEnd + actionColumnWidth
                let columns = [
                    CGFloat(0),
                    cutColumnEnd,
                    screenColumnStart,
                    screenColumnEnd,
                    contentColumnEnd,
                    actionColumnEnd,
                    proxy.size.width
                ]

                for x in columns {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: bottomY))
                }

                path.move(to: CGPoint(x: screenColumnEnd, y: 0))
                path.addLine(to: CGPoint(x: screenColumnEnd, y: StoryboardPageLayout.headerHeight))

                let horizontalLines = (0...5).map { StoryboardPageLayout.headerHeight + (CGFloat($0) * StoryboardPageLayout.rowHeight) }
                let allHorizontalLines = [CGFloat(0)] + horizontalLines
                for y in allHorizontalLines {
                    if abs(y - proxy.size.height) < 0.5 {
                        path.move(to: CGPoint(x: 0, y: bottomY))
                        path.addLine(to: CGPoint(x: cutColumnEnd, y: bottomY))
                        path.move(to: CGPoint(x: screenColumnStart, y: bottomY))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: bottomY))
                        continue
                    }

                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: cutColumnEnd, y: y))
                    path.move(to: CGPoint(x: screenColumnStart, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
            }
            .stroke(color, lineWidth: lineWidth)
        }
        .allowsHitTesting(false)
    }
}

private struct HeaderCell: View {
    var title: String
    var width: CGFloat

    init(_ title: String, width: CGFloat) {
        self.title = title
        self.width = width
    }

    var body: some View {
        Text(title)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(CinemaDesign.ink)
            .frame(width: width, height: 28)
            .background(Color(red: 0.985, green: 0.98, blue: 0.962))
    }
}
