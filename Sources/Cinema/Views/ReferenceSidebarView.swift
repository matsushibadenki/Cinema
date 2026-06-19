import AppKit
import SwiftUI

private enum InspectorSidebarTab: String, CaseIterable, Identifiable {
    case reference
    case properties

    var id: String { rawValue }

    func label(language: String) -> String {
        CinemaStrings.text(self == .reference ? .reference : .properties, language: language)
    }
}

struct ReferenceSidebarView: View {
    @Binding var document: StoryboardDocument
    var appLanguage: String
    @State private var selectedTab: InspectorSidebarTab = .reference

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("表示", selection: $selectedTab) {
                ForEach(InspectorSidebarTab.allCases) { tab in
                    Text(tab.label(language: appLanguage)).tag(tab)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            switch selectedTab {
            case .reference:
                referencePanel
            case .properties:
                TextPropertiesPanel(appLanguage: appLanguage)
            }
        }
        .padding(14)
        .frame(width: 270)
        .frame(maxHeight: .infinity)
        .background(CinemaDesign.panelBackground)
    }

    private var referencePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(t(.reference), systemImage: "photo.on.rectangle")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(CinemaDesign.ink)
                Spacer()
                Button {
                    addReferenceImage()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(CinemaDesign.keyColor)
                }
                .buttonStyle(.borderless)
                .help(t(.addPhoto))
            }

            if document.project.referenceImages.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(CinemaDesign.mutedInk.opacity(0.5))
                    Text(t(.noPhotos))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CinemaDesign.mutedInk)
                    Text(t(.addPhoto))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach($document.project.referenceImages) { $reference in
                            ReferenceImageRow(
                                reference: $reference,
                                image: ImageHelpers.nsImage(from: document.imageData[reference.imageFileName]),
                                delete: {
                                    deleteReferenceImage(reference.id)
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    private func addReferenceImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            guard let data = try? Data(contentsOf: url) else { continue }
            let id = UUID()
            let fileExtension = normalizedImageExtension(from: url)
            let fileName = "Images/References/\(id.uuidString).\(fileExtension)"
            let reference = ReferenceImage(
                id: id,
                name: url.deletingPathExtension().lastPathComponent,
                imageFileName: fileName
            )
            document.project.referenceImages.append(reference)
            document.imageData[fileName] = data
        }
    }

    private func deleteReferenceImage(_ id: ReferenceImage.ID) {
        guard let index = document.project.referenceImages.firstIndex(where: { $0.id == id }) else { return }
        let reference = document.project.referenceImages.remove(at: index)
        document.imageData[reference.imageFileName] = nil
    }

    private func normalizedImageExtension(from url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        return ext.isEmpty ? "png" : ext
    }

    private func t(_ key: CinemaTextKey) -> String {
        CinemaStrings.text(key, language: appLanguage)
    }
}

