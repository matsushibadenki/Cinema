// file:///Users/Shared/Program/Xcode/Cinema/Sources/Cinema/Views/SidebarView.swift
// SidebarView.swift
// 絵コンテアプリのサイドバービュー。ブロック（シーン）リスト、カット一覧、AI描画・動画化設定パネルなどのナビゲーションUIを表示・管理します。

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Binding var title: String
    @Binding var drawingSettings: DrawingSettings
    var cuts: [StoryboardCut]
    var imageData: [String: Data]
    @Binding var pageIndex: Int
    var pageCount: Int
    var navigationSectionTitle: String
    var navigationSummaries: [String]
    var allowsDeleteNavigationItems: Bool
    var addCut: () -> Void
    var addSubtitle: () -> Void
    var addCutAbove: (StoryboardCut.ID) -> Void
    var addCutBelow: (StoryboardCut.ID) -> Void
    var deleteCut: (StoryboardCut.ID) -> Void
    var deletePage: (Int) -> Void
    var jumpToCut: (StoryboardCut.ID) -> Void
    var moveCuts: (IndexSet, Int, [StoryboardCut.ID]) -> Void
    var moveCutRelativeToTarget: (StoryboardCut.ID, StoryboardCut.ID, CutDropPosition) -> Void
    var updateCutName: (StoryboardCut.ID, String) -> Void
    var sceneVideos: [SceneVideo]
    @Binding var selectedVideoSceneTitle: String?
    @Binding var selectedVideoCutIDs: Set<StoryboardCut.ID>
    var generatingSceneTitle: String?
    var generateSceneVideo: (String) -> Void
    var saveSceneVideo: (SceneVideo) -> Void
    var exportScenePrompts: (String) -> Void
    var aiEstimatedTokensUsed: Int
    var aiEstimatedCostUSD: Double
    var aiCostLimitEnabled: Bool
    var aiCostLimitUSD: Double
    var isAICostLimitExceeded: Bool
    var appLanguage: String
    @AppStorage("appThemeMode") private var appThemeMode = AppThemeMode.system.rawValue

    @State private var draggedCutID: StoryboardCut.ID?
    @State private var hoveredDropTarget: HoveredCutDropTarget?

    var body: some View {
        HStack(spacing: 0) {
            commandRail

            VStack(alignment: .leading, spacing: 12) {
                sidebarHeader
                aiPanel
                navigationList
                bottomActions
            }
            .padding(.top, 12)
            .frame(minWidth: 266)
            .background(CinemaDesign.panelBackground)
        }
        .frame(minWidth: 326)
        .background(CinemaDesign.canvasBackground)
    }

    private var commandRail: some View {
        VStack(spacing: 12) {
            Image(systemName: "movieclapper.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(CinemaDesign.keyColor)
                .frame(width: 42, height: 42)
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(CinemaDesign.cardSurface)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(CinemaDesign.cardStroke, lineWidth: 0.7)
                }
                .padding(.top, 12)

            Rectangle()
                .fill(CinemaDesign.cardStroke)
                .frame(width: 28, height: 1)
                .padding(.vertical, 2)

            SidebarRailButton(systemName: "text.badge.plus", help: t(.addBlock), action: addSubtitle)
            SidebarRailButton(systemName: "plus.square.on.square", help: t(.addCut), isProminent: true, action: addCut)

            Spacer()

            themeSwitcher
                .padding(.bottom, 12)
        }
        .frame(width: 60)
        .background(CinemaDesign.railBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(CinemaDesign.cardStroke)
                .frame(width: 1)
        }
    }

    private var selectedThemeMode: AppThemeMode {
        get { AppThemeMode(rawValue: appThemeMode) ?? .system }
        nonmutating set { appThemeMode = newValue.rawValue }
    }

    private var themeSwitcher: some View {
        VStack(spacing: 6) {
            ForEach(AppThemeMode.allCases) { mode in
                Button {
                    selectedThemeMode = mode
                } label: {
                    Image(systemName: mode.symbolName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selectedThemeMode == mode ? CinemaDesign.inverseInk : CinemaDesign.keyColor.opacity(0.82))
                        .frame(width: 34, height: 34)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedThemeMode == mode ? CinemaDesign.keyColor : CinemaDesign.railIconBackground)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(selectedThemeMode == mode ? CinemaDesign.keyColor.opacity(0.95) : CinemaDesign.railIconStroke, lineWidth: 0.7)
                        }
                }
                .buttonStyle(.plain)
                .help(mode.helpText)
            }
        }
        .padding(6)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(CinemaDesign.cardSurface.opacity(0.92))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(CinemaDesign.cardStroke, lineWidth: 0.7)
        }
        .shadow(color: CinemaDesign.raisedShadow.opacity(0.35), radius: 8, x: 0, y: 4)
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cinema")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(CinemaDesign.quietInk)
                .textCase(.uppercase)

            TextField(t(.title), text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(CinemaDesign.ink)
                .lineLimit(1)

            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 11, weight: .medium))
                Text("\(cuts.count) \(t(.cut))")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(CinemaDesign.mutedInk)
        }
        .padding(.horizontal, 18)
    }

    private var navigationList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if displayModeShowsPageNavigation {
                    pageNavigationSection
                }

                blockCutTreeSection
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
    }

    private var bottomActions: some View {
        HStack(spacing: 10) {
            Button {
                addSubtitle()
            } label: {
                Label(t(.addBlock), systemImage: "text.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                addCut()
            } label: {
                Label(t(.addCut), systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    private var aiPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // AI header with sparkle badge
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CinemaDesign.aiSparkle)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(CinemaDesign.aiSparkleLight)
                    )

                Text(t(.ai))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(CinemaDesign.ink)

                Spacer()
            }

            aiSummaryMetrics

            if isAICostLimitExceeded {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text(t(.costLimitExceeded))
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.red.opacity(0.08))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Label(t(.drawingPreset), systemImage: "paintpalette")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CinemaDesign.mutedInk)

                Picker(t(.drawingPreset), selection: $drawingSettings.selectedPresetID) {
                    ForEach(drawingSettings.presets) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            DisclosureGroup {
                videoSelectionPanel
            } label: {
                Label(t(.video), systemImage: "film.stack")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(14)
        .background(
            isAICostLimitExceeded
            ? AnyShapeStyle(Color.red.opacity(0.06))
            : AnyShapeStyle(CinemaDesign.aiSparkleLight)
        )
        .cinemaPanel(isHighlighted: true)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    isAICostLimitExceeded
                    ? Color.red.opacity(0.50)
                    : CinemaDesign.warmBorder,
                    lineWidth: isAICostLimitExceeded ? 1.2 : 0.8
                )
        }
        .padding(.horizontal, 14)
    }

    private var aiSummaryMetrics: some View {
        HStack(spacing: 10) {
            // Token card
            VStack(alignment: .leading, spacing: 3) {
                Text(t(.estimatedTokens))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isAICostLimitExceeded ? .red.opacity(0.7) : CinemaDesign.mutedInk)
                    .lineLimit(1)

                Text("\(aiEstimatedTokensUsed)")
                    .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(isAICostLimitExceeded ? .red : CinemaDesign.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(CinemaDesign.insetSurface.opacity(0.94))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(CinemaDesign.fineBorder, lineWidth: 0.6)
            }

            // Cost card
            VStack(alignment: .leading, spacing: 3) {
                Text(t(.estimatedCost))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isAICostLimitExceeded ? .red.opacity(0.7) : CinemaDesign.mutedInk)
                    .lineLimit(1)

                Text(estimatedCostText)
                    .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(isAICostLimitExceeded ? .red : CinemaDesign.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if aiCostLimitEnabled {
                    Text("\(t(.limit)): \(costText(aiCostLimitUSD))")
                        .font(.system(size: 9, weight: .medium).monospacedDigit())
                        .foregroundStyle(isAICostLimitExceeded ? .red.opacity(0.7) : .secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(CinemaDesign.insetSurface.opacity(0.94))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(CinemaDesign.fineBorder, lineWidth: 0.6)
            }
        }
    }

    private var selectedSection: CutSidebarSection? {
        guard let selectedVideoSceneTitle else { return nil }
        return cutSections.first { $0.title == selectedVideoSceneTitle }
    }

    private var displayModeShowsPageNavigation: Bool {
        navigationSectionTitle != t(.cut)
    }

    private var videoSelectionPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let selectedSection {
                Text(selectedSection.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                let selectedCuts = selectedSection.cuts.filter { selectedVideoCutIDs.contains($0.id) }

                Text("対象: Cut \(selectedCuts.map(\.cutNumber).map(String.init).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                VStack(spacing: 8) {
                    Button {
                        exportScenePrompts(selectedSection.title)
                    } label: {
                        Text(t(.exportPrompt))
                            .foregroundStyle(CinemaDesign.inverseInk)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.gray)

                    HStack {
                        Button {
                            generateSceneVideo(selectedSection.title)
                        } label: {
                            Text(generatingSceneTitle == selectedSection.title ? t(.generating) : t(.createSelectedSceneVideo))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(generatingSceneTitle != nil)

                        if let video = sceneVideos.first(where: { $0.title == selectedSection.title }) {
                            Button {
                                saveSceneVideo(video)
                            } label: {
                                Image(systemName: "square.and.arrow.down")
                            }
                            .buttonStyle(.bordered)
                            .help(t(.saveGeneratedVideo))
                        }
                    }
                }
            } else {
                Text(t(.selectScene))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .cinemaPanel()
    }

    private var estimatedCostText: String {
        costText(aiEstimatedCostUSD)
    }

    private func costText(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 4
        return formatter.string(from: NSNumber(value: value)) ?? "$0.0000"
    }

    private func cutSelectionBinding(for cutID: StoryboardCut.ID) -> Binding<Bool> {
        Binding {
            selectedVideoCutIDs.contains(cutID)
        } set: { isSelected in
            if isSelected {
                selectedVideoCutIDs.insert(cutID)
            } else {
                selectedVideoCutIDs.remove(cutID)
            }
        }
    }

    private var pageNavigationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(navigationSectionTitle)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(CinemaDesign.quietInk)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { index in
                    let summary = navigationSummaries.indices.contains(index) ? navigationSummaries[index] : "\(navigationSectionTitle) \(index + 1)"

                    Button {
                        pageIndex = index
                    } label: {
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundStyle(pageIndex == index ? CinemaDesign.keyColor : CinemaDesign.quietInk)
                                .frame(width: 22, height: 22)
                                .background {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(pageIndex == index ? CinemaDesign.keyColorSoft : CinemaDesign.insetSurface.opacity(0.88))
                                }

                            Text(summary)
                                .font(.system(size: 12, weight: pageIndex == index ? .semibold : .medium))
                                .foregroundStyle(pageIndex == index ? CinemaDesign.ink : CinemaDesign.mutedInk)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(pageIndex == index ? CinemaDesign.selectedRowSurface : CinemaDesign.cardSurface.opacity(0.72))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(pageIndex == index ? CinemaDesign.warmBorder : CinemaDesign.cardStroke, lineWidth: 0.8)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if allowsDeleteNavigationItems {
                            Button(t(.deletePage), role: .destructive) {
                                deletePage(index)
                            }
                            .disabled(pageCount <= 1)
                        }
                    }
                }
            }
        }
    }

    private var blockCutTreeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t(.structure))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(CinemaDesign.quietInk)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(spacing: 10) {
                ForEach(cutSections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        SceneSelectionRow(
                            title: section.title,
                            cutCount: section.cuts.count,
                            rangeText: section.rangeText,
                            isSelected: selectedVideoSceneTitle == section.title,
                            isGenerating: generatingSceneTitle == section.title,
                            hasVideo: sceneVideos.contains(where: { $0.title == section.title }),
                            select: { selectedVideoSceneTitle = section.title }
                        )

                        VStack(spacing: 6) {
                            ForEach(section.cuts) { cut in
                                CutSidebarRow(
                                    cut: cut,
                                    title: cutTitle(for: cut),
                                    cutName: cutNameBinding(for: cut.id),
                                    previewImage: previewImage(for: cut),
                                    isCurrentCut: currentCutID == cut.id,
                                    isVideoSceneSelected: selectedVideoSceneTitle == section.title,
                                    isCutSelectedForVideo: cutSelectionBinding(for: cut.id),
                                    isDragged: draggedCutID == cut.id,
                                    dropTargetPosition: hoveredDropTarget?.targetID == cut.id ? hoveredDropTarget?.position : nil,
                                    openCut: { jumpToCut(cut.id) },
                                    startDrag: {
                                        draggedCutID = cut.id
                                        return NSItemProvider(object: cut.id.uuidString as NSString)
                                    }
                                )
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: CutDropDelegate(
                                        targetID: cut.id,
                                        draggedCutID: $draggedCutID,
                                        hoveredDropTarget: $hoveredDropTarget,
                                        moveCutRelativeToTarget: moveCutRelativeToTarget
                                    )
                                )
                                .contextMenu {
                                    Button(t(.goToCut)) {
                                        jumpToCut(cut.id)
                                    }

                                    Divider()

                                    Button(t(.addCutAbove)) {
                                        addCutAbove(cut.id)
                                    }

                                    Button(t(.addCutBelow)) {
                                        addCutBelow(cut.id)
                                    }

                                    Divider()

                                    Button(t(.deleteCut), role: .destructive) {
                                        deleteCut(cut.id)
                                    }
                                }
                            }
                        }
                        .padding(.leading, 12)
                    }
                    .padding(10)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(CinemaDesign.cardSurface.opacity(0.78))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(CinemaDesign.cardStroke, lineWidth: 0.8)
                    }
                }
            }
        }
    }

    private var cutSections: [CutSidebarSection] {
        var sections: [CutSidebarSection] = []
        var currentTitle = CinemaStrings.blockName(1, language: appLanguage)
        var currentCuts: [StoryboardCut] = []

        for cut in cuts {
            let subtitle = cut.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !subtitle.isEmpty {
                if !currentCuts.isEmpty {
                    sections.append(CutSidebarSection(title: currentTitle, cuts: currentCuts))
                    currentCuts = []
                }
                currentTitle = subtitle
            }
            currentCuts.append(cut)
        }

        if !currentCuts.isEmpty {
            sections.append(CutSidebarSection(title: currentTitle, cuts: currentCuts))
        }

        return sections
    }

    private func cutTitle(for cut: StoryboardCut) -> String {
        let name = cut.cutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "Cut \(cut.cutNumber)" }
        return "Cut \(cut.cutNumber)"
    }

    private var currentCutID: StoryboardCut.ID? {
        guard navigationSectionTitle == t(.cut),
              cuts.indices.contains(pageIndex) else {
            return nil
        }
        return cuts[pageIndex].id
    }

    private func previewImage(for cut: StoryboardCut) -> NSImage? {
        guard let imageFileName = cut.imageFileName else { return nil }
        return ImageHelpers.nsImage(from: imageData[imageFileName])
    }

    private func cutNameBinding(for cutID: StoryboardCut.ID) -> Binding<String> {
        Binding(
            get: {
                cuts.first(where: { $0.id == cutID })?.cutName ?? ""
            },
            set: { newValue in
                updateCutName(cutID, newValue)
            }
        )
    }
}

