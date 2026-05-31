import SwiftUI

enum ScriptPageLayout {
    static let pageSize = CGSize(width: 496.06, height: 694.49)
    static let pageMargin: CGFloat = 42.52
    static let footerHeight: CGFloat = 20
    static let subtitleSpineWidth: CGFloat = 34
    static let columnWidth: CGFloat = 30
    static let columnSpacing: CGFloat = 10
    static let speakerTopInset: CGFloat = 14
    static let topRuleInsetRatio: CGFloat = 0.25
    static let topRuleTextInset: CGFloat = 18

    static var contentHeight: CGFloat {
        pageSize.height - (pageMargin * 2) - footerHeight
    }

    static var columnsPerPage: Int {
        let width = pageSize.width - (pageMargin * 2) - subtitleSpineWidth - 18
        return max(1, Int((width + columnSpacing) / (columnWidth + columnSpacing)))
    }
}

struct ScriptEntry: Identifiable {
    enum Kind {
        case subtitle
        case narrative
        case dialogue
    }

    var id = UUID()
    var kind: Kind
    var subtitle: String
    var speaker: String
    var text: String
}

struct ScriptPageView: View {
    var cuts: [StoryboardCut]
    var pageIndex: Int

    private var pages: [[ScriptEntry]] {
        ScriptPageView.pages(for: cuts)
    }

    private var entries: [ScriptEntry] {
        guard pages.indices.contains(pageIndex) else { return [] }
        return pages[pageIndex]
    }

    private var subtitle: String {
        entries.last(where: { !$0.subtitle.isEmpty })?.subtitle ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                scriptColumns

                VerticalText(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: ScriptPageLayout.subtitleSpineWidth, height: ScriptPageLayout.contentHeight)
                    .overlay {
                        Rectangle()
                            .stroke(Color.black, lineWidth: 1)
                    }
            }
            .frame(height: ScriptPageLayout.contentHeight, alignment: .topTrailing)

            HStack {
                Spacer()
                Text("\(pageIndex + 1)")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(.black)
            }
            .frame(height: ScriptPageLayout.footerHeight)
        }
        .padding(ScriptPageLayout.pageMargin)
        .background(.white)
    }

    private var scriptColumns: some View {
        GeometryReader { proxy in
            let topInset = proxy.size.height * ScriptPageLayout.topRuleInsetRatio
            let columnHeight = max(proxy.size.height - topInset - ScriptPageLayout.topRuleTextInset, 1)

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: topInset)

                HStack(alignment: .top, spacing: ScriptPageLayout.columnSpacing) {
                    ForEach(entries.reversed()) { entry in
                        ScriptColumnView(entry: entry)
                            .frame(width: ScriptPageLayout.columnWidth, height: columnHeight)
                    }
                }
                .padding(.top, ScriptPageLayout.topRuleTextInset)
                .frame(maxWidth: .infinity, maxHeight: columnHeight, alignment: .topTrailing)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: proxy.size.width * 0.75, height: 1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }

    static func pageCount(for cuts: [StoryboardCut]) -> Int {
        max(1, pages(for: cuts).count)
    }

    static func pages(for cuts: [StoryboardCut]) -> [[ScriptEntry]] {
        let entries = scriptEntries(for: cuts)
        let chunkSize = ScriptPageLayout.columnsPerPage
        guard !entries.isEmpty else { return [[]] }

        return stride(from: 0, to: entries.count, by: chunkSize).map { start in
            Array(entries[start..<min(start + chunkSize, entries.count)])
        }
    }

    private static func scriptEntries(for cuts: [StoryboardCut]) -> [ScriptEntry] {
        var entries: [ScriptEntry] = []
        var currentSubtitle = ""

        for cut in cuts {
            let subtitle = cut.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !subtitle.isEmpty, subtitle != currentSubtitle {
                currentSubtitle = subtitle
                entries.append(ScriptEntry(kind: .subtitle, subtitle: currentSubtitle, speaker: "", text: currentSubtitle))
            }

            let situation = cut.situation.trimmingCharacters(in: .whitespacesAndNewlines)
            if !situation.isEmpty {
                entries.append(ScriptEntry(kind: .narrative, subtitle: currentSubtitle, speaker: "", text: situation))
            }

            let dialogueLines = cut.dialogueLines.filter {
                !$0.speaker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !$0.dialogue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }

            for line in dialogueLines {
                entries.append(
                    ScriptEntry(
                        kind: .dialogue,
                        subtitle: currentSubtitle,
                        speaker: line.speaker.trimmingCharacters(in: .whitespacesAndNewlines),
                        text: line.dialogue.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                )
            }
        }

        return entries
    }
}

private struct ScriptColumnView: View {
    var entry: ScriptEntry

    var body: some View {
        VStack(spacing: 8) {
            if entry.kind == .subtitle {
                VerticalText(entry.text)
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .padding(.top, 20)
            } else {
                if !entry.speaker.isEmpty {
                    VerticalText(entry.speaker)
                        .font(.system(size: 11, weight: .medium, design: .serif))
                        .padding(.top, ScriptPageLayout.speakerTopInset)
                        .frame(height: 58 + ScriptPageLayout.speakerTopInset, alignment: .top)
                } else {
                    Spacer()
                        .frame(height: 58 + ScriptPageLayout.speakerTopInset)
                }

                VerticalText(entry.text)
                    .font(.system(size: 12, design: .serif))
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .foregroundStyle(.black)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct VerticalText: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        VStack(spacing: 1) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                Text(String(character))
                    .fixedSize()
            }
        }
        .multilineTextAlignment(.center)
    }
}
