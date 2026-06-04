// file:///Users/Shared/Program/Xcode/Cinema/Sources/Cinema/Views/ScriptPageView.swift
// ScriptPageView.swift
// 絵コンテの内容から縦書きの台本用PDF/プレビューページを生成・表示するビュー

import AppKit
import SwiftUI

enum ScriptPageLayout {
    static let pageSize = CGSize(width: 496.06, height: 694.49)
    static let pageMargin: CGFloat = 42.52
    static let footerHeight: CGFloat = 20
    static let subtitleSpineWidth: CGFloat = 34
    static let columnWidth: CGFloat = 34
    static let dialogueGroupMinimumWidth: CGFloat = 46
    static let bodyColumnWidth: CGFloat = 14
    static let bodyLineAdvance: CGFloat = 17
    static let columnSpacing: CGFloat = 2
    static let bodyColumnSpacing: CGFloat = 0
    static let speakerBodyGapCharacters = 2
    static let speakerTopInset: CGFloat = 10
    static let speakerFontSize: CGFloat = 11.5
    static let bodyFontSize: CGFloat = 12
    static let subtitleFontSize: CGFloat = 13
    static let contentLabelWidth: CGFloat = 16
    static let topRuleInsetRatio: CGFloat = 0.25
    static let topRuleTextInset: CGFloat = 12
    static let spineBlockHeight: CGFloat = 112
    static let spineSequenceHeight: CGFloat = 110
    static let spineSceneHeight: CGFloat = 92
    static let spineTitleHeight: CGFloat = 120
    static let dialogueTopOffset: CGFloat = 82
    static let bodyCharactersPerColumn = 24
    static let narrativeCharactersPerColumn = 8

    static var contentHeight: CGFloat {
        pageSize.height - (pageMargin * 2) - footerHeight
    }

    static var columnsPerPage: Int {
        let width = pageSize.width - (pageMargin * 2) - subtitleSpineWidth - contentLabelWidth - 24
        return max(1, Int((width + columnSpacing) / (columnWidth + columnSpacing)))
    }

    static func serifFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        if let font = NSFont(name: "Hiragino Mincho ProN", size: size) {
            return NSFontManager.shared.convert(font, toHaveTrait: weight == .bold || weight == .semibold ? .boldFontMask : [])
        }
        return NSFont.systemFont(ofSize: size, weight: weight)
    }
}

struct ScriptEntry: Identifiable {
    enum Kind {
        case subtitle
        case narrative
        case speaker
        case dialogue
    }

    var id = UUID()
    var kind: Kind
    var subtitle: String
    var scriptHeading: String
    var sceneLabel: String
    var speaker: String
    var text: String
}

struct ScriptPageView: View {
    var cuts: [StoryboardCut]
    var pageIndex: Int
    var documentTitle: String

    @AppStorage("scriptSpeakerFontSize") private var scriptSpeakerFontSize = Double(ScriptPageLayout.speakerFontSize)
    @AppStorage("scriptBodyFontSize") private var scriptBodyFontSize = Double(ScriptPageLayout.bodyFontSize)
    @AppStorage("scriptBodyLineAdvance") private var scriptBodyLineAdvance = Double(ScriptPageLayout.bodyLineAdvance)
    @AppStorage("scriptContentLabelFontSize") private var scriptContentLabelFontSize = 10.0
    @AppStorage("scriptSceneFontSize") private var scriptSceneFontSize = 11.5

    private var pages: [[ScriptEntry]] {
        ScriptPageView.pages(for: cuts)
    }

    private var entries: [ScriptEntry] {
        guard pages.indices.contains(pageIndex) else { return [] }
        return pages[pageIndex]
    }