private extension SidebarView {
    func t(_ key: CinemaTextKey) -> String {
        CinemaStrings.text(key, language: appLanguage)
    }
}

private struct CutSidebarSection: Identifiable {
    let id = UUID()
    var title: String
    var cuts: [StoryboardCut]

    var rangeText: String {
        let numbers = cuts.map(\.cutNumber)
        guard let first = numbers.first, let last = numbers.last else { return "" }
        return first == last ? "Cut \(first)" : "Cut \(first)-\(last)"
    }
}

private struct SidebarRailButton: View {
    var systemName: String
    var help: String
    var isProminent = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isProminent ? CinemaDesign.inverseInk : CinemaDesign.keyColor.opacity(0.86))
                .frame(width: 38, height: 38)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isProminent ? CinemaDesign.keyColor : CinemaDesign.railIconBackground)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isProminent ? CinemaDesign.keyColor.opacity(0.9) : CinemaDesign.railIconStroke, lineWidth: 0.7)
                }
        }
        .buttonStyle(.plain)
        .shadow(color: isProminent ? CinemaDesign.keyColor.opacity(0.22) : CinemaDesign.raisedShadow.opacity(0.28), radius: isProminent ? 10 : 4, x: 0, y: isProminent ? 5 : 2)
        .help(help)
    }
}

