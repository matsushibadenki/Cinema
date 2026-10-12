import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PerformancePlanView: View {
    @Binding var project: StoryboardProject
    @Binding var audioData: [String: Data]
    @Binding var videoData: [String: Data]
    var documentURL: URL?
    var language: String
    var isEmbedded = false
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    private func t(_ ja: String, _ en: String, _ zh: String) -> String { language == "en" ? en : language == "zh-Hans" ? zh : ja }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if !isEmbedded { Text(t("声・演技タイムライン", "Voice / Performance Timeline", "声音与表演时间线")).font(.title2) }
                Spacer()
                Button(t("計画を書き出す", "Export Plan", "导出计划")) { exportPlan() }
                if !isEmbedded { Button(t("閉じる", "Close", "关闭")) { dismiss() } }
            }
            Text(t("人物の声を作品全体で共有し、発話位置をシーンの先頭から秒で指定します。カット境界をまたぐ発話も設定できます。確定音声を読み込み、配置した音声や音声付きシーン動画を書き出せます。AI音声生成・口形補正は未対応です。", "Share character voices across the project and set dialogue timing in seconds from the scene start, including speech across cut boundaries. Import locked audio and export the placed audio or a mixed scene video. AI audio generation and lip-sync correction are not implemented.", "在整个项目中共享人物声音，并设置相对于场景起点的对白时间，允许跨镜头发声。可导入确定的音频并导出安排的音频或混合场景视频。尚不支持AI音频生成与口型修正。")).font(.callout).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.red) }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text(t("作品共通の人物・声", "Project Characters / Voices", "项目人物与声音")).font(.headline)
                        Spacer()
                        Button(t("人物を追加", "Add Character", "添加人物")) { project.performancePlan.characters.append(ProjectCharacter()) }
                    }
                    ForEach($project.performancePlan.characters) { $character in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField(t("人物名", "Name", "人物名"), text: $character.name)
                            HStack {
                                TextField("Provider", text: $character.voiceProvider)
                                TextField("Model", text: $character.voiceModel)
                                TextField("Voice ID", text: $character.voiceID)
                            }
                            TextField(t("話し方・アクセント", "Speaking Style / Accent", "说话风格与口音"), text: $character.speakingStyle)
                            Button(t("人物を削除", "Remove Character", "删除人物"), role: .destructive) {
                                let id = character.id
                                project.performancePlan.characters.removeAll { $0.id == id }
                                for index in project.performancePlan.cues.indices where project.performancePlan.cues[index].characterID == id { project.performancePlan.cues[index].characterID = nil }
                            }
                        }.textFieldStyle(.roundedBorder).padding(16).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                    }
                    Divider()
                    PerformanceAudioView(project: $project, audioData: $audioData, videoData: $videoData, documentURL: documentURL, language: language)
                    Divider()
                    Text(t("発話の配置", "Dialogue Placement", "对白安排")).font(.headline)
                    ForEach(project.cuts) { cut in
                        ForEach(cut.dialogueLines.filter { !$0.dialogue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { line in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(cut.cutNumber) · \(line.speaker) · \(line.dialogue)").lineLimit(3)
                                if let index = project.performancePlan.cues.firstIndex(where: { $0.dialogueID == line.id }) {
                                    cueEditor(index)
                                } else {
                                    Button(t("タイムラインに追加", "Add to Timeline", "添加到时间线")) {
                                        guard let sceneID = cut.sceneID else { return }
                                        project.performancePlan.cues.append(PerformanceCue(sceneID: sceneID, cutID: cut.id, dialogueID: line.id))
                                    }.disabled(cut.sceneID == nil)
                                }
                            }.padding(16).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    if project.cuts.allSatisfy({ $0.dialogueLines.allSatisfy { $0.dialogue.isEmpty } }) { Text(t("脚本にセリフを入力すると配置できます。", "Enter dialogue in the script to add cues.", "在剧本中输入对白后即可安排。" )).foregroundStyle(.secondary) }
                }.padding(.horizontal, 16)
            }
        }.padding(16).frame(width: isEmbedded ? nil : 740, height: isEmbedded ? nil : 660)
    }

    private func cueEditor(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker(t("人物", "Character", "人物"), selection: $project.performancePlan.cues[index].characterID) {
                    Text(t("未割り当て", "Unassigned", "未分配")).tag(Optional<UUID>.none)
                    ForEach(project.performancePlan.characters) { Text($0.name).tag(Optional($0.id)) }
                }
                Picker(t("制作方式", "Workflow", "制作方式"), selection: $project.performancePlan.cues[index].mode) {
                    Text(t("動画の音声を使用", "Native Audio", "视频原生音频")).tag(PerformanceProductionMode.nativeAudio)
                    Text(t("音声を先に確定", "Audio First", "音频优先")).tag(PerformanceProductionMode.audioFirst)
                    Text(t("映像を先に制作", "Video First", "视频优先")).tag(PerformanceProductionMode.videoFirst)
                }
            }
            HStack {
                Text(t("開始秒", "Start (s)", "开始秒"))
                TextField("0", value: seconds(index, end: false), format: .number).frame(width: 100)
                Text(t("終了秒", "End (s)", "结束秒"))
                TextField("0", value: seconds(index, end: true), format: .number).frame(width: 100)
                Spacer()
                Button(t("配置を削除", "Remove Cue", "删除安排")) { project.performancePlan.cues.remove(at: index) }
            }
            Picker(t("確定音声", "Locked Audio", "确定音频"), selection: $project.performancePlan.cues[index].audioAssetID) {
                Text(t("なし", "None", "无")).tag(Optional<UUID>.none)
                ForEach(project.performancePlan.audioAssets) { Text($0.name).tag(Optional($0.id)) }
            }
            HStack {
                Text(t("音声素材の開始秒", "Source Offset (s)", "音频素材起点秒"))
                TextField("0", value: Binding(get: { project.performancePlan.cues[index].sourceOffset?.seconds ?? 0 }, set: { value in
                    var time = PerformanceTime(); time.seconds = value; project.performancePlan.cues[index].sourceOffset = time
                }), format: .number).frame(width: 100)
            }
            PerformanceMixView(mix: $project.performancePlan.cues[index].mix, start: project.performancePlan.cues[index].start, end: project.performancePlan.cues[index].end, language: language)
                .disabled(project.performancePlan.cues[index].audioAssetID == nil)
            TextField(t("呼吸・感情・視線・同期の指示", "Breath / Emotion / Gaze / Sync Notes", "呼吸、情绪、视线与同步说明"), text: $project.performancePlan.cues[index].notes)
            if project.performancePlan.cues[index].end.ticks <= project.performancePlan.cues[index].start.ticks {
                Text(t("終了は開始より後にしてください。", "End must be after start.", "结束时间必须晚于开始时间。")).font(.caption).foregroundStyle(.orange)
            }
        }.textFieldStyle(.roundedBorder)
    }

    private func seconds(_ index: Int, end: Bool) -> Binding<Double> {
        Binding(get: { end ? project.performancePlan.cues[index].end.seconds : project.performancePlan.cues[index].start.seconds }, set: { value in
            if end { project.performancePlan.cues[index].end.seconds = value } else { project.performancePlan.cues[index].start.seconds = value }
            project.performancePlan.cues[index].revision += 1
        })
    }

    private func exportPlan() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "performance-plan.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(PerformancePlanExport(project: project)).write(to: url, options: .atomic)
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}
