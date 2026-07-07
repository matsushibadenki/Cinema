// file:///Users/Shared/Program/Xcode/Cinema/Sources/Cinema/Views/StoryboardCutRow.swift
// StoryboardCutRow.swift
// 絵コンテの各カット情報（カット番号、カット名、画像、セリフ、ト書き等）を表示・編集する行ビュー

import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum StoryboardTextPadding {
    static let horizontal: CGFloat = 5
    static let vertical: CGFloat = 4
}

private enum FocusedEditorTextMetrics {
    static let contentHorizontalPadding: CGFloat = 14
    static let contentVerticalPadding: CGFloat = 12
    static let contentLineSpacing: CGFloat = 3
    static let dialogueHorizontalPadding: CGFloat = 12
    static let dialogueVerticalPadding: CGFloat = 9
    static let dialogueLineSpacing: CGFloat = 2
}

private let storyboardDarkTextColor = NSColor(calibratedWhite: 0.10, alpha: 1.0)

private struct PointingHandCursorModifier: ViewModifier {
    var isEnabled = true

    func body(content: Content) -> some View {
        content.onHover { hovering in
            if hovering && isEnabled {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

private struct CompactStoryboardTextField: NSViewRepresentable {
    @Binding var text: String

    var placeholder = ""
    var font: NSFont
    var alignment: NSTextAlignment
    var textColor: NSColor = .labelColor

    func makeNSView(context: Context) -> CompactNSTextField {
        let field = CompactNSTextField(frame: .zero)
        field.cell = VerticallyCenteredTextFieldCell(textCell: "")
        field.isEditable = true
        field.isSelectable = true
        field.isEnabled = true
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

    func updateNSView(_ nsView: CompactNSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.font = font
        nsView.alignment = alignment
        nsView.textColor = textColor
        nsView.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: textColor.withAlphaComponent(0.42),
                .font: font
            ]
        )
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

private final class CompactNSTextField: NSTextField {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}

private final class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        centeredRect(for: super.drawingRect(forBounds: rect))
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: centeredRect(for: rect), in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: centeredRect(for: rect), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }

    private func centeredRect(for rect: NSRect) -> NSRect {
        let titleSize = cellSize(forBounds: rect)
        let heightDelta = rect.height - titleSize.height
        guard heightDelta > 0 else { return rect }
        return NSRect(
            x: rect.origin.x,
            y: rect.origin.y + floor(heightDelta / 2),
            width: rect.width,
            height: titleSize.height
        )
    }
}

private struct StoryboardProgressIndicator: NSViewRepresentable {
    func makeNSView(context: Context) -> CompactProgressIndicator {
        let indicator = CompactProgressIndicator(frame: .zero)
        indicator.style = .spinning
        indicator.controlSize = .large
        indicator.isIndeterminate = true
        indicator.startAnimation(nil)
        return indicator
    }

    func updateNSView(_ nsView: CompactProgressIndicator, context: Context) {
        nsView.startAnimation(nil)
    }
}

private final class CompactProgressIndicator: NSProgressIndicator {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}

private struct StoryboardTextView: NSViewRepresentable {
    @Binding var text: String

    var fontSize: CGFloat
    var horizontalInset: CGFloat = StoryboardTextPadding.horizontal
    var verticalInset: CGFloat = StoryboardTextPadding.vertical
    var lineSpacing: CGFloat = 0

    var alignment: NSTextAlignment = .left
    var textColor: NSColor = .labelColor

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.drawsBackground = false
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: horizontalInset, height: verticalInset)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.delegate = context.coordinator

        scrollView.documentView = textView
        context.coordinator.textView = textView
        applyStyle(to: textView)
        textView.string = text
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        if textView.string != text {
            textView.string = text
        }
        applyStyle(to: textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    private func applyStyle(to textView: NSTextView) {
        let font = NSFont.systemFont(ofSize: fontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.alignment = alignment
        textView.font = font
        textView.textColor = textColor
        textView.alignment = alignment
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        textView.textContainerInset = NSSize(width: horizontalInset, height: verticalInset)
        textView.textContainer?.lineFragmentPadding = 0
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        weak var textView: NSTextView?

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            TextSelectionStyleApplicator.activeTextView = textView
            text = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            TextSelectionStyleApplicator.activeTextView = textView
        }

        func textDidBeginEditing(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            TextSelectionStyleApplicator.activeTextView = textView
        }
    }
}

private struct StoryboardStaticTextView: NSViewRepresentable {
    var text: String
    var fontSize: CGFloat
    var horizontalInset: CGFloat = StoryboardTextPadding.horizontal
    var verticalInset: CGFloat = StoryboardTextPadding.vertical
    var lineSpacing: CGFloat = 0
    var alignment: NSTextAlignment = .left
    var textColor: NSColor = .labelColor

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isEditable = false
        textView.isSelectable = false
        textView.textContainerInset = NSSize(width: horizontalInset, height: verticalInset)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        applyStyle(to: textView)
        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        applyStyle(to: nsView)
    }

    private func applyStyle(to textView: NSTextView) {
        let font = NSFont.systemFont(ofSize: fontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.alignment = alignment
        textView.string = text
        textView.font = font
        textView.textColor = textColor
        textView.alignment = alignment
        textView.textStorage?.addAttributes(
            [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ],
            range: NSRange(location: 0, length: textView.string.utf16.count)
        )
        textView.textContainerInset = NSSize(width: horizontalInset, height: verticalInset)
        textView.textContainer?.lineFragmentPadding = 0
    }
}

private extension View {
    func pointingHandCursor(isEnabled: Bool = true) -> some View {
        modifier(PointingHandCursorModifier(isEnabled: isEnabled))
    }
}

private enum StoryboardTextFitter {
    static func fontSize(
        for text: String,
        width: CGFloat,
        height: CGFloat,
        base: CGFloat,
        minimum: CGFloat,
        lineSpacing: CGFloat = 0
    ) -> CGFloat {
        let clampedWidth = max(width, 1)
        let clampedHeight = max(height, 1)
        var size = base

        while size > minimum {
            if estimatedHeight(for: text, width: clampedWidth, fontSize: size, lineSpacing: lineSpacing) <= clampedHeight {
                return size
            }
            size -= 0.5
        }

        return minimum
    }

    static func dialogueFontSize(
        for lines: [DialogueLine],
        speakerWidth: CGFloat,
        dialogueWidth: CGFloat,
        height: CGFloat,
        base: CGFloat,
        minimum: CGFloat,
        minimumRowHeight: CGFloat,
        horizontalInset: CGFloat = StoryboardTextPadding.horizontal,
        verticalInset: CGFloat = StoryboardTextPadding.vertical,
        lineSpacing: CGFloat = 0
    ) -> CGFloat {
        let availableHeight = max(height, 1)
        var size = base

        while size > minimum {
            if estimatedDialogueHeight(
                for: lines,
                speakerWidth: speakerWidth,
                dialogueWidth: dialogueWidth,
                fontSize: size,
                minimumRowHeight: minimumRowHeight,
                horizontalInset: horizontalInset,
                verticalInset: verticalInset,
                lineSpacing: lineSpacing
            ) <= availableHeight {
                return size
            }
            size -= 0.5
        }

        return minimum
    }

    static func estimatedDialogueHeight(
        for lines: [DialogueLine],
        speakerWidth: CGFloat,
        dialogueWidth: CGFloat,
        fontSize: CGFloat,
        minimumRowHeight: CGFloat,
        horizontalInset: CGFloat = StoryboardTextPadding.horizontal,
        verticalInset: CGFloat = StoryboardTextPadding.vertical,
        lineSpacing: CGFloat = 0
    ) -> CGFloat {
        let activeLines = lines.isEmpty ? [DialogueLine()] : lines
        return activeLines.reduce(CGFloat.zero) { partial, line in
            let speakerHeight = estimatedHeight(
                for: line.speaker,
                width: speakerWidth - (horizontalInset * 2),
                fontSize: fontSize,
                lineSpacing: lineSpacing
            )
            let dialogueHeight = estimatedHeight(
                for: line.dialogue,
                width: dialogueWidth - (horizontalInset * 2),
                fontSize: fontSize,
                lineSpacing: lineSpacing
            )
            let rowHeight = max(speakerHeight, dialogueHeight) + (verticalInset * 2)
            return partial + max(minimumRowHeight, rowHeight)
        }
    }

    static func estimatedHeight(for text: String, width: CGFloat, fontSize: CGFloat, lineSpacing: CGFloat = 0) -> CGFloat {
        let paragraphs = text.isEmpty ? [""] : text.components(separatedBy: .newlines)
        let lineCount = paragraphs.reduce(0) { partial, paragraph in
            partial + max(1, estimatedWrappedLineCount(for: paragraph, width: width, fontSize: fontSize))
        }
        let lineHeight = ceil(fontSize * 1.25)
        return CGFloat(lineCount) * lineHeight + CGFloat(max(lineCount - 1, 0)) * lineSpacing
    }

    private static func estimatedWrappedLineCount(for text: String, width: CGFloat, fontSize: CGFloat) -> Int {
        let capacity = max(width / max(fontSize, 1), 1)
        let units = text.reduce(CGFloat.zero) { partial, character in
            partial + characterWidthUnit(character)
        }
        return max(1, Int(ceil(units / capacity)))
    }

    private static func characterWidthUnit(_ character: Character) -> CGFloat {
        guard let scalar = character.unicodeScalars.first else { return 1 }
        if scalar.isASCII {
            return scalar.properties.isWhitespace ? 0.35 : 0.58
        }
        return 1
    }
}

struct StoryboardCutRow: View {
    @Binding var cut: StoryboardCut
    @Environment(\.isPrintingStoryboard) private var isPrintingStoryboard
    @State private var showsPromptEditor = false
    @State private var showsReferencePicker = false

    var imageData: Data?
    var image: NSImage?
    var referenceImages: [ReferenceImage]
    var screenAspectRatio: CGFloat
    var showsGeneratePlaceholder: Bool
    var showsCutActionControls: Bool
    var screenBackgroundBrightness: CGFloat
    var imageColumnWidth: CGFloat
    var contentColumnWidth: CGFloat
    var actionColumnWidth: CGFloat
    var textBaseFontSize: CGFloat
    var isGenerating: Bool
    var generate: () -> Void
    var importImage: () -> Void
    var deleteImageData: (String) -> Void
    var addAfter: () -> Void
    var delete: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                cutColumn
                    .frame(width: StoryboardPageLayout.sideColumnWidth, height: StoryboardPageLayout.rowHeight)

                Rectangle()
                    .fill(CinemaDesign.storyboardPaperAccent)
                    .frame(width: StoryboardPageLayout.cutImageGap, height: StoryboardPageLayout.rowHeight)

                StoryboardScreenFrame(
                    imageData: imageData,
                    image: image,
                    aspectRatio: screenAspectRatio,
                    showsGeneratePlaceholder: showsGeneratePlaceholder,
                    backgroundBrightness: screenBackgroundBrightness,
                    isGenerating: isGenerating,
                    cutNumber: cut.cutNumber,
                    importImage: importImage,
                    deleteImage: deleteImage
                )
                .frame(width: imageColumnWidth, height: StoryboardPageLayout.rowHeight)
                .background(CinemaDesign.storyboardScreenColumn)

                contentColumn
                    .background(CinemaDesign.storyboardPaper)
                    .frame(width: contentColumnWidth, height: StoryboardPageLayout.rowHeight)

                actionColumn
                    .background(CinemaDesign.storyboardDialogueColumn)
                    .frame(width: actionColumnWidth, height: StoryboardPageLayout.rowHeight)

                CompactStoryboardTextField(
                    text: $cut.duration,
                    font: .systemFont(ofSize: 10),
                    alignment: .center,
                    textColor: storyboardDarkTextColor
                )
                    .frame(width: StoryboardPageLayout.sideColumnWidth, height: StoryboardPageLayout.rowHeight)
            }

            if showsCutActionControls {
                cutActionToolbar
                    .padding(.vertical, 8)
                    .frame(width: 20, height: StoryboardPageLayout.rowHeight - 18)
                    .background(CinemaDesign.storyboardToolChrome)
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.black.opacity(0.18), lineWidth: 0.6)
                    }
                    .offset(x: -28)
            }
        }
        .frame(height: StoryboardPageLayout.rowHeight)
    }

    private var cutColumn: some View {
        VStack(spacing: 3) {
            CompactStoryboardTextField(
                text: cutNumberText,
                font: .systemFont(ofSize: 12),
                alignment: .center,
                textColor: storyboardDarkTextColor
            )
            .frame(height: 18)
            .frame(maxWidth: .infinity, alignment: .center)

            CompactStoryboardTextField(
                text: $cut.cutName,
                placeholder: "名前",
                font: .monospacedSystemFont(ofSize: 7, weight: .regular),
                alignment: .center,
                textColor: storyboardDarkTextColor
            )
            .frame(height: 16)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 2)
        .background(CinemaDesign.storyboardPaper)
    }

    private var cutActionToolbar: some View {
        VStack(spacing: 5) {
            iconButton(
                systemName: "sparkles",
                help: "AIで画面を生成",
                action: generate
            )
            .pointingHandCursor(isEnabled: !isGenerating)
            .disabled(isGenerating)

            Button {
                showsReferencePicker.toggle()
            } label: {
                Image(systemName: cut.referenceImageIDs.isEmpty ? "photo.on.rectangle" : "photo.on.rectangle.angled")
                    .foregroundStyle(CinemaDesign.storyboardToolIcon)
            }
            .buttonStyle(.borderless)
            .controlSize(.mini)
            .font(.system(size: 9))
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
            .pointingHandCursor()
            .help("このカットのリファレンスを選択")
            .popover(isPresented: $showsReferencePicker, arrowEdge: .trailing) {
                CutReferencePickerPopover(
                    selectedIDs: $cut.referenceImageIDs,
                    references: referenceImages
                )
            }

            Button {
                showsPromptEditor.toggle()
            } label: {
                Image(systemName: "text.badge.plus")
                    .foregroundStyle(CinemaDesign.storyboardToolIcon)
            }
            .buttonStyle(.borderless)
            .controlSize(.mini)
            .font(.system(size: 9))
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
            .pointingHandCursor()
            .help("追加プロンプト")
            .popover(isPresented: $showsPromptEditor, arrowEdge: .trailing) {
                PromptEditorPopover(
                    prompt: $cut.generationPrompt,
                    shotSettings: $cut.aiShotSettings
                )
            }

            iconButton(
                systemName: "plus.square.on.square",
                help: "この後ろにカットを追加",
                action: addAfter
            )

            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
                    .foregroundStyle(CinemaDesign.storyboardToolIcon)
            }
            .buttonStyle(.borderless)
            .controlSize(.mini)
            .font(.system(size: 9))
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
            .pointingHandCursor()
            .help("カットを削除")
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private func iconButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(CinemaDesign.storyboardToolIcon)
        }
        .buttonStyle(.borderless)
        .controlSize(.mini)
        .font(.system(size: 9))
        .frame(width: 16, height: 16)
        .contentShape(Rectangle())
        .pointingHandCursor()
        .help(help)
    }

    private func deleteImage() {
        guard let imageFileName = cut.imageFileName else { return }
        cut.imageFileName = nil
        deleteImageData(imageFileName)
    }

    private var contentColumn: some View {
        AutoSizingStoryboardTextEditor(
            text: $cut.situation,
            placeholder: "",
            baseFontSize: textBaseFontSize,
            minimumFontSize: 8,
            isPrinting: isPrintingStoryboard,
            textColor: storyboardDarkTextColor
        )
        .overlay {
            Rectangle()
                .stroke(Color.black.opacity(0.16), lineWidth: 0.8)
        }
    }

    private var actionColumn: some View {
        DialogueSheetEditor(
            lines: $cut.dialogueLines,
            speakerRatio: $cut.dialogueSpeakerRatio,
            baseFontSize: textBaseFontSize,
            showsLineControls: showsCutActionControls,
            isPrinting: isPrintingStoryboard,
            usesClassicStoryboardChrome: true,
            textColor: storyboardDarkTextColor
        )
        .overlay {
            Rectangle()
                .stroke(Color.black.opacity(0.16), lineWidth: 0.8)
        }
    }

    private var screenBackgroundColor: Color {
        Color(white: min(max(screenBackgroundBrightness, 0), 1))
    }

    private var cutNumberText: Binding<String> {
        Binding {
            String(cut.cutNumber)
        } set: { newValue in
            let digits = newValue.filter(\.isNumber)
            if let number = Int(digits) {
                cut.cutNumber = number
            }
        }
    }

}

