import SwiftUI

struct DrawingSettingsView: View {
    @Binding var settings: DrawingSettings

    private var selectedPresetIndex: Int? {
        settings.presets.firstIndex { $0.id == settings.selectedPresetID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let index = selectedPresetIndex {
                        presetEditor(index: index)
                    } else {
                        Text("プリセットがありません")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(24)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            settings.ensureSelection()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("描画設定")
                .font(.title2.weight(.semibold))

            Picker("プリセット", selection: $settings.selectedPresetID) {
                ForEach(settings.presets) { preset in
                    Text(preset.name).tag(preset.id)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 220)

            Button {
                duplicateSelectedPreset()
            } label: {
                Label("複製", systemImage: "doc.on.doc")
            }

            Button {
                addPreset()
            } label: {
                Label("新規", systemImage: "plus")
            }

            Button(role: .destructive) {
                deleteSelectedPreset()
            } label: {
                Label("削除", systemImage: "trash")
            }
            .disabled(!canDeleteSelectedPreset)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func presetEditor(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("プリセット名")
                    .font(.headline)

                TextField("プリセット名", text: $settings.presets[index].name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 16))
                    .frame(maxWidth: 360)
            }

            ForEach(settings.presets[index].sections.indices, id: \.self) { sectionIndex in
                sectionEditor(presetIndex: index, sectionIndex: sectionIndex)
            }

            Button {
                settings.presets[index].sections.append(
                    DrawingSettingsSection(
                        title: "New Section",
                        fields: [DrawingSettingsField(key: "Key", value: "")]
                    )
                )
            } label: {
                Label("セクションを追加", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.bordered)
        }
    }

    private func sectionEditor(presetIndex: Int, sectionIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("セクション名", text: $settings.presets[presetIndex].sections[sectionIndex].title)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: 360)

                Spacer()

                Button(role: .destructive) {
                    settings.presets[presetIndex].sections.remove(at: sectionIndex)
                } label: {
                    Label("削除", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }

            ForEach(settings.presets[presetIndex].sections[sectionIndex].fields.indices, id: \.self) { fieldIndex in
                fieldEditor(presetIndex: presetIndex, sectionIndex: sectionIndex, fieldIndex: fieldIndex)
            }

            Button {
                settings.presets[presetIndex].sections[sectionIndex].fields.append(DrawingSettingsField(key: "Key", value: ""))
            } label: {
                Label("項目を追加", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.8)
        }
    }

    private func fieldEditor(presetIndex: Int, sectionIndex: Int, fieldIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                TextField("項目名", text: $settings.presets[presetIndex].sections[sectionIndex].fields[fieldIndex].key)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)

                Spacer()

                Button(role: .destructive) {
                    settings.presets[presetIndex].sections[sectionIndex].fields.remove(at: fieldIndex)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .help("項目を削除")
            }

            TextEditor(text: $settings.presets[presetIndex].sections[sectionIndex].fields[fieldIndex].value)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 88)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.6)
                }
        }
    }

    private var canDeleteSelectedPreset: Bool {
        guard settings.presets.count > 1,
              let index = selectedPresetIndex else {
            return false
        }
        return !settings.presets[index].isBuiltin
    }

    private func duplicateSelectedPreset() {
        guard let index = selectedPresetIndex else { return }
        let preset = settings.presets[index].duplicatedForUser()
        settings.presets.append(preset)
        settings.selectedPresetID = preset.id
    }

    private func addPreset() {
        let preset = DrawingPreset(
            name: "カスタム",
            isBuiltin: false,
            sections: [
                DrawingSettingsSection(title: "Character", fields: [
                    DrawingSettingsField(key: "Subject", value: "")
                ]),
                DrawingSettingsSection(title: "Scene", fields: [
                    DrawingSettingsField(key: "Environment", value: "")
                ]),
                DrawingSettingsSection(title: "Photography", fields: [
                    DrawingSettingsField(key: "Style", value: "")
                ])
            ]
        )
        settings.presets.append(preset)
        settings.selectedPresetID = preset.id
    }

    private func deleteSelectedPreset() {
        guard canDeleteSelectedPreset,
              let index = selectedPresetIndex else {
            return
        }
        settings.presets.remove(at: index)
        settings.ensureSelection()
    }
}
