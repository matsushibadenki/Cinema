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
    static let mainColumnWidth: CGFloat = adjustableColumnSpace / 2
    static let minimumTextColumnWidth: CGFloat = 160
    static let maximumTextColumnWidth: CGFloat = adjustableColumnSpace - 150
    static let rowHeight: CGFloat = (pageSize.height - (pageMargin * 2) - titleHeight - headerHeight - footerHeight) / 5

    static func clampedTextColumnWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, minimumTextColumnWidth), maximumTextColumnWidth)
    }

    static func imageColumnWidth(for textColumnWidth: CGFloat) -> CGFloat {
        adjustableColumnSpace - clampedTextColumnWidth(textColumnWidth)
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

    var pageIndex: Int
    var cutsPerPage: Int
    var generatingCutID: StoryboardCut.ID?
    var generate: (StoryboardCut.ID) -> Void
    var addAfter: (StoryboardCut.ID) -> Void
    var delete: (StoryboardCut.ID) -> Void

    private var pageCuts: [Binding<StoryboardCut>] {
        let start = pageIndex * cutsPerPage
        let end = min(start + cutsPerPage, document.project.cuts.count)
        guard start < end else { return [] }
        return Array($document.project.cuts[start..<end])
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
        .background(.white)
    }

    private var pageTitle: some View {
        HStack {
            Text(document.project.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            TextField("サブタイトル", text: pageSubtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.black)
                .textFieldStyle(.plain)
                .lineLimit(1)
                .frame(maxWidth: 210)
                .padding(.leading, 8)

            Spacer()
        }
        .frame(height: StoryboardPageLayout.titleHeight)
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

    private var pageStartIndex: Int {
        min(pageIndex * cutsPerPage, max(document.project.cuts.count - 1, 0))
    }

    private var clampedTextColumnWidth: CGFloat {
        StoryboardPageLayout.clampedTextColumnWidth(textColumnWidth)
    }

    private var imageColumnWidth: CGFloat {
        StoryboardPageLayout.imageColumnWidth(for: textColumnWidth)
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
                        screenAspectRatio: screenAspectRatio,
                        showsGeneratePlaceholder: showsGeneratePlaceholder,
                        showsCutActionControls: showsCutActionControls,
                        screenBackgroundBrightness: screenBackgroundBrightness,
                        imageColumnWidth: imageColumnWidth,
                        textColumnWidth: clampedTextColumnWidth,
                        textBaseFontSize: textBaseFontSize,
                        isGenerating: generatingCutID == cut.wrappedValue.id,
                        generate: { generate(cut.wrappedValue.id) },
                        addAfter: { addAfter(cut.wrappedValue.id) },
                        delete: { delete(cut.wrappedValue.id) }
                    )
                }

                ForEach(0..<max(0, cutsPerPage - pageCuts.count), id: \.self) { emptyIndex in
                    EmptyCutRow(
                        imageColumnWidth: imageColumnWidth,
                        textColumnWidth: clampedTextColumnWidth,
                        screenBackgroundBrightness: screenBackgroundBrightness
                    )
                }
            }

            StoryboardTableGrid(
                imageColumnWidth: imageColumnWidth,
                textColumnWidth: clampedTextColumnWidth
            )
        }
        .frame(height: StoryboardPageLayout.headerHeight + (StoryboardPageLayout.rowHeight * CGFloat(cutsPerPage)))
    }

    private var header: some View {
        HStack(spacing: 0) {
            HeaderCell("カット", width: StoryboardPageLayout.sideColumnWidth)
            GapCell()
            HeaderCell("画面", width: imageColumnWidth)
            HeaderCell("内容 / ト書き", width: clampedTextColumnWidth)
            HeaderCell("秒", width: StoryboardPageLayout.sideColumnWidth)
        }
        .frame(height: StoryboardPageLayout.headerHeight)
    }
}

private struct GapCell: View {
    var body: some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: StoryboardPageLayout.cutImageGap)
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
}

struct StoryboardTableGrid: View {
    var imageColumnWidth: CGFloat
    var textColumnWidth: CGFloat
    var color: Color = .black
    var lineWidth: CGFloat = StoryboardPageLayout.tableLineWidth

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let bottomY = max(proxy.size.height - (lineWidth / 2), 0)
                let cutColumnEnd = StoryboardPageLayout.sideColumnWidth
                let screenColumnStart = cutColumnEnd + StoryboardPageLayout.cutImageGap
                let screenColumnEnd = screenColumnStart + imageColumnWidth
                let textColumnEnd = screenColumnEnd + textColumnWidth
                let columns = [
                    CGFloat(0),
                    cutColumnEnd,
                    screenColumnStart,
                    textColumnEnd,
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
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.black)
            .frame(width: width, height: 28)
    }
}