private struct ReferenceImageRow: View {
    @Binding var reference: ReferenceImage
    var image: NSImage?
    var delete: () -> Void
    @State private var showsDetails = false
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.92))
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(CinemaDesign.warmBorder, lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(isHovering ? 0.10 : 0.05), radius: isHovering ? 10 : 6, y: isHovering ? 4 : 2)
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }

            HStack(spacing: 6) {
                TextField("名前", text: $reference.name)
                    .textFieldStyle(.roundedBorder)

                Button(role: .destructive, action: delete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("削除")
            }

            DisclosureGroup(isExpanded: $showsDetails) {
                referenceDetailsEditor
            } label: {
                Label("詳細情報", systemImage: "text.badge.plus")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(10)
        .cinemaPanel()
    }

    private var referenceDetailsEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(reference.details.indices, id: \.self) { sectionIndex in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("セクション", text: $reference.details[sectionIndex].title)
                            .textFieldStyle(.roundedBorder)
                            .font(.subheadline.weight(.semibold))

                        Button(role: .destructive) {
                            reference.details.remove(at: sectionIndex)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("セクションを削除")
                    }

                    ForEach(reference.details[sectionIndex].fields.indices, id: \.self) { fieldIndex in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                TextField("項目", text: $reference.details[sectionIndex].fields[fieldIndex].key)
                                    .textFieldStyle(.roundedBorder)

                                Button(role: .destructive) {
                                    reference.details[sectionIndex].fields.remove(at: fieldIndex)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .help("項目を削除")
                            }

                            TextEditor(text: $reference.details[sectionIndex].fields[fieldIndex].value)
                                .font(.system(size: 12))
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 64)
                                .padding(6)
                                .background(Color(nsColor: .textBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                                }
                        }
                    }

                    Button {
                        reference.details[sectionIndex].fields.append(DrawingSettingsField(key: "Key", value: ""))
                    } label: {
                        Label("項目を追加", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(8)
                .cinemaPanel(cornerRadius: 6)
            }

            Button {
                reference.details.append(
                    DrawingSettingsSection(
                        title: "New Section",
                        fields: [DrawingSettingsField(key: "Key", value: "")]
                    )
                )
            } label: {
                Label("セクションを追加", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.top, 4)
    }
}

private struct TextPropertiesPanel: View {
    var appLanguage: String
    @AppStorage("storyboardTextBaseFontSize") private var storyboardTextBaseFontSize = 11.0
    @AppStorage("selectedTextFontName") private var selectedTextFontName = "System"
    @AppStorage("selectedTextLetterSpacing") private var selectedTextLetterSpacing = 0.0
    @AppStorage("selectedTextLineSpacing") private var selectedTextLineSpacing = 1.0
    @AppStorage("selectedTextAlignment") private var selectedTextAlignment = TextAlignmentOption.left.rawValue
    @AppStorage("selectedTextIsBold") private var selectedTextIsBold = false
    @AppStorage("selectedTextIsItalic") private var selectedTextIsItalic = false
    @AppStorage("selectedTextIsUnderline") private var selectedTextIsUnderline = false
    @State private var selectedTextColor = Color.black

    private var fontNames: [String] {
        ["System"] + NSFontManager.shared.availableFontFamilies.sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(t(.properties), systemImage: "slider.horizontal.3")
                .font(.headline)
                .foregroundStyle(CinemaDesign.ink)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    propertySection(t(.typography)) {
                        propertyRow(t(.font)) {
                            Picker(t(.font), selection: $selectedTextFontName) {
                                ForEach(fontNames, id: \.self) { fontName in
                                    Text(fontName).tag(fontName)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                        propertyRow(t(.size)) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Stepper(
                                    "",
                                    value: $storyboardTextBaseFontSize,
                                    in: 7...24,
                                    step: 0.5
                                )
                                .labelsHidden()

                                Text("\(storyboardTextBaseFontSize, specifier: "%.1f")")
                                    .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(CinemaDesign.ink)
                                    .frame(width: 64, alignment: .trailing)
                            }
                        }

                        propertyRow(t(.textColor)) {
                            ColorPicker(t(.textColor), selection: $selectedTextColor, supportsOpacity: true)
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        propertyRow(t(.style)) {
                            HStack(spacing: 6) {
                                Toggle("B", isOn: $selectedTextIsBold)
                                    .toggleStyle(.button)
                                    .help(t(.bold))

                                Toggle("I", isOn: $selectedTextIsItalic)
                                    .toggleStyle(.button)
                                    .help(t(.italic))

                                Toggle("U", isOn: $selectedTextIsUnderline)
                                    .toggleStyle(.button)
                                    .help(t(.underline))
                            }
                        }

                        propertyRow(t(.letterSpacing)) {
                            HStack(spacing: 8) {
                                Slider(value: $selectedTextLetterSpacing, in: -2...8, step: 0.5)
                                Text("\(selectedTextLetterSpacing, specifier: "%.1f")")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }

                        propertyRow(t(.lineSpacing)) {
                            HStack(spacing: 8) {
                                Slider(value: $selectedTextLineSpacing, in: 0.8...2.4, step: 0.1)
                                Text("\(selectedTextLineSpacing, specifier: "%.1f")")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            Text(t(.alignment))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(CinemaDesign.mutedInk)

                            Picker(t(.alignment), selection: $selectedTextAlignment) {
                                ForEach(TextAlignmentOption.allCases) { option in
                                    Image(systemName: option.systemImageName).tag(option.rawValue)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }

                        Button {
                            applyTextStyle()
                        } label: {
                            Label(t(.applyToSelection), systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func propertySection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CinemaDesign.ink)

            content()
        }
        .padding(10)
        .cinemaPanel()
    }

    private func propertyRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(CinemaDesign.mutedInk)

            content()
        }
    }

    private func applyTextStyle() {
        let alignmentOption = TextAlignmentOption(rawValue: selectedTextAlignment) ?? .left
        let color = NSColor(selectedTextColor).usingColorSpace(.sRGB) ?? .black
        TextSelectionStyleApplicator.apply(
            TextSelectionStyle(
                fontFamily: selectedTextFontName,
                fontSize: CGFloat(storyboardTextBaseFontSize),
                color: color,
                isBold: selectedTextIsBold,
                isItalic: selectedTextIsItalic,
                isUnderline: selectedTextIsUnderline,
                letterSpacing: CGFloat(selectedTextLetterSpacing),
                lineSpacing: CGFloat(selectedTextLineSpacing),
                alignment: alignmentOption.nsTextAlignment
            )
        )
    }

    private func t(_ key: CinemaTextKey) -> String {
        CinemaStrings.text(key, language: appLanguage)
    }
}

private enum TextAlignmentOption: String, CaseIterable, Identifiable {
    case left
    case center
    case right
    case justified

    var id: String { rawValue }

    var systemImageName: String {
        switch self {
        case .left:
            return "text.alignleft"
        case .center:
            return "text.aligncenter"
        case .right:
            return "text.alignright"
        case .justified:
            return "text.justify"
        }
    }

    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .left:
            return .left
        case .center:
            return .center
        case .right:
            return .right
        case .justified:
            return .justified
        }
    }
}
