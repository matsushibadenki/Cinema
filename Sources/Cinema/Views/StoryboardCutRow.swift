import AppKit
import SwiftUI

struct StoryboardCutRow: View {
    @Binding var cut: StoryboardCut
    @State private var splitDragStartRatio: Double?

    var image: NSImage?
    var screenAspectRatio: CGFloat
    var showsGeneratePlaceholder: Bool
    var showsCutActionControls: Bool
    var screenBackgroundBrightness: CGFloat
    var imageColumnWidth: CGFloat
    var textColumnWidth: CGFloat
    var textBaseFontSize: CGFloat
    var isGenerating: Bool
    var generate: () -> Void
    var addAfter: () -> Void
    var delete: () -> Void

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                TextField("", value: $cut.cutNumber, format: .number)
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .frame(width: StoryboardPageLayout.sideColumnWidth, height: StoryboardPageLayout.rowHeight)

                Rectangle()
                    .fill(Color.white)
                    .frame(width: StoryboardPageLayout.cutImageGap, height: StoryboardPageLayout.rowHeight)

                StoryboardScreenFrame(
                    image: image,
                    aspectRatio: screenAspectRatio,
                    showsGeneratePlaceholder: showsGeneratePlaceholder,
                    backgroundBrightness: screenBackgroundBrightness,
                    isGenerating: isGenerating
                )
                .frame(width: imageColumnWidth, height: StoryboardPageLayout.rowHeight)

                textColumn
                    .background(Color.white)
                    .frame(width: textColumnWidth, height: StoryboardPageLayout.rowHeight)

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

    private var textColumn: some View {
        GeometryReader { proxy in
            let controlsHeight: CGFloat = showsCutActionControls ? 26 : 0
            let dividerHeight: CGFloat = 7
            let editableHeight = max(proxy.size.height - controlsHeight - dividerHeight, 64)
            let situationHeight = splitHeight(totalHeight: editableHeight)
            let actionHeight = max(editableHeight - situationHeight, 28)

            VStack(spacing: 0) {
                AutoSizingStoryboardTextEditor(
                    text: $cut.situation,
                    placeholder: "内容",
                    baseFontSize: textBaseFontSize,
                    minimumFontSize: 8
                )
                .frame(height: situationHeight)

                SplitDragHandle()
                    .frame(height: dividerHeight)
                    .gesture(splitGesture(totalHeight: editableHeight))

                AutoSizingStoryboardTextEditor(
                    text: $cut.action,
                    placeholder: "ト書き",
                    baseFontSize: textBaseFontSize,
                    minimumFontSize: 7
                )
                .frame(height: actionHeight)

                if showsCutActionControls {
                    cutActionControls
                        .frame(height: controlsHeight)
                }
            }
        }
    }

    private var screenBackgroundColor: Color {
        Color(white: min(max(screenBackgroundBrightness, 0), 1))
    }

    private var cutActionControls: some View {
        HStack(spacing: 4) {
            Button(action: generate) {
                Image(systemName: "sparkles")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
            .help("AIで画面を生成")
            .disabled(isGenerating)

            Button(action: addAfter) {
                Image(systemName: "plus.square.on.square")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
            .help("この後ろにカットを追加")

            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
            .help("カットを削除")

            TextField("追加プロンプト", text: $cut.generationPrompt)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 10))
                .frame(height: 22)
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 2)
    }

    private func splitHeight(totalHeight: CGFloat) -> CGFloat {
        totalHeight * CGFloat(clampedSplitRatio(cut.textSplitRatio))
    }

    private func splitGesture(totalHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if splitDragStartRatio == nil {
                    splitDragStartRatio = cut.textSplitRatio
                }

                let startRatio = splitDragStartRatio ?? cut.textSplitRatio
                let changedRatio = startRatio + Double(value.translation.height / max(totalHeight, 1))
                cut.textSplitRatio = clampedSplitRatio(changedRatio)
            }
            .onEnded { _ in
                cut.textSplitRatio = clampedSplitRatio(cut.textSplitRatio)
                splitDragStartRatio = nil
            }
    }

    private func clampedSplitRatio(_ ratio: Double) -> Double {
        min(max(ratio, 0.2), 0.8)
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

private struct StoryboardScreenFrame: View {
    private let horizontalPadding: CGFloat = 5

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
    var textColumnWidth: CGFloat
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
                Rectangle().fill(.white).frame(width: textColumnWidth, height: StoryboardPageLayout.rowHeight)
                Rectangle().fill(.white).frame(width: StoryboardPageLayout.sideColumnWidth, height: StoryboardPageLayout.rowHeight)
            }

        }
        .frame(height: StoryboardPageLayout.rowHeight)
    }
}

private struct AutoSizingStoryboardTextEditor: View {
    @Binding var text: String
    var placeholder: String
    var baseFontSize: CGFloat
    var minimumFontSize: CGFloat

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
        TextEditor(text: $text)
            .font(.system(size: fontSize))
            .foregroundStyle(.black)
            .lineSpacing(fontSize <= 8 ? 0 : 1)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                        .padding(.leading, 12)
                        .padding(.top, 10)
                }
            }
    }
}
