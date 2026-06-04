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

    func makeNSView(context: Context) -> CompactNSTextField {
        let field = CompactNSTextField(frame: .zero)
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
        nsView.placeholderString = placeholder
        nsView.font = font
        nsView.alignment = alignment
        nsView.textColor = .black
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
        textView.textColor = .black
        textView.alignment = alignment
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: NSColor.black,
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
        textView.textColor = .black
        textView.alignment = alignment
        textView.textStorage?.addAttributes(
            [
                .font: font,
                .foregroundColor: NSColor.black,
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
        minimumRowHeight: CGFloat
    ) -> CGFloat {
        let availableHeight = max(height, 1)
        var size = base

        while size > minimum {
            if estimatedDialogueHeight(
                for: lines,
                speakerWidth: speakerWidth,
                dialogueWidth: dialogueWidth,
                fontSize: size,
                minimumRowHeight: minimumRowHeight
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
        minimumRowHeight: CGFloat
    ) -> CGFloat {
        let activeLines = lines.isEmpty ? [DialogueLine()] : lines
        return activeLines.reduce(CGFloat.zero) { partial, line in
            let speakerHeight = estimatedHeight(
                for: line.speaker,
                width: speakerWidth - (StoryboardTextPadding.horizontal * 2),
                fontSize: fontSize
            )
            let dialogueHeight = estimatedHeight(
                for: line.dialogue,
                width: dialogueWidth - (StoryboardTextPadding.horizontal * 2),
                fontSize: fontSize
            )
            let rowHeight = max(speakerHeight, dialogueHeight) + (StoryboardTextPadding.vertical * 2)
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
                    .fill(Color(red: 0.98, green: 0.975, blue: 0.955))
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

                contentColumn
                    .background(Color.white)
                    .frame(width: contentColumnWidth, height: StoryboardPageLayout.rowHeight)

                actionColumn
                    .background(Color.white)
                    .frame(width: actionColumnWidth, height: StoryboardPageLayout.rowHeight)

                CompactStoryboardTextField(
                    text: $cut.duration,
                    font: .systemFont(ofSize: 10),
                    alignment: .center
                )
                    .frame(width: StoryboardPageLayout.sideColumnWidth, height: StoryboardPageLayout.rowHeight)
            }

            if showsCutActionControls {
                cutActionToolbar
                    .padding(.vertical, 8)
                    .frame(width: 20, height: StoryboardPageLayout.rowHeight - 18)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(CinemaDesign.fineBorder, lineWidth: 0.6)
                    }
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
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
                alignment: .center
            )
            .frame(height: 18)
            .frame(maxWidth: .infinity, alignment: .center)

            CompactStoryboardTextField(
                text: $cut.cutName,
                placeholder: "名前",
                font: .systemFont(ofSize: 8),
                alignment: .center
            )
            .frame(height: 14)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 2)
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
            }
            .buttonStyle(.borderless)
            .controlSize(.mini)
            .font(.system(size: 9))
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
            .pointingHandCursor()
            .help("追加プロンプト")
            .popover(isPresented: $showsPromptEditor, arrowEdge: .trailing) {
                PromptEditorPopover(prompt: $cut.generationPrompt)
            }

            iconButton(
                systemName: "plus.square.on.square",
                help: "この後ろにカットを追加",
                action: addAfter
            )

            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
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
            placeholder: "内容",
            baseFontSize: textBaseFontSize,
            minimumFontSize: 8,
            isPrinting: isPrintingStoryboard
        )
    }

    private var actionColumn: some View {
        DialogueSheetEditor(
            lines: $cut.dialogueLines,
            speakerRatio: $cut.dialogueSpeakerRatio,
            baseFontSize: textBaseFontSize,
            showsLineControls: showsCutActionControls,
            isPrinting: isPrintingStoryboard
        )
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

private struct SplitDragHandle: View {
    @State private var isHovering = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle()
                    .fill(Color.white)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: proxy.size.height / 2))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height / 2))
                }
                .stroke(Color.black.opacity(0.65), style: StrokeStyle(lineWidth: 0.8, dash: [2, 2]))
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

    private let minimumRowHeight: CGFloat = 18
    private let splitHandleWidth: CGFloat = 3
    private let buttonWidth: CGFloat = 14
    private let minimumSpeakerWidth: CGFloat = 24
    private let minimumDialogueWidth: CGFloat = 26

    private var fontSize: CGFloat {
        max(baseFontSize - 1, 8)
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                let minimumEditorWidth = minimumSpeakerWidth + splitHandleWidth + minimumDialogueWidth

                if proxy.size.width >= minimumEditorWidth {
                    let speakerWidth = speakerWidth(totalWidth: proxy.size.width)
                    let dialogueWidth = max(proxy.size.width - speakerWidth - splitHandleWidth, minimumDialogueWidth)
                    let rowFontSize = isPrinting
                        ? StoryboardTextFitter.dialogueFontSize(
                            for: lines,
                            speakerWidth: speakerWidth,
                            dialogueWidth: dialogueWidth,
                            height: proxy.size.height,
                            base: fontSize,
                            minimum: 5.5,
                            minimumRowHeight: minimumRowHeight
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
                    Color.white
                }
            }
        }
        .background(Color.white)
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
            width: speakerWidth - (StoryboardTextPadding.horizontal * 2),
            fontSize: fontSize
        )
        let dialogueHeight = StoryboardTextFitter.estimatedHeight(
            for: line.dialogue,
            width: dialogueWidth - (StoryboardTextPadding.horizontal * 2),
            fontSize: fontSize
        )
        let textHeight = max(speakerHeight, dialogueHeight) + (StoryboardTextPadding.vertical * 2)
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
    var showsLineControls: Bool
    var isPrinting: Bool
    var canDelete: Bool
    var showsAddButton: Bool
    var add: () -> Void
    var delete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            speakerCell

            DialogueColumnSplitHandle()
                .frame(width: splitHandleWidth)
                .frame(height: rowHeight)
                .gesture(splitGesture(totalWidth: speakerWidth + dialogueWidth + splitHandleWidth))

            dialogueCell
        }
        .frame(height: rowHeight, alignment: .topLeading)
        .background(Color.white)
        .overlay(alignment: .bottomLeading) {
            if showsLineControls {
                Button(action: showsAddButton ? add : delete) {
                    Image(systemName: showsAddButton ? "plus" : "minus")
                }
                .buttonStyle(.borderless)
                .controlSize(.mini)
                .font(.system(size: 8))
                .frame(width: buttonWidth, height: buttonWidth)
                .opacity(showsAddButton || canDelete ? 0.7 : 0.25)
                .pointingHandCursor(isEnabled: showsAddButton || canDelete)
                .disabled(!showsAddButton && !canDelete)
                .help(showsAddButton ? "会話行を追加" : "会話行を削除")
                .offset(x: 2, y: -2)
            }
        }
        .overlay(alignment: .bottom) {
            DialogueSheetRowDivider()
        }
    }

    @ViewBuilder
    private var speakerCell: some View {
        if isPrinting {
            Text(line.speaker)
                .font(.system(size: fontSize))
                .foregroundStyle(.black)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .padding(.horizontal, StoryboardTextPadding.horizontal)
                .padding(.vertical, StoryboardTextPadding.vertical)
                .frame(width: speakerWidth, alignment: .topLeading)
                .frame(height: rowHeight, alignment: .topLeading)
        } else {
            StoryboardTextView(text: $line.speaker, fontSize: fontSize)
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
                alignment: .justified
            )
                .frame(width: dialogueWidth, alignment: .topLeading)
                .frame(height: rowHeight, alignment: .topLeading)
        } else {
            StoryboardTextView(text: $line.dialogue, fontSize: fontSize, alignment: .justified)
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
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.25))
                path.addLine(to: CGPoint(x: proxy.size.width, y: 0.25))
            }
            .stroke(Color.black.opacity(0.22), style: StrokeStyle(lineWidth: 0.5, dash: [1.4, 2.2]))
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
                    .fill(Color.black.opacity(0.14))
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
                                .fill(Color(red: 0.99, green: 0.988, blue: 0.98))

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
                            .stroke(Color.black.opacity(0.12), lineWidth: 0.8)
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
                        .stroke(Color.black.opacity(0.12), lineWidth: 0.5)
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
                Rectangle().fill(.white).frame(width: StoryboardPageLayout.sideColumnWidth, height: StoryboardPageLayout.rowHeight)
                Rectangle().fill(Color(red: 0.98, green: 0.975, blue: 0.955)).frame(width: StoryboardPageLayout.cutImageGap, height: StoryboardPageLayout.rowHeight)
                Rectangle().fill(screenBackgroundColor).frame(width: imageColumnWidth, height: StoryboardPageLayout.rowHeight)
                Rectangle().fill(.white).frame(width: contentColumnWidth, height: StoryboardPageLayout.rowHeight)
                Rectangle().fill(.white).frame(width: actionColumnWidth, height: StoryboardPageLayout.rowHeight)
                Rectangle().fill(.white).frame(width: StoryboardPageLayout.sideColumnWidth, height: StoryboardPageLayout.rowHeight)
            }

        }
        .frame(height: StoryboardPageLayout.rowHeight)
    }
}

private struct PromptEditorPopover: View {
    @Binding var prompt: String

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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("追加プロンプト")
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
            }

            TextEditor(text: $prompt)
                .font(.system(size: 12))
                .foregroundStyle(.black)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.8)
                }
                .frame(width: 460, height: 320)
        }
        .padding(12)
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

    var body: some View {
        GeometryReader { proxy in
            if isPrinting {
                let printFontSize = StoryboardTextFitter.fontSize(
                    for: text,
                    width: proxy.size.width - (StoryboardTextPadding.horizontal * 2),
                    height: proxy.size.height - (StoryboardTextPadding.vertical * 2),
                    base: fontSize,
                    minimum: 5.5
                )

                StoryboardStaticTextView(
                    text: text,
                    fontSize: printFontSize,
                    alignment: .justified
                )
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            } else {
                StoryboardTextView(
                    text: $text,
                    fontSize: fontSize,
                    lineSpacing: fontSize <= 8 ? 0 : 1,
                    alignment: .justified
                )
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(placeholder)
                                .font(.system(size: 11))
                                .foregroundStyle(.gray)
                                .padding(.leading, StoryboardTextPadding.horizontal)
                                .padding(.top, StoryboardTextPadding.vertical)
                        }
                    }
            }
        }
    }
}