private struct CutSidebarRow: View {
    var cut: StoryboardCut
    var title: String
    @Binding var cutName: String
    var previewImage: NSImage?
    var isCurrentCut: Bool
    var isVideoSceneSelected: Bool
    @Binding var isCutSelectedForVideo: Bool
    var isDragged: Bool
    var dropTargetPosition: CutDropPosition?
    var openCut: () -> Void
    var startDrag: () -> NSItemProvider

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            dragHandle

            if isVideoSceneSelected {
                Toggle("", isOn: $isCutSelectedForVideo)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .help("このカットを動画化に含める")
                    .padding(.top, 8)
            }

            HStack(alignment: .top, spacing: 10) {
                previewThumbnail

                VStack(alignment: .leading, spacing: 4) {
                    Button(action: openCut) {
                        Text(title)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isCurrentCut ? CinemaDesign.ink : CinemaDesign.mutedInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    EditableCutNameField(text: $cutName)
                        .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)

                    if !cut.situation.isEmpty {
                        Text(cut.situation)
                            .foregroundStyle(CinemaDesign.quietInk)
                            .font(.system(size: 10.5, weight: .regular))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
        .overlay(alignment: .top) {
            if dropTargetPosition == .before {
                Rectangle()
                    .fill(CinemaDesign.keyColor)
                    .frame(height: 3)
                    .padding(.leading, 2)
            }
        }
        .overlay(alignment: .bottom) {
            if dropTargetPosition == .after {
                Rectangle()
                    .fill(CinemaDesign.keyColor)
                    .frame(height: 3)
                    .padding(.leading, 2)
            }
        }
        .overlay {
            if dropTargetPosition != nil {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(CinemaDesign.keyColor.opacity(0.7), lineWidth: 1)
            }
        }
        .opacity(isDragged ? 0.65 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture(perform: openCut)
    }

    private var dragHandle: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(isDragged ? CinemaDesign.keyColor.opacity(0.18) : CinemaDesign.insetSurface.opacity(0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(CinemaDesign.fineBorder, lineWidth: 0.6)
                }

            Image(systemName: "line.3.horizontal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isDragged ? CinemaDesign.keyColor : Color.secondary.opacity(0.75))
        }
        .frame(width: 18, height: 28)
        .contentShape(RoundedRectangle(cornerRadius: 4))
        .help("ドラッグしてカットを並べ替え")
        .onDrag(startDrag)
    }

    @ViewBuilder
    private var rowBackground: some View {
        if dropTargetPosition != nil {
            RoundedRectangle(cornerRadius: 6)
                .fill(CinemaDesign.keyColor.opacity(0.16))
        } else if isDragged {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.14))
        } else if isCurrentCut {
            RoundedRectangle(cornerRadius: 8)
                .fill(CinemaDesign.selectedRowSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(CinemaDesign.warmBorder, lineWidth: 0.8)
                }
        } else if isVideoSceneSelected {
            RoundedRectangle(cornerRadius: 6)
                .fill(CinemaDesign.insetSurface.opacity(0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(CinemaDesign.warmBorder, lineWidth: 0.8)
                }
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(CinemaDesign.insetSurface.opacity(0.62))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(CinemaDesign.fineBorder.opacity(0.72), lineWidth: 0.6)
                }
        }
    }

    private var previewThumbnail: some View {
        Group {
            if let previewImage {
                Image(nsImage: previewImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            CinemaDesign.keyColorSoft.opacity(0.9),
                            CinemaDesign.insetSurface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Image(systemName: "photo")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CinemaDesign.quietInk)
                }
            }
        }
        .frame(width: 54, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(CinemaDesign.cardStroke, lineWidth: 0.7)
        }
    }
}

