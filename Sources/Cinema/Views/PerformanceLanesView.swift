import SwiftUI

/// All lanes share the scene clock; each overlapping clip remains visible on its own row.
struct PerformanceLanesView: View {
    @Binding var project: StoryboardProject
    var sceneID: UUID
    var language: String
    var playhead: Double = 0
    var previewDuration: Double = 0
    var onSeek: ((Double) -> Void)? = nil
    @State private var selectedAsset: UUID?
    private func t(_ ja: String, _ en: String, _ zh: String) -> String { language == "en" ? en : language == "zh-Hans" ? zh : ja }
    private func title(_ lane: PerformanceAudioLane) -> String {
        lane == .music ? t("音楽", "Music", "音乐") : t("環境音", "Ambience", "环境音")
    }
    private var duration: Double {
        max(1, previewDuration, max(project.performancePlan.cues.filter { $0.sceneID == sceneID }.map { $0.end.seconds }.max() ?? 0,
                   project.performancePlan.audioClips.filter { $0.sceneID == sceneID }.map { $0.end.seconds }.max() ?? 0))
    }
    private func time(_ binding: Binding<PerformanceTime>) -> Binding<Double> {
        Binding(get: { binding.wrappedValue.seconds }, set: { binding.wrappedValue.seconds = $0 })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("シーン音声レーン", "Scene Audio Lanes", "场景音频轨道")).font(.headline)
            Text(t("時刻はシーンの先頭からの秒数です。配置音声のミュート・ソロは書き出しにも適用します。ソロは複数選べ、ミュートを優先します。プレビュー準備後はバーをクリックして移動できます。", "Times are scene-relative. Mute and solo affect placed audio in previews and exports. Multiple solos are allowed; mute takes priority. Click a bar to seek after preparing the preview.", "时间以场景起点为基准。静音与独奏应用于安排的音频试听和导出。可选择多个独奏轨道，静音优先。预览准备后可点击时间条调整位置。")).font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("0 s"); Spacer(); Text(String(format: "%.2f s", duration))
            }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12)
            laneHeader(.dialogue)
            ForEach(project.performancePlan.cues.filter { $0.sceneID == sceneID }) { cue in
                let line = project.cuts.first { $0.id == cue.cutID }?.dialogueLines.first { $0.id == cue.dialogueID }
                interval(label: line?.speaker.isEmpty == false ? line!.speaker : t("発話", "Dialogue", "对白"), start: cue.start.seconds, end: cue.end.seconds, color: .accentColor, lane: .dialogue).padding(.horizontal, 12)
            }
            Picker(t("配置する素材", "Audio to Place", "安排的音频"), selection: $selectedAsset) {
                Text(t("素材を選択", "Choose Audio", "选择音频")).tag(Optional<UUID>.none)
                ForEach(project.performancePlan.audioAssets) { asset in Text(asset.name).tag(Optional(asset.id)) }
            }
            ForEach(PerformanceAudioLane.allCases, id: \.self) { lane in
                HStack {
                    laneHeader(lane == .music ? .music : .ambience); Spacer()
                    Button(t("追加", "Add", "添加")) {
                        guard let asset = project.performancePlan.audioAssets.first(where: { $0.id == selectedAsset }) else { return }
                        project.performancePlan.audioClips.append(PerformanceAudioClip(sceneID: sceneID, audioAssetID: asset.id, lane: lane, end: asset.duration))
                    }.disabled(!project.performancePlan.audioAssets.contains { $0.id == selectedAsset })
                }
                ForEach($project.performancePlan.audioClips) { $clip in
                    if clip.sceneID == sceneID && clip.lane == lane {
                        clipEditor($clip, lane: lane)
                    }
                }
            }
        }
    }
    private func laneHeader(_ lane: PerformanceMixLane) -> some View {
        HStack(spacing: 12) {
            Text(lane == .dialogue ? t("発話", "Dialogue", "对白") : title(lane == .music ? .music : .ambience)).font(.subheadline.bold())
            Toggle(t("ミュート", "Mute", "静音"), isOn: laneFlag(lane, solo: false))
                .toggleStyle(PerformanceLaneToggleStyle(color: .orange, onText: t("オン", "On", "开启"), offText: t("オフ", "Off", "关闭")))
            Toggle(t("ソロ", "Solo", "独奏"), isOn: laneFlag(lane, solo: true))
                .toggleStyle(PerformanceLaneToggleStyle(color: .accentColor, onText: t("オン", "On", "开启"), offText: t("オフ", "Off", "关闭")))
        }.controlSize(.small)
    }
    private func laneFlag(_ lane: PerformanceMixLane, solo: Bool) -> Binding<Bool> {
        Binding(get: {
            let state = project.performancePlan.laneStates.first { $0.sceneID == sceneID && $0.lane == lane }
            return solo ? state?.isSolo ?? false : state?.isMuted ?? false
        }, set: { value in
            if let index = project.performancePlan.laneStates.firstIndex(where: { $0.sceneID == sceneID && $0.lane == lane }) {
                if solo { project.performancePlan.laneStates[index].isSolo = value } else { project.performancePlan.laneStates[index].isMuted = value }
                if !project.performancePlan.laneStates[index].isSolo && !project.performancePlan.laneStates[index].isMuted { project.performancePlan.laneStates.remove(at: index) }
            } else if value {
                project.performancePlan.laneStates.append(PerformanceLaneState(sceneID: sceneID, lane: lane, isMuted: !solo, isSolo: solo))
            }
        })
    }

    private func clipEditor(_ binding: Binding<PerformanceAudioClip>, lane: PerformanceAudioLane) -> some View {
        let clip = binding.wrappedValue
        let asset = project.performancePlan.audioAssets.first { $0.id == clip.audioAssetID }
        return VStack(alignment: .leading, spacing: 8) {
            interval(label: asset?.name ?? t("素材なし", "Missing Audio", "缺少音频"), start: clip.start.seconds, end: clip.end.seconds, color: lane == .music ? .purple : .teal, lane: lane == .music ? .music : .ambience)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    timingField(t("開始秒", "Start (s)", "开始秒"), value: binding.start)
                    timingField(t("終了秒", "End (s)", "结束秒"), value: binding.end)
                    timingField(t("素材開始秒", "Source Offset (s)", "素材开始秒"), value: binding.sourceOffset)
                }
                VStack(alignment: .leading, spacing: 8) {
                    timingField(t("開始秒", "Start (s)", "开始秒"), value: binding.start)
                    timingField(t("終了秒", "End (s)", "结束秒"), value: binding.end)
                    timingField(t("素材開始秒", "Source Offset (s)", "素材开始秒"), value: binding.sourceOffset)
                }
            }
            if asset == nil || clip.end.ticks <= clip.start.ticks || clip.sourceOffset.seconds + clip.end.seconds - clip.start.seconds > (asset?.duration.seconds ?? 0) {
                Text(t("終了を開始より後にして、使用区間を素材の長さ内に収めてください。", "End must follow start and the source range must fit within the audio.", "结束必须晚于开始，使用区间必须在音频长度内。")).font(.caption).foregroundStyle(.orange)
            }
            PerformanceMixView(mix: binding.mix, start: clip.start, end: clip.end, language: language)
            Button(t("配置を削除", "Remove Placement", "删除安排"), role: .destructive) { project.performancePlan.audioClips.removeAll { $0.id == clip.id } }
        }.padding(12).background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }

    private func timingField(_ label: String, value: Binding<PerformanceTime>) -> some View {
        HStack {
            Text(label).fixedSize()
            TextField("0", value: time(value), format: .number).frame(width: 80)
        }.textFieldStyle(.roundedBorder)
    }

    private func interval(label: String, start: Double, end: Double, color: Color, lane: PerformanceMixLane) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label + String(format: " · %.2f–%.2f s", start, end)).font(.caption).lineLimit(2)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                    let x = min(max(start / duration, 0), 1) * geometry.size.width
                    RoundedRectangle(cornerRadius: 4).fill(color.opacity(project.performancePlan.laneIsAudible(lane, sceneID: sceneID) ? 1 : 0.25))
                        .frame(width: max(2, min(max((end - start) / duration, 0) * geometry.size.width, geometry.size.width - x)))
                        .offset(x: x)
                    Rectangle().fill(.primary).frame(width: 2)
                        .offset(x: min(max(playhead / duration, 0), 1) * max(geometry.size.width - 2, 0))
                }.contentShape(Rectangle()).onTapGesture { location in
                    onSeek?(min(max(location.x / max(geometry.size.width, 1), 0), 1) * duration)
                }
            }.frame(height: 16).accessibilityLabel(label + String(format: " %.2f–%.2f s", start, end))
        }
    }
}

private struct PerformanceLaneToggleStyle: ToggleStyle {
    var color: Color
    var onText: String
    var offText: String
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 4) {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle").foregroundStyle(color)
                configuration.label.foregroundStyle(.primary)
            }.font(.caption.weight(.semibold)).fixedSize()
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(configuration.isOn ? color.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                .overlay { RoundedRectangle(cornerRadius: 6).stroke(color.opacity(configuration.isOn ? 1 : 0.5), lineWidth: 1) }
        }.buttonStyle(.plain).accessibilityValue(configuration.isOn ? onText : offText)
    }
}