struct FocusedStoryboardCutScroller: View {
    @Binding var cuts: [StoryboardCut]
    @Binding var currentIndex: Int
    @Binding var scrollPosition: Int?

    var generatedVideoColumns: [GeneratedVideoStripColumn]
    var selectedVideoSceneTitle: String?
    var referenceImages: [ReferenceImage]
    var imageData: [String: Data]
    var screenAspectRatio: CGFloat
    var showsGeneratePlaceholder: Bool
    var screenBackgroundBrightness: CGFloat
    var textBaseFontSize: CGFloat
    var generatingCutID: StoryboardCut.ID?
    var deleteImageData: (String) -> Void
    var generate: (StoryboardCut.ID) -> Void
    var importImage: (StoryboardCut.ID) -> Void
    var addAfter: (StoryboardCut.ID) -> Void
    var delete: (StoryboardCut.ID) -> Void
    var appLanguage: String

    var body: some View {
        GeometryReader { proxy in
            let isCompactWidth = proxy.size.width < 1380
            let stripSpacing = isCompactWidth ? 6.0 : 8.0
            let stripHeight = isCompactWidth ? 134.0 : 148.0
            let currentCutID = cuts.indices.contains(currentIndex) ? cuts[currentIndex].id : nil
            let editorHeight = max(proxy.size.height - stripHeight - stripSpacing, 700)

            VStack(spacing: 0) {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array($cuts.enumerated()), id: \.element.id) { index, $cut in
                            FocusedStoryboardCutView(
                                cut: $cut,
                                imageData: cut.imageFileName.flatMap { imageData[$0] },
                                image: ImageHelpers.nsImage(from: cut.imageFileName.flatMap { imageData[$0] }),
                                referenceImages: referenceImages,
                                screenAspectRatio: screenAspectRatio,
                                showsGeneratePlaceholder: showsGeneratePlaceholder,
                                screenBackgroundBrightness: screenBackgroundBrightness,
                                textBaseFontSize: textBaseFontSize,
                                isGenerating: generatingCutID == cut.id,
                                deleteImageData: deleteImageData,
                                generate: { generate(cut.id) },
                                importImage: { importImage(cut.id) },
                                addAfter: { addAfter(cut.id) },
                                delete: { delete(cut.id) },
                                appLanguage: appLanguage
                            )
                            .frame(height: editorHeight)
                            .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.never)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $scrollPosition)
                .background(CinemaDesign.canvasBackground)

                GeneratedVideoFilmstripView(
                    sceneTitle: selectedVideoSceneTitle,
                    columns: generatedVideoColumns,
                    currentCutID: currentCutID,
                    isCompact: isCompactWidth
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: stripHeight)
                .padding(.top, stripSpacing)
            }
            .onAppear {
                scrollPosition = min(max(currentIndex, 0), max(cuts.count - 1, 0))
            }
            .onChange(of: scrollPosition) { _, newValue in
                guard let newValue, cuts.indices.contains(newValue), currentIndex != newValue else { return }
                currentIndex = newValue
            }
        }
    }
}

