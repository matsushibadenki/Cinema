import SwiftUI

struct PrintablePageView: View {
    @AppStorage("screenAspectRatio") private var screenAspectRatioRawValue = ScreenAspectRatio.television169.rawValue
    @AppStorage("showsGeneratePlaceholder") private var showsGeneratePlaceholder = true
    @AppStorage("showsCutActionControls") private var showsCutActionControls = true
    @AppStorage("screenBackgroundBrightness") private var screenBackgroundBrightness = 0.0
    @AppStorage("storyboardTextColumnWidth") private var storyboardTextColumnWidth = Double(StoryboardPageLayout.mainColumnWidth)
    @AppStorage("storyboardTextBaseFontSize") private var storyboardTextBaseFontSize = 11.0

    var document: StoryboardDocument
    var pageIndex: Int

    var body: some View {
        StoryboardPageView(
            document: .constant(document),
            pageIndex: pageIndex,
            cutsPerPage: 5,
            pageCutIDs: pageCutIDs,
            generatingCutID: nil,
            generate: { _ in },
            importImage: { _ in },
            addAfter: { _ in },
            delete: { _ in }
        )
        .screenAspectRatio(ScreenAspectRatio.value(for: screenAspectRatioRawValue).ratio)
        .showsGeneratePlaceholder(showsGeneratePlaceholder)
        .showsCutActionControls(false)
        .screenBackgroundBrightness(CGFloat(screenBackgroundBrightness))
        .storyboardTextColumnWidth(CGFloat(storyboardTextColumnWidth))
        .storyboardTextBaseFontSize(CGFloat(storyboardTextBaseFontSize))
        .printingStoryboard(true)
    }

    private var pageCutIDs: [StoryboardCut.ID] {
        let pages = StoryboardPageView.pageCutIDs(for: document.project.cuts, cutsPerPage: 5)
        guard pages.indices.contains(pageIndex) else { return [] }
        return pages[pageIndex]
    }
}