    private var pageBlockLabel: String {
        entries.first(where: { !$0.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.subtitle ?? ""
    }

    private var pageSequenceLabel: String {
        entries.first(where: { !$0.scriptHeading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.scriptHeading ?? ""
    }

    private var pageSceneLabel: String {
        entries.first(where: { !$0.sceneLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.sceneLabel ?? ""
    }

    private var displayDocumentTitle: String {
        let title = documentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return title == "Untitled Storyboard" ? "" : title
    }

    private var typography: ScriptTypography {
        let speakerFontSize = safeCGFloat(scriptSpeakerFontSize, fallback: ScriptPageLayout.speakerFontSize, min: 8, max: 18)
        let bodyFontSize = safeCGFloat(scriptBodyFontSize, fallback: ScriptPageLayout.bodyFontSize, min: 8, max: 18)
        let bodyLineAdvance = safeCGFloat(scriptBodyLineAdvance, fallback: ScriptPageLayout.bodyLineAdvance, min: 14, max: 28)
        let contentLabelFontSize = safeCGFloat(scriptContentLabelFontSize, fallback: 10, min: 7, max: 16)
        let sceneFontSize = safeCGFloat(scriptSceneFontSize, fallback: 11.5, min: 8, max: 18)
        return ScriptTypography(
            speakerFontSize: speakerFontSize,
            bodyFontSize: bodyFontSize,
            bodyLineAdvance: max(bodyLineAdvance, bodyFontSize * 1.4),
            contentLabelFontSize: contentLabelFontSize,
            sceneFontSize: sceneFontSize
        )
    }

    private func safeCGFloat(_ value: Double, fallback: CGFloat, min lowerBound: CGFloat, max upperBound: CGFloat) -> CGFloat {
        let converted = CGFloat(value)
        guard converted.isFinite else { return fallback }
        return min(max(converted, lowerBound), upperBound)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                scriptColumns

                VerticalText(
                    "内容",
                    font: .systemFont(ofSize: typography.contentLabelFontSize, weight: .medium),
                    horizontalInset: 2,
                    verticalInset: 10
                )
                    .frame(width: ScriptPageLayout.contentLabelWidth, height: ScriptPageLayout.contentHeight, alignment: .top)

                scriptSpine
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

    private var scriptSpine: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Spacer().frame(height: 10)

                if !pageBlockLabel.isEmpty {
                    VerticalText(
                        pageBlockLabel,
                        font: ScriptPageLayout.serifFont(size: 14, weight: .semibold),
                        horizontalInset: nil,
                        verticalInset: 4
                    )
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: ScriptPageLayout.spineBlockHeight, alignment: .top)
                } else {
                    Spacer().frame(height: ScriptPageLayout.spineBlockHeight)
                }

                Spacer().frame(height: 8)

                if !pageSequenceLabel.isEmpty {
                    VerticalText(
                        pageSequenceLabel,
                        font: ScriptPageLayout.serifFont(size: typography.sceneFontSize, weight: .regular),
                        horizontalInset: nil,
                        verticalInset: 4
                    )
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: ScriptPageLayout.spineSequenceHeight, alignment: .top)
                } else {
                    Spacer().frame(height: ScriptPageLayout.spineSequenceHeight)
                }

                Spacer().frame(height: 8)

                if !pageSceneLabel.isEmpty {
                    VerticalText(
                        pageSceneLabel,
                        font: ScriptPageLayout.serifFont(size: typography.sceneFontSize, weight: .regular),
                        horizontalInset: nil,
                        verticalInset: 2
                    )
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: ScriptPageLayout.spineSceneHeight, alignment: .top)
                } else {
                    Spacer().frame(height: ScriptPageLayout.spineSceneHeight)
                }

                Spacer(minLength: 0)

                if !displayDocumentTitle.isEmpty {
                    VerticalText(
                        displayDocumentTitle,
                        font: ScriptPageLayout.serifFont(size: 12, weight: .regular),
                        horizontalInset: nil,
                        verticalInset: 2
                    )
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: ScriptPageLayout.spineTitleHeight, alignment: .bottom)
                }

                Spacer().frame(height: 10)
            }
        }
        .frame(width: ScriptPageLayout.subtitleSpineWidth, height: ScriptPageLayout.contentHeight)
        .overlay {
            Rectangle()
                .stroke(Color.black, lineWidth: 1)
        }
    }

