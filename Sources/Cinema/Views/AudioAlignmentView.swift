import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AudioAlignmentView: View {
    @Binding var asset: PerformanceAudioAsset
    var data: Data?
    var language: String
    @State private var peaks: [Float] = []
    @State private var error: String?
    @State private var expanded = false
    private func t(_ ja: String, _ en: String, _ zh: String) -> String { language == "en" ? en : language == "zh-Hans" ? zh : ja }
    private var segments: Binding<[AudioAlignmentSegment]> {
        Binding(get: { asset.alignment ?? [] }, set: { asset.alignment = $0 })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Canvas { context, size in
                let mid = size.height / 2
                for (index, peak) in peaks.enumerated() {
                    let x = CGFloat(index) / CGFloat(max(peaks.count, 1)) * size.width
                    let height = max(1, CGFloat(peak) * mid)
                    var path = Path(); path.move(to: CGPoint(x: x, y: mid - height)); path.addLine(to: CGPoint(x: x, y: mid + height))
                    context.stroke(path, with: .color(.accentColor), lineWidth: 1.5)
                }
            }.frame(height: 64).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                .accessibilityLabel(t("音声波形", "Audio Waveform", "音频波形"))
            HStack {
                Text("0 s").font(.caption)
                Spacer()
                Text(String(format: "%.2f s", asset.duration.seconds)).font(.caption)
            }
            DisclosureGroup(t("音素・口形・演技タイミング", "Phoneme / Viseme / Performance Timing", "音素、口型与表演时间"), isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(t("時刻は元の音声素材の先頭からの秒数です。手動編集・JSON読み込み用のデータで、口形補正を実行する機能ではありません。", "Times are seconds from the original audio start. Edit manually or import JSON; these annotations do not apply lip-sync correction.", "时间以原始音频起点为基准。可手动编辑或导入JSON，这些标注不执行口型修正。")).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(t("区間を追加", "Add Segment", "添加区间")) { segments.wrappedValue.append(AudioAlignmentSegment()) }
                        Button(t("JSON読み込み", "Import JSON", "导入JSON")) { importJSON() }
                        Button(t("JSON書き出し", "Export JSON", "导出JSON")) { exportJSON() }
                    }
                    ForEach(segments) { $segment in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                TextField(t("音素", "Phoneme", "音素"), text: $segment.phoneme)
                                TextField(t("口形", "Viseme", "口型"), text: $segment.viseme)
                                Button(t("削除", "Remove", "删除")) { segments.wrappedValue.removeAll { $0.id == segment.id } }
                            }
                            HStack {
                                Text(t("開始秒", "Start (s)", "开始秒"))
                                TextField("0", value: time($segment.start), format: .number)
                                Text(t("終了秒", "End (s)", "结束秒"))
                                TextField("0", value: time($segment.end), format: .number)
                            }
                            TextField(t("呼吸・表情・演技", "Breath / Expression / Performance", "呼吸、表情与表演"), text: $segment.performance)
                            if segment.end.ticks <= segment.start.ticks || segment.end.ticks > asset.duration.ticks {
                                Text(t("素材の長さ内で、終了を開始より後にしてください。", "End must follow start and fit within the audio duration.", "结束必须晚于开始且不超过音频长度。")).font(.caption).foregroundStyle(.orange)
                            }
                        }.textFieldStyle(.roundedBorder).padding(8).background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                    }
                }.padding(.vertical, 8)
            }
            if let error { Text(error).font(.caption).foregroundStyle(.secondary) }
        }
        .task(id: asset.id) {
            guard let data else { error = t("音声素材が見つかりません。", "Audio asset is missing.", "找不到音频素材。"); return }
            let ext = URL(fileURLWithPath: asset.fileName).pathExtension
            let worker = Task.detached(priority: .utility) { () throws -> [Float] in
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
                defer { try? FileManager.default.removeItem(at: url) }
                try data.write(to: url, options: .atomic)
                return try AudioWaveformService.peaks(at: url)
            }
            do { peaks = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() }) }
            catch { if !Task.isCancelled { self.error = t("波形を読み込めませんでした。", "Could not load waveform.", "无法加载波形。") } }
        }
    }
    private func time(_ value: Binding<PerformanceTime>) -> Binding<Double> {
        Binding(get: { value.wrappedValue.seconds }, set: { value.wrappedValue.seconds = $0 })
    }
    private func alignment() -> AudioAlignmentFile { AudioAlignmentFile(audioAssetID: asset.id, segments: segments.wrappedValue) }
    private func importJSON() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let file = try JSONDecoder().decode(AudioAlignmentFile.self, from: Data(contentsOf: url))
            try file.validate(for: asset)
            segments.wrappedValue = file.segments.sorted { $0.start.ticks < $1.start.ticks }; error = nil
        } catch { self.error = t("読み込みに失敗しました：", "Import failed: ", "导入失败：") + error.localizedDescription }
    }
    private func exportJSON() {
        do {
            let file = alignment(); try file.validate(for: asset)
            let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "audio-alignment.json"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(file).write(to: url, options: .atomic); error = nil
        } catch { self.error = t("書き出しに失敗しました：", "Export failed: ", "导出失败：") + error.localizedDescription }
    }
}