private struct FocusedStoryboardCutView: View {
    private enum InspectorTab: String, CaseIterable, Identifiable {
        case contentDialogue
        case additionalPrompt

        var id: String { rawValue }
    }

    @Binding var cut: StoryboardCut
    @AppStorage("focusedCutInspectorWidthRatio") private var inspectorWidthRatio = 0.38
    @State private var selectedTab: InspectorTab = .contentDialogue
    @State private var inspectorDragStartRatio: Double?

    var imageData: Data?
    var image: NSImage?
    var referenceImages: [ReferenceImage]
    var screenAspectRatio: CGFloat
    var showsGeneratePlaceholder: Bool
    var screenBackgroundBrightness: CGFloat
    var textBaseFontSize: CGFloat
    var isGenerating: Bool
    var deleteImageData: (String) -> Void
    var generate: () -> Void
    var importImage: () -> Void
    var addAfter: () -> Void
    var delete: () -> Void
    var appLanguage: String

    private let headerHorizontalPadding: CGFloat = 18
    private let contentHorizontalPadding: CGFloat = 18
    private let contentSpacing: CGFloat = 14
    private let canvasInset: CGFloat = 18
    var body: some View {
        GeometryReader { proxy in
            let isCompactWidth = proxy.size.width < 1380
            let isVeryCompactWidth = proxy.size.width < 1160
            let innerInset = isCompactWidth ? 10.0 : 12.0
            let sectionSpacing = isCompactWidth ? 6.0 : 8.0
            let contentBottomInset = isCompactWidth ? 10.0 : 12.0
            let contentColumnWidth = max(proxy.size.width - (innerInset * 2), 320)
            let contentHeight = max(proxy.size.height - 108 - contentBottomInset, isCompactWidth ? 320 : 420)
            let inspectorWidth = clampedInspectorWidth(
                totalWidth: contentColumnWidth,
                ratio: inspectorWidthRatio
            )
            let handleWidth: CGFloat = 2
            let availableContentWidth = max(
                contentColumnWidth,
                320
            )
            let imageWidth = max(
                availableContentWidth - inspectorWidth - handleWidth - (sectionSpacing * 2),
                280
            )

            ZStack {
                CinemaDesign.mainBlockSurface

                VStack(spacing: 0) {
                    headerPanel(compact: isCompactWidth)
                        .frame(width: contentColumnWidth, alignment: .leading)
                        .padding(.bottom, sectionSpacing)

                    Group {
                        if isVeryCompactWidth {
                            VStack(spacing: sectionSpacing) {
                                previewPanel
                                    .frame(maxWidth: .infinity)
                                    .frame(height: max(contentHeight * 0.48, 240))

                                inspectorPanel(contentHeight: max(contentHeight * 0.52, 260))
                                    .frame(maxWidth: .infinity)
                                    .frame(maxHeight: .infinity)
                            }
                        } else {
                            HStack(spacing: sectionSpacing) {
                                previewPanel
                                    .frame(width: imageWidth)
                                    .frame(maxHeight: .infinity)

                                FocusedInspectorSplitHandle()
                                    .frame(width: handleWidth)
                                    .frame(maxHeight: .infinity)
                                    .gesture(inspectorWidthGesture(totalWidth: contentColumnWidth))

                                inspectorPanel(contentHeight: contentHeight)
                                    .frame(width: inspectorWidth)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                    }
                    .frame(width: contentColumnWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, contentBottomInset)
                }
                .padding(innerInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CinemaDesign.canvasBackground)
        }
    }

    @ViewBuilder
    private func contentDialogueTab(contentHeight: CGFloat) -> some View {
        VStack(spacing: 18) {
            panel(title: t(.content)) {
                AutoSizingStoryboardTextEditor(
                    text: $cut.situation,
                    placeholder: "",
                    baseFontSize: max(textBaseFontSize + 5, 16),
                    minimumFontSize: 12,
                    isPrinting: false,
                    horizontalInset: FocusedEditorTextMetrics.contentHorizontalPadding,
                    verticalInset: FocusedEditorTextMetrics.contentVerticalPadding,
                    lineSpacing: FocusedEditorTextMetrics.contentLineSpacing
                )
                .background(CinemaDesign.editorSurface)
            }
            .frame(maxHeight: max(contentHeight * 0.38, 180))

            panel(title: t(.dialogue)) {
                DialogueSheetEditor(
                    lines: $cut.dialogueLines,
                    speakerRatio: $cut.dialogueSpeakerRatio,
                    baseFontSize: max(textBaseFontSize + 4, 15),
                    showsLineControls: true,
                    isPrinting: false,
                    horizontalInset: FocusedEditorTextMetrics.dialogueHorizontalPadding,
                    verticalInset: FocusedEditorTextMetrics.dialogueVerticalPadding,
                    lineSpacing: FocusedEditorTextMetrics.dialogueLineSpacing
                )
                .background(CinemaDesign.editorSurface)
            }
            .frame(maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func header(compact: Bool) -> some View {
        if compact {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    metaField(text: cutNumberText, placeholder: t(.cut), minWidth: 52, alignment: .center, fontSize: 18)
                    metaField(text: $cut.cutName, placeholder: t(.cutName), minWidth: 140, alignment: .left, fontSize: 16)
                    metaField(text: $cut.duration, placeholder: t(.seconds), minWidth: 68, alignment: .center, fontSize: 14)
                    Spacer(minLength: 8)
                    actionToolbar
                        .fixedSize()
                }

                HStack(spacing: 8) {
                    metaField(text: $cut.subtitle, placeholder: t(.block), minWidth: 120, alignment: .left, fontSize: 13)
                    metaField(text: $cut.scriptHeading, placeholder: t(.sequence), minWidth: 132, alignment: .left, fontSize: 13)
                    metaField(text: $cut.sceneName, placeholder: t(.scene), minWidth: 120, alignment: .left, fontSize: 13)
                }
            }
        } else {
            HStack(spacing: 10) {
                metaField(text: cutNumberText, placeholder: t(.cut), minWidth: 54, alignment: .center, fontSize: 20)
                metaField(text: $cut.cutName, placeholder: t(.cutName), minWidth: 168, alignment: .left, fontSize: 18)
                metaField(text: $cut.subtitle, placeholder: t(.block), minWidth: 132, alignment: .left, fontSize: 14)
                metaField(text: $cut.scriptHeading, placeholder: t(.sequence), minWidth: 148, alignment: .left, fontSize: 14)
                metaField(text: $cut.sceneName, placeholder: t(.scene), minWidth: 132, alignment: .left, fontSize: 14)
                metaField(text: $cut.duration, placeholder: t(.seconds), minWidth: 72, alignment: .center, fontSize: 16)
                Spacer(minLength: 12)
                actionToolbar
                    .fixedSize()
            }
        }
    }

    private func headerPanel(compact: Bool) -> some View {
        header(compact: compact)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, compact ? 10 : 12)
            .padding(.vertical, compact ? 8 : 10)
            .background(
                Rectangle()
                    .fill(CinemaDesign.mainBlockSurface)
            )
            .overlay(
                Rectangle()
                    .stroke(CinemaDesign.strongBorder.opacity(0.9), lineWidth: 0.8)
            )
    }

    private var previewPanel: some View {
        StoryboardScreenFrame(
            imageData: imageData,
            image: image,
            aspectRatio: screenAspectRatio,
            showsGeneratePlaceholder: showsGeneratePlaceholder,
            backgroundBrightness: screenBackgroundBrightness,
            isGenerating: isGenerating,
            cutNumber: cut.cutNumber,
            importImage: importImage,
            deleteImage: deleteImage
        )
        .background(CinemaDesign.mainBlockSurface)
        .clipShape(Rectangle())
        .overlay(
            Rectangle()
                .stroke(CinemaDesign.strongBorder.opacity(0.92), lineWidth: 0.8)
        )
    }

    private func inspectorPanel(contentHeight: CGFloat) -> some View {
        VStack(spacing: 10) {
            Picker("Inspector", selection: $selectedTab) {
                Text(t(.contentAndDialogue)).tag(InspectorTab.contentDialogue)
                Text(t(.additionalPrompt)).tag(InspectorTab.additionalPrompt)
            }
            .pickerStyle(.segmented)

            Group {
                switch selectedTab {
                case .contentDialogue:
                    contentDialogueTab(contentHeight: contentHeight)
                case .additionalPrompt:
                    PromptEditorContent(
                        prompt: $cut.generationPrompt,
                        shotSettings: $cut.aiShotSettings
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(8)
        .background(CinemaDesign.mainBlockSurface)
        .clipShape(Rectangle())
        .overlay {
            Rectangle()
                .stroke(CinemaDesign.strongBorder.opacity(0.92), lineWidth: 0.8)
        }
    }

    private func panel<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CinemaDesign.ink)
            content()
                .clipShape(Rectangle())
                .overlay(
                    Rectangle()
                        .stroke(CinemaDesign.strongBorder.opacity(0.88), lineWidth: 0.8)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func clampedInspectorWidth(totalWidth: CGFloat, ratio: Double) -> CGFloat {
        let width = totalWidth * CGFloat(ratio)
        return min(max(width, 320), max(totalWidth * 0.52, 360))
    }

    private func inspectorWidthGesture(totalWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if inspectorDragStartRatio == nil {
                    inspectorDragStartRatio = inspectorWidthRatio
                }
                let start = inspectorDragStartRatio ?? inspectorWidthRatio
                let nextWidth = clampedInspectorWidth(
                    totalWidth: totalWidth,
                    ratio: start
                ) - value.translation.width
                inspectorWidthRatio = Double(nextWidth / max(totalWidth, 1))
            }
            .onEnded { _ in
                let clamped = clampedInspectorWidth(totalWidth: totalWidth, ratio: inspectorWidthRatio)
                inspectorWidthRatio = Double(clamped / max(totalWidth, 1))
                inspectorDragStartRatio = nil
            }
    }

    private func metaField(
        text: Binding<String>,
        placeholder: String,
        minWidth: CGFloat,
        alignment: NSTextAlignment,
        fontSize: CGFloat
    ) -> some View {
        CompactStoryboardTextField(
            text: text,
            placeholder: placeholder,
            font: .systemFont(ofSize: fontSize, weight: .medium),
            alignment: alignment
        )
        .frame(minWidth: minWidth, maxWidth: .infinity, minHeight: 34, maxHeight: 34)
        .padding(.horizontal, 6)
        .background(CinemaDesign.insetSurface)
        .clipShape(Rectangle())
        .overlay(
            Rectangle()
                .stroke(CinemaDesign.strongBorder.opacity(0.9), lineWidth: 0.8)
        )
    }

    private var actionToolbar: some View {
        HStack(spacing: 6) {
            toolbarButton(systemName: "sparkles", help: "AIで画面を生成", action: generate)
                .disabled(isGenerating)

            toolbarButton(systemName: "plus.square.on.square", help: "この後ろにカットを追加", action: addAfter)
            toolbarButton(systemName: "trash", help: "このカットを削除", action: delete)
        }
        .padding(.trailing, 2)
    }

    private func toolbarButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CinemaDesign.ink)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.borderless)
        .frame(width: 32, height: 32)
        .background(CinemaDesign.editorSurface.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(CinemaDesign.fineBorder.opacity(0.74), lineWidth: 0.5)
        )
        .help(help)
        .pointingHandCursor()
    }

    private func deleteImage() {
        guard let imageFileName = cut.imageFileName else { return }
        cut.imageFileName = nil
        deleteImageData(imageFileName)
    }

    private var cutNumberText: Binding<String> {
        Binding {
            String(cut.cutNumber)
        } set: { newValue in
            let digits = newValue.filter(\.isNumber)
            if let number = Int(digits) {
                cut.cutNumber = number
            }
        }
    }

    private func t(_ key: CinemaTextKey) -> String {
        CinemaStrings.text(key, language: appLanguage)
    }
}

private struct FocusedInspectorSplitHandle: View {
    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .overlay {
                Rectangle()
                    .fill(Color.black.opacity(isHovering ? 0.22 : 0.12))
                    .frame(width: 1)
            }
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
            .help("ドラッグしてプレビューと編集エリアの幅を調整")
    }
}

private struct SplitDragHandle: View {
    @State private var isHovering = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle()
                    .fill(CinemaDesign.storyboardPaper)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: proxy.size.height / 2))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height / 2))
                }
                .stroke(CinemaDesign.storyboardGrid.opacity(0.72), style: StrokeStyle(lineWidth: 0.8, dash: [2, 2]))
            }
        }
        .clipped()
        .contentShape(Rectangle())
        .onHover { hovering in
            guard hovering != isHovering else { return }
            isHovering = hovering
            if hovering {
                NSCursor.resizeUpDown.push()
            } else {
                NSCursor.pop()
            }
        }
        .help("ドラッグして内容とセリフの高さを調整")
    }
}

