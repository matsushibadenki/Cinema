import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum StoryboardTextPadding {
    static let horizontal: CGFloat = 4
    static let vertical: CGFloat = 3
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
                width: dialogueWidth - StoryboardTextPadding.horizontal,
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

    var imageData: Data?
    var image: NSImage?
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
    var addAfter: () -> Void
    var delete: () -> Void

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                cutColumn
                    .frame(width: StoryboardPageLayout.sideColumnWidth, height: StoryboardPageLayout.rowHeight)

                Rectangle()
                    .fill(Color.white)
                    .frame(width: StoryboardPageLayout.cutImageGap, height: StoryboardPageLayout.rowHeight)

                StoryboardScreenFrame(
                    imageData: imageData,
                    image: image,
                    aspectRatio: screenAspectRatio,
                    showsGeneratePlaceholder: showsGeneratePlaceholder,
                    backgroundBrightness: screenBackgroundBrightness,
                    isGenerating: isGenerating
                )
                .frame(width: imageColumnWidth, height: StoryboardPageLayout.rowHeight)

                contentColumn
                    .background(Color.white)
                    .frame(width: contentColumnWidth, height: StoryboardPageLayout.rowHeight)

                actionColumn
                    .background(Color.white)
                    .frame(width: actionColumnWidth, height: StoryboardPageLayout.rowHeight)

                TextField("", text: $cut.duration)
                    .font(.system(size: 10, design: .serif))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .frame(width: StoryboardPageLayout.sideColumnWidth, height: StoryboardPageLayout.rowHeight)
            }

        }
        .frame(height: StoryboardPageLayout.rowHeight)
    }

    private var cutColumn: some View {
        ZStack {
            VStack(spacing: 3) {
                TextField("", value: $cut.cutNumber, format: .number)
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)

                TextField("名前", text: $cut.cutName)
                    .font(.system(size: 8))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 2)

            if showsCutActionControls {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Button(action: generate) {
                            Image(systemName: "sparkles")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        .font(.system(size: 8))
                        .frame(width: 14, height: 14)
                        .contentShape(Rectangle())
                        .pointingHandCursor(isEnabled: !isGenerating)
                        .help("AIで画面を生成")
                        .disabled(isGenerating)

                        Button {
                            showsPromptEditor.toggle()
                        } label: {
                            Image(systemName: "text.badge.plus")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        .font(.system(size: 8))
                        .frame(width: 14, height: 14)
                        .contentShape(Rectangle())
                        .pointingHandCursor()
                        .help("追加プロンプト")
                        .popover(isPresented: $showsPromptEditor, arrowEdge: .trailing) {
                            PromptEditorPopover(prompt: $cut.generationPrompt)
                        }
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 0) {
                        Button(action: addAfter) {
                            Image(systemName: "plus.square.on.square")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        .font(.system(size: 8))
                        .frame(width: 14, height: 14)
                        .contentShape(Rectangle())
                        .pointingHandCursor()
                        .help("この後ろにカットを追加")

                        Button(role: .destructive, action: delete) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                        .font(.system(size: 8))
                        .frame(width: 14, height: 14)
                        .contentShape(Rectangle())
                        .pointingHandCursor()
                        .help("カットを削除")
                    }
                }
                .frame(width: 30)
                .padding(.vertical, 3)
            }
        }
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
        .help("ドラッグして内容とト書きの高さを調整")
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
    private let buttonGap: CGFloat = 3

    private var fontSize: CGFloat {
        max(baseFontSize - 1, 8)
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                let lineControlWidth = showsLineControls ? buttonWidth : 0
                let lineControlGap = showsLineControls ? buttonGap : 0
                let speakerWidth = speakerWidth(totalWidth: proxy.size.width)
                let dialogueWidth = max(proxy.size.width - speakerWidth - splitHandleWidth - lineControlGap - lineControlWidth, 1)
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
                            DialogueSheetRow(
                                line: $line,
                                speakerRatio: $speakerRatio,
                                fontSize: rowFontSize,
                                minimumRowHeight: minimumRowHeight,
                                speakerWidth: speakerWidth,
                                dialogueWidth: dialogueWidth,
                                splitHandleWidth: splitHandleWidth,
                                buttonWidth: lineControlWidth,
                                buttonGap: lineControlGap,
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
        let lineControlWidth = showsLineControls ? buttonWidth : 0
        let lineControlGap = showsLineControls ? buttonGap : 0
        let availableWidth = max(totalWidth - lineControlWidth - lineControlGap - splitHandleWidth, 1)
        let minimumSpeakerWidth: CGFloat = 36
        let maximumSpeakerWidth = max(minimumSpeakerWidth, availableWidth - 60)
        return min(max(availableWidth * CGFloat(clampedSpeakerRatio(speakerRatio)), minimumSpeakerWidth), maximumSpeakerWidth)
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
    var speakerWidth: CGFloat
    var dialogueWidth: CGFloat
    var splitHandleWidth: CGFloat
    var buttonWidth: CGFloat
    var buttonGap: CGFloat
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
                .frame(minHeight: minimumRowHeight, maxHeight: .infinity)
                .gesture(splitGesture(totalWidth: speakerWidth + dialogueWidth + splitHandleWidth + buttonGap + buttonWidth))

            dialogueCell

            if showsLineControls {
                Spacer(minLength: 0)
                    .frame(width: buttonGap)

                Button(action: showsAddButton ? add : delete) {
                    Image(systemName: showsAddButton ? "plus" : "minus")
                }
                .buttonStyle(.borderless)
                .controlSize(.mini)
                .font(.system(size: 8))
                .padding(.vertical, 2)
                .frame(width: buttonWidth, alignment: .top)
                .frame(minHeight: minimumRowHeight, alignment: .top)
                .opacity(showsAddButton || canDelete ? 0.7 : 0.25)
                .pointingHandCursor(isEnabled: showsAddButton || canDelete)
                .disabled(!showsAddButton && !canDelete)
                .help(showsAddButton ? "会話行を追加" : "会話行を削除")
            }
        }
        .frame(minHeight: minimumRowHeight, alignment: .topLeading)
        .background(Color.white)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.2))
                .frame(height: 0.5)
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
                .frame(minHeight: minimumRowHeight, alignment: .topLeading)
        } else {
            TextField("", text: $line.speaker, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: fontSize))
                .foregroundStyle(.black)
                .multilineTextAlignment(.leading)
                .lineLimit(1...)
                .padding(.horizontal, StoryboardTextPadding.horizontal)
                .padding(.vertical, StoryboardTextPadding.vertical)
                .frame(width: speakerWidth, alignment: .topLeading)
                .frame(minHeight: minimumRowHeight, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var dialogueCell: some View {
        if isPrinting {
            Text(line.dialogue)
                .font(.system(size: fontSize))
                .foregroundStyle(.black)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .padding(.leading, StoryboardTextPadding.horizontal)
                .padding(.trailing, 0)
                .padding(.vertical, StoryboardTextPadding.vertical)
                .frame(width: dialogueWidth, alignment: .topLeading)
                .frame(minHeight: minimumRowHeight, alignment: .topLeading)
        } else {
            TextField("", text: $line.dialogue, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: fontSize))
                .foregroundStyle(.black)
                .multilineTextAlignment(.leading)
                .lineLimit(1...)
                .padding(.leading, StoryboardTextPadding.horizontal)
                .padding(.trailing, 0)
                .padding(.vertical, StoryboardTextPadding.vertical)
                .frame(width: dialogueWidth, alignment: .topLeading)
                .frame(minHeight: minimumRowHeight, alignment: .topLeading)
        }
    }

    private func splitGesture(totalWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if speakerDragStartRatio == nil {
                    speakerDragStartRatio = speakerRatio
                }

                let availableWidth = max(totalWidth - buttonWidth - buttonGap - splitHandleWidth, 1)
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
                Rectangle()
                    .fill(backgroundColor)

                ZStack {
                    Rectangle()
                        .fill(Color.white)

                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(4)
                    } else if showsGeneratePlaceholder {
                        VStack(spacing: 6) {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                            Text("Generate")
                                .font(.caption2)
                        }
                        .foregroundStyle(.gray)
                    }
                }
                .frame(width: frameSize.width, height: frameSize.height)

                if isGenerating {
                    ProgressView()
                        .controlSize(.large)
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
        }
    }

    private func saveImage(data: Data) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "storyboard-image.png"
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

    private func fittedSize(in size: CGSize, aspectRatio: CGFloat) -> CGSize {
        let widthBasedHeight = size.width / aspectRatio
        if widthBasedHeight <= size.height {
            return CGSize(width: size.width, height: widthBasedHeight)
        }

        return CGSize(width: size.height * aspectRatio, height: size.height)
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
                Rectangle().fill(.white).frame(width: StoryboardPageLayout.cutImageGap, height: StoryboardPageLayout.rowHeight)
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

                Text(text)
                    .font(.system(size: printFontSize))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .padding(.horizontal, StoryboardTextPadding.horizontal)
                    .padding(.vertical, StoryboardTextPadding.vertical)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            } else {
                TextEditor(text: $text)
                    .font(.system(size: fontSize))
                    .foregroundStyle(.black)
                    .lineSpacing(fontSize <= 8 ? 0 : 1)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, StoryboardTextPadding.horizontal)
                    .padding(.vertical, StoryboardTextPadding.vertical)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(placeholder)
                                .font(.system(size: 11))
                                .foregroundStyle(.gray)
                                .padding(.leading, StoryboardTextPadding.horizontal + 4)
                                .padding(.top, StoryboardTextPadding.vertical + 5)
                        }
                    }
            }
        }
    }
}