    private var scriptColumns: some View {
        GeometryReader { proxy in
            let topInset = proxy.size.height * ScriptPageLayout.topRuleInsetRatio
            let bodyHeight = max(proxy.size.height - topInset - ScriptPageLayout.topRuleTextInset, 1)
            let narrativeEntries = entries.filter { $0.kind == .narrative }
            let bodyEntries = entries.filter { $0.kind != .narrative }

            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: ScriptPageLayout.columnSpacing) {
                    ForEach(narrativeEntries.reversed()) { entry in
                        ScriptColumnView(entry: entry, typography: typography, showsSideLabel: false)
                            .frame(width: ScriptColumnView.columnWidth(for: entry, typography: typography), height: max(topInset - 10, 1), alignment: .bottomTrailing)
                            .clipped()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: topInset, maxHeight: topInset, alignment: .bottomTrailing)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: proxy.size.width * 0.75, height: 1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                HStack(alignment: .top, spacing: ScriptPageLayout.bodyColumnSpacing) {
                    ForEach(bodyEntries.reversed()) { entry in
                        ScriptColumnView(entry: entry, typography: typography)
                            .frame(width: ScriptColumnView.columnWidth(for: entry, typography: typography), height: bodyHeight, alignment: .topTrailing)
                    }
                }
                .padding(.top, ScriptPageLayout.topRuleTextInset)
                .frame(maxWidth: .infinity, maxHeight: bodyHeight, alignment: .topTrailing)
                .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .clipped()
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
        var currentScriptHeading = ""
        var currentSceneName = ""
        var currentSceneLabel = ""
        var hasStartedScene = false

        for cut in cuts {
            let subtitle = cut.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let scriptHeading = cut.scriptHeading.trimmingCharacters(in: .whitespacesAndNewlines)
            let sceneName = cut.sceneName.trimmingCharacters(in: .whitespacesAndNewlines)
            let situation = cut.situation.trimmingCharacters(in: .whitespacesAndNewlines)
            let dialogueLines = cut.dialogueLines.filter {
                !$0.speaker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !$0.dialogue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            let hasMetadata = !subtitle.isEmpty || !scriptHeading.isEmpty || !sceneName.isEmpty
            let hasContent = !situation.isEmpty || !dialogueLines.isEmpty

            guard hasMetadata || hasContent else { continue }

            let startsNewScene = !hasStartedScene ||
                (!subtitle.isEmpty && subtitle != currentSubtitle) ||
                (!scriptHeading.isEmpty && scriptHeading != currentScriptHeading) ||
                (!sceneName.isEmpty && sceneName != currentSceneName)

            if startsNewScene {
                hasStartedScene = true
                currentSubtitle = subtitle
                currentSceneName = sceneName
                currentSceneLabel = sceneName
                currentScriptHeading = scriptHeading
                entries.append(
                    ScriptEntry(
                        kind: .subtitle,
                        subtitle: currentSubtitle,
                        scriptHeading: currentScriptHeading,
                        sceneLabel: currentSceneLabel,
                        speaker: "",
                        text: currentScriptHeading
                    )
                )
            }

            if !situation.isEmpty {
                appendTextEntries(
                    to: &entries,
                    kind: .narrative,
                    subtitle: currentSubtitle,
                    scriptHeading: currentScriptHeading,
                    sceneLabel: currentSceneLabel,
                    speaker: "",
                    text: situation,
                    charactersPerColumn: ScriptPageLayout.narrativeCharactersPerColumn
                )
            }

            for line in dialogueLines {
                appendDialogueEntries(
                    to: &entries,
                    subtitle: currentSubtitle,
                    scriptHeading: currentScriptHeading,
                    sceneLabel: currentSceneLabel,
                    speaker: line.speaker.trimmingCharacters(in: .whitespacesAndNewlines),
                    text: line.dialogue.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        }

        return entries
    }

    private static func appendDialogueEntries(
        to entries: inout [ScriptEntry],
        subtitle: String,
        scriptHeading: String,
        sceneLabel: String,
        speaker: String,
        text: String
    ) {
        entries.append(
            ScriptEntry(
                kind: .dialogue,
                subtitle: subtitle,
                scriptHeading: scriptHeading,
                sceneLabel: sceneLabel,
                speaker: speaker,
                text: text
            )
        )
    }

    private static func appendTextEntries(
        to entries: inout [ScriptEntry],
        kind: ScriptEntry.Kind,
        subtitle: String,
        scriptHeading: String,
        sceneLabel: String,
        speaker: String,
        text: String,
        charactersPerColumn: Int
    ) {
        for chunk in chunkedText(text, firstLimit: charactersPerColumn, followingLimit: charactersPerColumn) {
            entries.append(
                ScriptEntry(
                    kind: kind,
                    subtitle: subtitle,
                    scriptHeading: scriptHeading,
                    sceneLabel: sceneLabel,
                    speaker: speaker,
                    text: chunk
                )
            )
        }
    }

    private static func chunkedText(_ text: String, firstLimit: Int, followingLimit: Int) -> [String] {
        var remaining = Array(text)
        var chunks: [String] = []
        var limit = max(firstLimit, 1)

        while !remaining.isEmpty {
            let count = min(limit, remaining.count)
            chunks.append(String(remaining.prefix(count)))
            remaining.removeFirst(count)
            limit = max(followingLimit, 1)
        }

        return chunks
    }
}

private struct ScriptTypography {
    var speakerFontSize: CGFloat
    var bodyFontSize: CGFloat
    var bodyLineAdvance: CGFloat
    var contentLabelFontSize: CGFloat
    var sceneFontSize: CGFloat
}

private struct ScriptColumnView: View {
    var entry: ScriptEntry
    var typography: ScriptTypography
    var showsSideLabel = true

    static func columnWidth(for entry: ScriptEntry, typography: ScriptTypography) -> CGFloat {
        switch entry.kind {
        case .dialogue:
            return dialogueGroupWidth(for: entry, typography: typography)
        case .narrative:
            return typography.bodyLineAdvance
        case .subtitle, .speaker:
            return ScriptPageLayout.columnWidth
        }
    }

    private static func dialogueGroupWidth(for entry: ScriptEntry, typography: ScriptTypography) -> CGFloat {
        let chunks = dialogueChunks(for: entry.text)
        let bodyWidth = ScriptPageLayout.bodyColumnWidth + (CGFloat(max(chunks.count - 1, 0)) * typography.bodyLineAdvance)
        return max(ScriptPageLayout.dialogueGroupMinimumWidth, bodyWidth + typography.bodyFontSize)
    }

    var body: some View {
        VStack(spacing: 8) {
            if entry.kind == .subtitle {
                VerticalText(entry.text, font: ScriptPageLayout.serifFont(size: ScriptPageLayout.bodyFontSize, weight: .semibold))
                    .frame(width: ScriptPageLayout.columnWidth, alignment: .top)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 20)
            } else if entry.kind == .dialogue, !entry.speaker.isEmpty {
                ZStack(alignment: .topTrailing) {
                    InlineVerticalText(
                        entry.speaker,
                        fontSize: typography.speakerFontSize,
                        weight: .medium
                    )
                    .frame(width: ScriptPageLayout.columnWidth, alignment: .bottomTrailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .frame(
                        height: max(
                            ScriptPageLayout.dialogueTopOffset - (typography.bodyFontSize * CGFloat(ScriptPageLayout.speakerBodyGapCharacters)),
                            1
                        ),
                        alignment: .bottomTrailing
                    )

                    dialogueBody
                        .padding(.top, ScriptPageLayout.dialogueTopOffset)
                }
                .frame(width: Self.columnWidth(for: entry, typography: typography), alignment: .topTrailing)
                .frame(maxHeight: .infinity, alignment: .topTrailing)
            } else if entry.kind == .dialogue {
                dialogueBody
                    .padding(.top, ScriptPageLayout.dialogueTopOffset)
                    .frame(width: Self.columnWidth(for: entry, typography: typography), alignment: .topTrailing)
                    .frame(maxHeight: .infinity, alignment: .topTrailing)
            } else {
                InlineVerticalText(
                    columnText,
                    fontSize: entry.kind == .speaker ? typography.speakerFontSize : typography.bodyFontSize,
                    weight: entry.kind == .speaker ? .medium : .regular,
                    preservesCharacterWidth: true
                )
                .frame(width: Self.columnWidth(for: entry, typography: typography), alignment: .topTrailing)
                .frame(maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, topOffset)
            }
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    private var topOffset: CGFloat {
        switch entry.kind {
        case .dialogue:
            return ScriptPageLayout.dialogueTopOffset
        case .speaker:
            return ScriptPageLayout.speakerTopInset
        case .narrative, .subtitle:
            return 0
        }
    }

    private var columnText: String {
        if !showsSideLabel, entry.kind == .narrative {
            return entry.text
        }

        switch entry.kind {
        case .narrative:
            return entry.text
        case .speaker:
            return entry.speaker
        case .dialogue, .subtitle:
            return entry.text
        }
    }

    private var dialogueBody: some View {
        let chunks = Self.dialogueChunks(for: entry.text)
        let width = ScriptPageLayout.bodyColumnWidth + (CGFloat(max(chunks.count - 1, 0)) * typography.bodyLineAdvance)

        return ZStack(alignment: .topTrailing) {
            ForEach(Array(chunks.enumerated()), id: \.offset) { index, chunk in
                InlineVerticalText(
                    chunk,
                    fontSize: typography.bodyFontSize,
                    weight: .regular
                )
                .frame(width: ScriptPageLayout.bodyColumnWidth, alignment: .topTrailing)
                .offset(x: -CGFloat(index) * typography.bodyLineAdvance)
            }
        }
        .frame(width: width, alignment: .topTrailing)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private static func dialogueChunks(for text: String) -> [String] {
        let characters = Array(text)
        guard !characters.isEmpty else { return [""] }

        var remaining = characters
        var chunks: [String] = []
        while !remaining.isEmpty {
            let count = min(ScriptPageLayout.bodyCharactersPerColumn, remaining.count)
            chunks.append(String(remaining.prefix(count)))
            remaining.removeFirst(count)
        }

        return chunks
    }
}

private struct InlineVerticalText: View {
    var text: String
    var fontSize: CGFloat
    var weight: Font.Weight
    var preservesCharacterWidth: Bool

    init(_ text: String, fontSize: CGFloat, weight: Font.Weight, preservesCharacterWidth: Bool = true) {
        self.text = text
        self.fontSize = fontSize
        self.weight = weight
        self.preservesCharacterWidth = preservesCharacterWidth
    }

    var body: some View {
        let nsWeight: NSFont.Weight = {
            if weight == .bold { return .bold }
            if weight == .semibold { return .semibold }
            if weight == .medium { return .medium }
            return .regular
        }()
        let font = ScriptPageLayout.serifFont(size: fontSize, weight: nsWeight)

        VerticalTextRepresentable(
            text: text,
            font: font,
            horizontalInset: nil,
            verticalInset: 0
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}

private struct VerticalText: View {
    var text: String
    var font: NSFont
    var horizontalInset: CGFloat?
    var verticalInset: CGFloat

    init(_ text: String, font: NSFont, horizontalInset: CGFloat? = nil, verticalInset: CGFloat = 0) {
        self.text = text
        self.font = font
        self.horizontalInset = horizontalInset
        self.verticalInset = verticalInset
    }

    var body: some View {
        VerticalTextRepresentable(text: text, font: font, horizontalInset: horizontalInset, verticalInset: verticalInset)
    }
}

private struct VerticalTextRepresentable: NSViewRepresentable {
    var text: String
    var font: NSFont
    var horizontalInset: CGFloat?
    var verticalInset: CGFloat

    func makeNSView(context: Context) -> NativeVerticalTextView {
        NativeVerticalTextView()
    }

    func updateNSView(_ nsView: NativeVerticalTextView, context: Context) {
        nsView.text = text
        nsView.font = font
        nsView.horizontalInset = horizontalInset
        nsView.verticalInset = verticalInset
    }
}

private final class NativeVerticalTextView: NSView {
    var text: String = "" {
        didSet { needsDisplay = true }
    }

    var font: NSFont = .systemFont(ofSize: 12) {
        didSet { needsDisplay = true }
    }

    var horizontalInset: CGFloat? {
        didSet { needsDisplay = true }
    }

    var verticalInset: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !text.isEmpty else { return }

        let displayText = Self.verticalPresentationString(for: text)
        let attributedString = NSAttributedString(
            string: displayText,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.black,
                .verticalGlyphForm: true
            ]
        )

        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let path = CGMutablePath()
        let resolvedHorizontalInset = horizontalInset ?? max((bounds.width - font.pointSize) / 2, 0)
        path.addRect(bounds.insetBy(dx: resolvedHorizontalInset, dy: verticalInset))
        let frameAttributes = [
            kCTFrameProgressionAttributeName: CTFrameProgression.rightToLeft.rawValue
        ] as CFDictionary

        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: attributedString.length), path, frameAttributes)

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        CTFrameDraw(frame, context)
        context.restoreGState()
    }

    private static func verticalPresentationString(for text: String) -> String {
        text.map { character -> String in
            switch character {
            case "0": return "０"
            case "1": return "１"
            case "2": return "２"
            case "3": return "３"
            case "4": return "４"
            case "5": return "５"
            case "6": return "６"
            case "7": return "７"
            case "8": return "８"
            case "9": return "９"
            case " ":
                return "\u{00A0}"
            default:
                return String(character)
            }
        }
        .joined()
    }
}