enum CutDropPosition: Equatable {
    case before
    case after
}

private struct HoveredCutDropTarget: Equatable {
    var targetID: StoryboardCut.ID
    var position: CutDropPosition
}

private struct EditableCutNameField: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> EditableCutNameNSTextField {
        let field = EditableCutNameNSTextField(frame: .zero)
        field.isEditable = true
        field.isSelectable = true
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.font = .systemFont(ofSize: 10, weight: .regular)
        field.delegate = context.coordinator
        field.focusRingType = .none
        field.usesSingleLineMode = true
        field.lineBreakMode = .byTruncatingTail
        field.placeholderString = "カット名"
        field.stringValue = text
        return field
    }

    func updateNSView(_ nsView: EditableCutNameNSTextField, context: Context) {
        guard !context.coordinator.isEditing else { return }
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var isEditing = false

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            isEditing = true
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            isEditing = false
            controlTextDidChange(obj)
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}

private final class EditableCutNameNSTextField: NSTextField {
    override var acceptsFirstResponder: Bool { true }
}

private struct CutDropDelegate: DropDelegate {
    var targetID: StoryboardCut.ID
    @Binding var draggedCutID: StoryboardCut.ID?
    @Binding var hoveredDropTarget: HoveredCutDropTarget?
    var moveCutRelativeToTarget: (StoryboardCut.ID, StoryboardCut.ID, CutDropPosition) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func dropEntered(info: DropInfo) {
        guard let draggedCutID, draggedCutID != targetID else { return }
        updateHoverAndMoveIfNeeded(draggedCutID: draggedCutID, info: info)
    }