private struct DialogueSheetEditor: View {
    @Binding var lines: [DialogueLine]
    @Binding var speakerRatio: Double

    var baseFontSize: CGFloat
    var showsLineControls: Bool
    var isPrinting: Bool
    var usesClassicStoryboardChrome = false
    var textColor: NSColor = .labelColor
    var horizontalInset: CGFloat = StoryboardTextPadding.horizontal
    var verticalInset: CGFloat = StoryboardTextPadding.vertical
    var lineSpacing: CGFloat = 0

    private let minimumRowHeight: CGFloat = 18
    private let splitHandleWidth: CGFloat = 3
    private let buttonWidth: CGFloat = 18
    private let minimumSpeakerWidth: CGFloat = 24
    private let minimumDialogueWidth: CGFloat = 26

    private var controlGutterWidth: CGFloat {
        max(buttonWidth + (horizontalInset * 2), buttonWidth + 8)
    }

    private var fontSize: CGFloat {
        isPrinting ? max(baseFontSize - 1, 8) : max(baseFontSize - 1, 13)
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                let minimumEditorWidth = minimumSpeakerWidth + splitHandleWidth + minimumDialogueWidth

                if proxy.size.width >= minimumEditorWidth {
                    let controlLaneWidth = showsLineControls ? controlGutterWidth : 0
                    let editableWidth = max(proxy.size.width - controlLaneWidth, minimumEditorWidth)
                    let speakerWidth = speakerWidth(totalWidth: editableWidth)
                    let dialogueWidth = max(editableWidth - speakerWidth - splitHandleWidth, minimumDialogueWidth)
                    let rowFontSize = isPrinting
                        ? StoryboardTextFitter.dialogueFontSize(
                            for: lines,
                            speakerWidth: speakerWidth,
                            dialogueWidth: dialogueWidth,
                            height: proxy.size.height,
                            base: fontSize,
                            minimum: 5.5,
                            minimumRowHeight: minimumRowHeight,
                            horizontalInset: horizontalInset,
                            verticalInset: verticalInset,
                            lineSpacing: lineSpacing
                        )
                        : fontSize

                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array($lines.enumerated()), id: \.element.id) { index, $line in
                                let rowHeight = dialogueRowHeight(
                                    for: line,
                                    speakerWidth: speakerWidth,
                                    dialogueWidth: dialogueWidth,
                                    fontSize: rowFontSize
                                )
                                DialogueSheetRow(
                                    line: $line,
                                    speakerRatio: $speakerRatio,
                                    fontSize: rowFontSize,
                                    minimumRowHeight: minimumRowHeight,
                                    rowHeight: rowHeight,
                                    speakerWidth: speakerWidth,
                                    dialogueWidth: dialogueWidth,
                                    splitHandleWidth: splitHandleWidth,
                                    buttonWidth: buttonWidth,
                                    controlGutterWidth: controlLaneWidth,
                                    horizontalInset: horizontalInset,
                                    verticalInset: verticalInset,
                                    lineSpacing: lineSpacing,
                                    usesClassicStoryboardChrome: usesClassicStoryboardChrome,
                                    textColor: textColor,
                                    showsLineControls: showsLineControls,
                                    isPrinting: isPrinting,
                                    canDelete: lines.count > 1,
                                    showsAddButton: index == lines.count - 1,
                                    add: addLine,
                                    delete: { deleteLine(id: line.id) }
                                )
                            }
                        }
                        .frame(width: proxy.size.width, alignment: .leading)
                        .frame(minHeight: proxy.size.height, alignment: .top)
                    }
                    .scrollIndicators(.never)
                } else {
                    usesClassicStoryboardChrome ? CinemaDesign.storyboardPaper : CinemaDesign.editorSurface
                }
            }
        }
        .background(usesClassicStoryboardChrome ? CinemaDesign.storyboardPaper : CinemaDesign.editorSurface)
        .onAppear(perform: ensureLine)
    }

    private func ensureLine() {
        if lines.isEmpty {
            lines.append(DialogueLine())
        }
    }

    private func addLine() {
        lines.append(DialogueLine())
    }

    private func deleteLine(id: DialogueLine.ID) {
        guard lines.count > 1 else { return }
        lines.removeAll { $0.id == id }
    }

    private func speakerWidth(totalWidth: CGFloat) -> CGFloat {
        let availableWidth = max(totalWidth - splitHandleWidth, 1)
        let maximumSpeakerWidth = max(minimumSpeakerWidth, availableWidth - minimumDialogueWidth)
        return min(max(availableWidth * CGFloat(clampedSpeakerRatio(speakerRatio)), minimumSpeakerWidth), maximumSpeakerWidth)
    }

    private func dialogueRowHeight(
        for line: DialogueLine,
        speakerWidth: CGFloat,
        dialogueWidth: CGFloat,
        fontSize: CGFloat
    ) -> CGFloat {
        let speakerHeight = StoryboardTextFitter.estimatedHeight(
            for: line.speaker,
            width: speakerWidth - (horizontalInset * 2),
            fontSize: fontSize,
            lineSpacing: lineSpacing
        )
        let dialogueHeight = StoryboardTextFitter.estimatedHeight(
            for: line.dialogue,
            width: dialogueWidth - (horizontalInset * 2),
            fontSize: fontSize,
            lineSpacing: lineSpacing
        )
        let textHeight = max(speakerHeight, dialogueHeight) + (verticalInset * 2)
        return max(minimumRowHeight, ceil(textHeight))
    }

    private func clampedSpeakerRatio(_ ratio: Double) -> Double {
        min(max(ratio, 0.16), 0.55)
    }
}

