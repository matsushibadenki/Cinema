import SwiftUI

struct PerformanceLoopView: View {
    @ObservedObject var playback: PerformancePreviewPlayer
    var project: StoryboardProject
    var sceneID: UUID
    var language: String
    @State private var start: Double = 0
    @State private var end: Double = 1
    @State private var selectedCue: UUID?
    private func t(_ ja: String, _ en: String, _ zh: String) -> String { language == "en" ? en : language == "zh-Hans" ? zh : ja }
    private var range: PreviewLoopRange { PreviewLoopRange(start: start, end: end) }
    private var valid: Bool { range.isValid(duration: playback.duration) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(t("指定区間を繰り返す", "Repeat Selected Range", "循环播放指定区间"), isOn: Binding(get: { playback.loopRange != nil }, set: { enabled in
                if enabled { try? playback.setLoopRange(range) } else { try? playback.setLoopRange(nil) }
            })).disabled(!playback.isReady || !valid)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { startField; endField }
                VStack(alignment: .leading, spacing: 8) { startField; endField }
            }
            HStack {
                Button(t("現在位置を開始に", "Set Start Here", "设为起点")) { start = playback.position }
                Button(t("現在位置を終了に", "Set End Here", "设为终点")) { end = playback.position }
            }.disabled(!playback.isReady)
            Picker(t("発話から区間を選ぶ", "Range from Dialogue", "从对白选择区间"), selection: $selectedCue) {
                Text(t("手動指定", "Manual Range", "手动指定")).tag(Optional<UUID>.none)
                ForEach(project.performancePlan.cues.filter { $0.sceneID == sceneID }) { cue in
                    let line = project.cuts.first { $0.id == cue.cutID }?.dialogueLines.first { $0.id == cue.dialogueID }
                    Text("\(line?.speaker ?? "") · \(line?.dialogue ?? "")").lineLimit(1).tag(Optional(cue.id))
                }
            }.disabled(!playback.isReady)
            if playback.isReady && !valid {
                Text(t("開始・終了をプレビューの長さ内に設定し、区間を0.05秒以上にしてください。", "Set a range of at least 0.05 seconds within the preview duration.", "请在预览时长内设置至少0.05秒的区间。")).font(.caption).foregroundStyle(.orange)
            }
            Text(t("プレビュー専用です。発話を選ぶと前後0.2秒を含めます。編集やテイク切り替えで解除します。", "Preview only. Dialogue selection includes 0.2 seconds before and after. Editing or changing takes clears the range.", "仅用于预览。选择对白时包括前后0.2秒。编辑或切换版本后清除区间。")).font(.caption).foregroundStyle(.secondary)
        }.onAppear {
            start = playback.loopRange?.start ?? 0
            end = playback.loopRange?.end ?? playback.duration
        }.onChange(of: playback.duration) { _, duration in start = 0; end = duration; selectedCue = nil }
            .onChange(of: start) { _, _ in updateLoop() }
            .onChange(of: end) { _, _ in updateLoop() }
            .onChange(of: selectedCue) { _, id in
                guard let cue = project.performancePlan.cues.first(where: { $0.id == id && $0.sceneID == sceneID }) else { return }
                start = max(0, cue.start.seconds - 0.2); end = min(playback.duration, cue.end.seconds + 0.2)
            }
    }
    private var startField: some View {
        HStack { Text(t("開始秒", "Start (s)", "开始秒")).fixedSize(); TextField("0", value: $start, format: .number).frame(width: 90) }.textFieldStyle(.roundedBorder).disabled(!playback.isReady)
    }
    private var endField: some View {
        HStack { Text(t("終了秒", "End (s)", "结束秒")).fixedSize(); TextField("0", value: $end, format: .number).frame(width: 90) }.textFieldStyle(.roundedBorder).disabled(!playback.isReady)
    }
    private func updateLoop() {
        guard playback.loopRange != nil else { return }
        if valid { try? playback.setLoopRange(range) }
        else { playback.pause(); try? playback.setLoopRange(nil) }
    }
}