    func dropExited(info: DropInfo) {
        if hoveredDropTarget?.targetID == targetID {
            hoveredDropTarget = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedCutID = nil
        hoveredDropTarget = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if let draggedCutID, draggedCutID != targetID {
            updateHoverAndMoveIfNeeded(draggedCutID: draggedCutID, info: info)
        }
        return DropProposal(operation: .move)
    }

    private func dropPosition(for info: DropInfo) -> CutDropPosition {
        info.location.y < 26 ? .before : .after
    }

    private func updateHoverAndMoveIfNeeded(draggedCutID: StoryboardCut.ID, info: DropInfo) {
        let nextTarget = HoveredCutDropTarget(targetID: targetID, position: dropPosition(for: info))
        guard hoveredDropTarget != nextTarget else { return }
        hoveredDropTarget = nextTarget
        moveCutRelativeToTarget(draggedCutID, targetID, nextTarget.position)
    }
}

private struct SceneSelectionRow: View {
    var title: String
    var cutCount: Int
    var rangeText: String
    var isSelected: Bool
    var isGenerating: Bool
    var hasVideo: Bool
    var select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 8) {
                // Accent bar for selected state
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isSelected ? CinemaDesign.keyColor : Color.clear)
                    .frame(width: 3, height: 24)

                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? CinemaDesign.keyColor : .secondary)
                    .font(.system(size: 13))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(rangeText)
                            .font(.caption.weight(.medium))
                        Text("\(cutCount)カット")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if isGenerating {
                    SidebarProgressIndicator()
                        .frame(width: 16, height: 16)
                } else if hasVideo {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 14))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? CinemaDesign.selectedRowSurface : Color.clear)
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(CinemaDesign.warmBorder, lineWidth: 0.8)
                        }
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SidebarProgressIndicator: NSViewRepresentable {
    func makeNSView(context: Context) -> CompactSidebarProgressIndicator {
        let indicator = CompactSidebarProgressIndicator(frame: .zero)
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.isIndeterminate = true
        indicator.startAnimation(nil)
        return indicator
    }

    func updateNSView(_ nsView: CompactSidebarProgressIndicator, context: Context) {
        nsView.startAnimation(nil)
    }
}

private final class CompactSidebarProgressIndicator: NSProgressIndicator {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}