private struct DialogueSheetRow: View {
    @Binding var line: DialogueLine
    @Binding var speakerRatio: Double
    @State private var speakerDragStartRatio: Double?

    var fontSize: CGFloat
    var minimumRowHeight: CGFloat
    var rowHeight: CGFloat
    var speakerWidth: CGFloat
    var dialogueWidth: CGFloat
    var splitHandleWidth: CGFloat
    var buttonWidth: CGFloat
    var controlGutterWidth: CGFloat
    var horizontalInset: CGFloat
    var verticalInset: CGFloat
    var lineSpacing: CGFloat
    var usesClassicStoryboardChrome: Bool
    var textColor: NSColor
    var showsLineControls: Bool
    var isPrinting: Bool
    var canDelete: Bool
    var showsAddButton: Bool
    var add: () -> Void
    var delete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if showsLineControls {
                controlGutter
            }

            speakerCell

            DialogueColumnSplitHandle()
                .frame(width: splitHandleWidth)
                .frame(height: rowHeight)
                .gesture(splitGesture(totalWidth: speakerWidth + dialogueWidth + splitHandleWidth))

            dialogueCell
        }
        .frame(height: rowHeight, alignment: .topLeading)
        .background {
            if usesClassicStoryboardChrome {
                Rectangle()
                    .fill(CinemaDesign.storyboardPaper)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(CinemaDesign.insetSurface.opacity(0.94))
            }
        }
        .overlay {
            if usesClassicStoryboardChrome {
                Rectangle()
                    .stroke(Color.black.opacity(0.18), lineWidth: 0.8)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(CinemaDesign.strongBorder.opacity(0.75), lineWidth: 0.7)
            }
        }
        .overlay(alignment: .bottom) {
            DialogueSheetRowDivider(usesClassicStoryboardChrome: usesClassicStoryboardChrome)
        }
    }

    @ViewBuilder
    private var controlGutter: some View {
        VStack {
            Button(action: showsAddButton ? add : delete) {
                Image(systemName: showsAddButton ? "plus" : "minus")
                    .foregroundStyle(showsAddButton || canDelete ? CinemaDesign.storyboardToolIcon : CinemaDesign.storyboardToolIcon.opacity(0.45))
            }
            .buttonStyle(.borderless)
            .controlSize(.mini)
            .font(.system(size: 9, weight: .semibold))
            .frame(width: buttonWidth, height: buttonWidth)
            .background {
                RoundedRectangle(cornerRadius: usesClassicStoryboardChrome ? 8 : 6, style: .continuous)
                    .fill(usesClassicStoryboardChrome ? CinemaDesign.storyboardPaperAccent : (showsAddButton ? CinemaDesign.keyColor : CinemaDesign.insetSurface))
            }
            .overlay {
                RoundedRectangle(cornerRadius: usesClassicStoryboardChrome ? 8 : 6, style: .continuous)
                    .stroke(usesClassicStoryboardChrome ? Color.black.opacity(0.18) : (showsAddButton ? CinemaDesign.keyColor.opacity(0.95) : CinemaDesign.strongBorder.opacity(0.9)), lineWidth: 0.7)
            }
            .opacity(showsAddButton || canDelete ? 1.0 : 0.45)
            .pointingHandCursor(isEnabled: showsAddButton || canDelete)
            .disabled(!showsAddButton && !canDelete)
            .help(showsAddButton ? "会話行を追加" : "会話行を削除")

            Spacer(minLength: 0)
        }
        .frame(width: controlGutterWidth, height: rowHeight, alignment: .top)
        .padding(.top, verticalInset)
    }

    @ViewBuilder
    private var speakerCell: some View {
        if isPrinting {
            Text(line.speaker)
                .font(.system(size: fontSize))
                .foregroundStyle(Color(nsColor: textColor))
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .padding(.horizontal, horizontalInset)
                .padding(.vertical, verticalInset)
                .frame(width: speakerWidth, alignment: .topLeading)
                .frame(height: rowHeight, alignment: .topLeading)
        } else {
            StoryboardTextView(
                text: $line.speaker,
                fontSize: fontSize,
                horizontalInset: horizontalInset,
                verticalInset: verticalInset,
                lineSpacing: lineSpacing,
                textColor: textColor
            )
                .frame(width: speakerWidth, alignment: .topLeading)
                .frame(height: rowHeight, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var dialogueCell: some View {
        if isPrinting {
            StoryboardStaticTextView(
                text: line.dialogue,
                fontSize: fontSize,
                horizontalInset: horizontalInset,
                verticalInset: verticalInset,
                lineSpacing: lineSpacing,
                alignment: .justified,
                textColor: textColor
            )
                .frame(width: dialogueWidth, alignment: .topLeading)
                .frame(height: rowHeight, alignment: .topLeading)
        } else {
            StoryboardTextView(
                text: $line.dialogue,
                fontSize: fontSize,
                horizontalInset: horizontalInset,
                verticalInset: verticalInset,
                lineSpacing: lineSpacing,
                alignment: .justified,
                textColor: textColor
            )
                .frame(width: dialogueWidth, alignment: .topLeading)
                .frame(height: rowHeight, alignment: .topLeading)
        }
    }

    private func splitGesture(totalWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if speakerDragStartRatio == nil {
                    speakerDragStartRatio = speakerRatio
                }

                let availableWidth = max(totalWidth - splitHandleWidth, 1)
                let startRatio = speakerDragStartRatio ?? speakerRatio
                speakerRatio = clampedSpeakerRatio(startRatio + Double(value.translation.width / availableWidth))
            }
            .onEnded { _ in
                speakerRatio = clampedSpeakerRatio(speakerRatio)
                speakerDragStartRatio = nil
            }
    }

    private func clampedSpeakerRatio(_ ratio: Double) -> Double {
        min(max(ratio, 0.16), 0.55)
    }
}

private struct DialogueSheetRowDivider: View {
    var usesClassicStoryboardChrome = false

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.25))
                path.addLine(to: CGPoint(x: proxy.size.width, y: 0.25))
            }
            .stroke(
                usesClassicStoryboardChrome ? Color.black.opacity(0.18) : CinemaDesign.strongBorder.opacity(0.7),
                style: StrokeStyle(lineWidth: 0.6, dash: usesClassicStoryboardChrome ? [] : [1.6, 2.4])
            )
        }
        .frame(height: 0.5)
    }
}

private struct DialogueColumnSplitHandle: View {
    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .overlay {
                Rectangle()
                    .fill(Color.black.opacity(isHovering ? 0.38 : 0.24))
                    .frame(width: 1)
            }
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
            .help("ドラッグして名前と会話の幅を調整")
    }
}

private struct StoryboardScreenFrame: View {
    private let horizontalPadding: CGFloat = 5

    var imageData: Data?
    var image: NSImage?
    var aspectRatio: CGFloat
    var showsGeneratePlaceholder: Bool
    var backgroundBrightness: CGFloat
    var isGenerating: Bool
    var cutNumber: Int
    var importImage: () -> Void
    var deleteImage: () -> Void

    @State private var isEnlarged = false

    private var backgroundColor: Color {
        Color(white: min(max(backgroundBrightness, 0), 1))
    }

    var body: some View {
        GeometryReader { proxy in
            let paddedSize = CGSize(
                width: max(proxy.size.width - (horizontalPadding * 2), 1),
                height: proxy.size.height
            )
            let frameSize = fittedSize(in: paddedSize, aspectRatio: aspectRatio)

            ZStack {
                LinearGradient(
                    colors: [
                        backgroundColor,
                        backgroundColor.opacity(0.86)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ZStack {
                    ZStack {
                        if let image {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .onTapGesture(count: 2) {
                                    isEnlarged = true
                                }
                                .pointingHandCursor()
                        } else {
                            Rectangle()
                                .fill(CinemaDesign.storyboardPaper)

                            if showsGeneratePlaceholder {
                                VStack(spacing: 6) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 24))
                                    Text("Generate")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.gray)
                            }
                        }
                    }
                    .frame(width: frameSize.width, height: frameSize.height)
                    .overlay {
                        Rectangle()
                            .stroke(CinemaDesign.storyboardFrameBorder, lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(image == nil ? 0 : 0.14), radius: 5, x: 0, y: 2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        importImage()
                    }
                    .help("クリックして画像を読み込む。ダブルクリックで拡大表示")

                }

                if let imageData {
                    HStack(spacing: 4) {
                        imageCellButton(
                            systemName: "arrow.down",
                            help: "AI生成画像をダウンロード",
                            action: { saveImage(data: imageData) }
                        )

                        imageCellButton(
                            systemName: "trash",
                            help: "画像を削除",
                            action: deleteImage
                        )
                    }
                    .padding(.leading, 6)
                    .padding(.bottom, 5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }

                if isGenerating {
                    StoryboardProgressIndicator()
                        .frame(width: 32, height: 32)
                        .padding(12)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .contextMenu {
                if let imageData {
                    Button("画像をダウンロード...") {
                        saveImage(data: imageData)
                    }
                }
            }
            .sheet(isPresented: $isEnlarged) {
                if let image, let imageData {
                    EnlargedImageView(
                        image: image,
                        cutNumber: cutNumber,
                        onDismiss: { isEnlarged = false },
                        onDownload: { saveImage(data: imageData) }
                    )
                }
            }
        }
    }

    private func saveImage(data: Data) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "cut-\(cutNumber).png"
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                // Settings' aspect ratio is matched and upconverted to 4K height (2160pt)
                let targetHeight: CGFloat = 2160
                let targetWidth = targetHeight * aspectRatio
                let upconvertedData = ImageHelpers.pngDataByResizing(data, width: Int(targetWidth), height: Int(targetHeight))
                try upconvertedData.write(to: url)
            } catch {
                NSSound.beep()
            }
        }
    }

    private func imageCellButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 13, height: 13)
                .background(.regularMaterial)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(CinemaDesign.storyboardFrameBorder, lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .help(help)
    }

    private func fittedSize(in size: CGSize, aspectRatio: CGFloat) -> CGSize {
        let widthBasedHeight = size.width / aspectRatio
        if widthBasedHeight <= size.height {
            return CGSize(width: size.width, height: widthBasedHeight)
        }

        return CGSize(width: size.height * aspectRatio, height: size.height)
    }
}

private struct EnlargedImageView: View {
    var image: NSImage
    var cutNumber: Int
    var onDismiss: () -> Void
    var onDownload: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("カット \(cutNumber) 拡大プレビュー")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ZStack {
                Color.black.opacity(0.03)
                
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(20)
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            }

            Divider()

            HStack(spacing: 12) {
                Button(action: onDownload) {
                    Label("4Kアップコンバート保存", systemImage: "arrow.down.doc.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .pointingHandCursor()

                Button("閉じる", action: onDismiss)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .pointingHandCursor()
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}

struct EmptyCutRow: View {
    var imageColumnWidth: CGFloat
    var contentColumnWidth: CGFloat
    var actionColumnWidth: CGFloat
    var screenBackgroundBrightness: CGFloat

    private var screenBackgroundColor: Color {
        Color(white: min(max(screenBackgroundBrightness, 0), 1))
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Rectangle().fill(CinemaDesign.storyboardPaper).frame(width: StoryboardPageLayout.sideColumnWidth, height: StoryboardPageLayout.rowHeight)
                Rectangle().fill(CinemaDesign.storyboardPaperAccent).frame(width: StoryboardPageLayout.cutImageGap, height: StoryboardPageLayout.rowHeight)
                Rectangle().fill(screenBackgroundColor).frame(width: imageColumnWidth, height: StoryboardPageLayout.rowHeight)
                Rectangle().fill(CinemaDesign.storyboardPaper).frame(width: contentColumnWidth, height: StoryboardPageLayout.rowHeight)
                Rectangle().fill(CinemaDesign.storyboardPaper).frame(width: actionColumnWidth, height: StoryboardPageLayout.rowHeight)
                Rectangle().fill(CinemaDesign.storyboardPaper).frame(width: StoryboardPageLayout.sideColumnWidth, height: StoryboardPageLayout.rowHeight)
            }

        }
        .frame(height: StoryboardPageLayout.rowHeight)
    }
}

private struct PromptEditorPopover: View {
    @Binding var prompt: String
    @Binding var shotSettings: AIShotSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("追加プロンプト")
                    .font(.headline)

                Spacer()
            }

            PromptEditorContent(prompt: $prompt, shotSettings: $shotSettings)
            .frame(width: 500, height: 430)
        }
        .padding(12)
    }
}

private struct PromptEditorContent: View {
    @Binding var prompt: String
    @Binding var shotSettings: AIShotSettings

    private let template = """
・被写体（Subject）
「誰が、何が映っているのかを詳細に記述します。」
例：「30代の女性」「アンティークの懐中時計」「サイバーパンク風のロボット」

・アクション・動き（Action / Motion）
「動画ならではの「どんな動きをしているか」を指定します。」
例：「笑顔でコーヒーを飲んでいる」「ゆっくりと歯車が回っている」「雨の中を力強く走っている」

・カメラワーク・アングル（Camera Work）
「映像をどのように撮影しているかを指示すると、プロっぽさが出ます。」
例：「被写体に徐々に近づくズームイン」「横から追いかけるトラッキングショット」「真上からのドローン視点」「クローズアップ」

・環境・背景・照明（Environment & Lighting）
「場所、時間帯、光の当たり方を指定して、映像の雰囲気を決定づけます。」
例：「夕暮れ時の誰もいないビーチ」「ネオンが光る夜の路地裏」「窓から差し込む柔らかな自然光」

・スタイル・質感（Style）
「映像のテイストを指定します。」
例：「実写映画のようなシネマティックな映像」「水彩画アニメーション」「8mmフィルムのようなレトロ調」「3D CG」

・追加プロンプト
"""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Text("ショット設定")
                        .font(.headline)
                    Spacer()
                    Button("テンプレート") {
                        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            prompt = template
                        } else {
                            prompt += "\n\n" + template
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .fixedSize()
                }

                VStack(alignment: .leading, spacing: 10) {
                    shotField("ショットサイズ", text: $shotSettings.shotSize, prompt: "例: クローズアップ、ミディアム、ワイド")
                    shotField("カメラアングル", text: $shotSettings.cameraAngle, prompt: "例: 目線の高さ、ローアングル")
                    shotField("レンズ", text: $shotSettings.lens, prompt: "例: 50mm、広角、浅い被写界深度")
                    shotField("カメラ移動", text: $shotSettings.cameraMovement, prompt: "例: ゆっくりドリーイン")
                    shotField("被写体の動き", text: $shotSettings.subjectMovement, prompt: "例: 画面左から右へ歩く")
                    shotField("開始状態", text: $shotSettings.startState, prompt: "人物位置、視線、姿勢、小道具")
                    shotField("終了状態", text: $shotSettings.endState, prompt: "次のカットへ渡す状態")
                    shotField("次への接続", text: $shotSettings.transition, prompt: "例: 動作つなぎ、カット、ディゾルブ")
                    shotField("音・環境音", text: $shotSettings.soundDirection, prompt: "例: 雨音、遠くの電車")
                    shotField("避ける要素", text: $shotSettings.negativePrompt, prompt: "例: 顔の変化、余分な人物、文字")

                    HStack {
                        Text("連続性")
                            .frame(width: 92, alignment: .leading)
                        Slider(value: $shotSettings.continuityStrength, in: 0...1)
                        Text("\(Int((shotSettings.continuityStrength * 100).rounded()))%")
                            .monospacedDigit()
                            .frame(width: 42, alignment: .trailing)
                    }

                    HStack {
                        Text("Seed")
                            .frame(width: 92, alignment: .leading)
                        TextField(
                            "任意",
                            value: $shotSettings.seed,
                            format: .number
                        )
                        .textFieldStyle(.roundedBorder)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("自由記述")
                        .font(.headline)
                    TextEditor(text: $prompt)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(Color(nsColor: .textBackgroundColor))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.8)
                        }
                        .frame(minHeight: 220)
                }
            }
            .padding(8)
        }
    }

    private func shotField(_ title: String, text: Binding<String>, prompt: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .frame(width: 92, alignment: .leading)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

private struct CutReferencePickerPopover: View {
    @Binding var selectedIDs: [ReferenceImage.ID]
    var references: [ReferenceImage]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("このカットのリファレンス")
                .font(.headline)

            if references.isEmpty {
                Text("右側のリファレンス欄で写真を追加してください。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 260, alignment: .leading)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(references) { reference in
                            Toggle(isOn: binding(for: reference.id)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(reference.name.isEmpty ? "名称なし" : reference.name)
                                        .lineLimit(1)
                                    Text(reference.imageFileName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(width: 300, height: min(CGFloat(references.count) * 34 + 12, 240))

                HStack {
                    Button("すべて選択") {
                        selectedIDs = references.map(\.id)
                    }

                    Button("解除") {
                        selectedIDs.removeAll()
                    }

                    Spacer()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
    }

    private func binding(for id: ReferenceImage.ID) -> Binding<Bool> {
        Binding {
            selectedIDs.contains(id)
        } set: { isSelected in
            if isSelected {
                if !selectedIDs.contains(id) {
                    selectedIDs.append(id)
                }
            } else {
                selectedIDs.removeAll { $0 == id }
            }
        }
    }
}

private struct AutoSizingStoryboardTextEditor: View {
    @Binding var text: String
    var placeholder: String
    var baseFontSize: CGFloat
    var minimumFontSize: CGFloat
    var isPrinting: Bool
    var textColor: NSColor = .labelColor
    var horizontalInset: CGFloat = StoryboardTextPadding.horizontal
    var verticalInset: CGFloat = StoryboardTextPadding.vertical
    var lineSpacing: CGFloat = 0

    private var fontSize: CGFloat {
        let lines = max(text.components(separatedBy: .newlines).count, 1)
        let count = text.count

        switch (count, lines) {
        case let (count, lines) where count > 180 || lines > 8:
            return minimumFontSize
        case let (count, lines) where count > 120 || lines > 6:
            return max(minimumFontSize, baseFontSize - 2.5)
        case let (count, lines) where count > 80 || lines > 4:
            return max(minimumFontSize, baseFontSize - 1.5)
        default:
            return baseFontSize
        }
    }

    private var editingLineSpacing: CGFloat {
        lineSpacing > 0 ? lineSpacing : (fontSize <= 8 ? 0 : 1)
    }

    var body: some View {
        GeometryReader { proxy in
            if isPrinting {
                let printFontSize = StoryboardTextFitter.fontSize(
                    for: text,
                    width: proxy.size.width - (horizontalInset * 2),
                    height: proxy.size.height - (verticalInset * 2),
                    base: fontSize,
                    minimum: 5.5,
                    lineSpacing: editingLineSpacing
                )

                StoryboardStaticTextView(
                    text: text,
                    fontSize: printFontSize,
                    horizontalInset: horizontalInset,
                    verticalInset: verticalInset,
                    lineSpacing: editingLineSpacing,
                    alignment: .justified,
                    textColor: textColor
                )
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            } else {
                StoryboardTextView(
                    text: $text,
                    fontSize: fontSize,
                    horizontalInset: horizontalInset,
                    verticalInset: verticalInset,
                    lineSpacing: editingLineSpacing,
                    alignment: .justified,
                    textColor: textColor
                )
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(placeholder)
                                .font(.system(size: 11))
                                .foregroundStyle(Color(nsColor: textColor).opacity(0.42))
                                .padding(.leading, horizontalInset)
                                .padding(.top, verticalInset)
                        }
                    }
            }
        }
    }
}
