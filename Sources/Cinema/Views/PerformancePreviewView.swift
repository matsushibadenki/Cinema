import SwiftUI

struct PerformancePreviewView: View {
    var project: StoryboardProject
    var sceneID: UUID
    var audioData: [String: Data]
    var language: String
    var videoData: [String: Data] = [:]
    var documentURL: URL? = nil
    var keepNativeAudio = false
    var onPlay: () -> Void = {}
    @ObservedObject var playback: PerformancePreviewPlayer
    @State var includeVideo = false
    @State var selectedVideoID: UUID? = nil
    @State private var stepping: Task<Void, Never>?
    @State private var preparation: Task<Void, Never>?
    @State private var scrubbing = false
    @State private var seekPosition: Double = 0
    private func t(_ ja: String, _ en: String, _ zh: String) -> String { language == "en" ? en : language == "zh-Hans" ? zh : ja }
    private var hasAudio: Bool {
        project.performancePlan.cues.contains { $0.sceneID == sceneID && $0.audioAssetID != nil } || project.performancePlan.audioClips.contains { $0.sceneID == sceneID }
    }
    private var videoTakes: [SceneVideo] { project.sceneVideos.filter { $0.sceneID == sceneID }.sorted { $0.generatedAt > $1.generatedAt } }
    private var hasSceneVideo: Bool { project.sceneVideos.contains { $0.sceneID == sceneID } }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("シーン映像・音声プレビュー", "Scene Video / Audio Preview", "场景视频与音频预览")).font(.headline)
            Text(t("配置した発話・音楽・環境音を、音量・フェード付きで確認できます。動画モードでは選択したシーン動画と同期再生します。口形補正は行いません。編集すると再生をリセットします。", "Preview placed dialogue, music and ambience with volume and fades. Video mode plays the selected scene video in sync. No lip-sync correction is applied. Editing resets playback.", "预览安排的对白、音乐与环境音，包括音量与淡入淡出。视频模式同步播放选定的场景视频，不执行口型修正。编辑后重置播放。")).font(.caption).foregroundStyle(.secondary)
            Picker(t("プレビュー方式", "Preview Mode", "预览模式"), selection: $includeVideo) {
                Text(t("音声のみ", "Audio Only", "仅音频")).tag(false)
                Text(t("動画と音声", "Video and Audio", "视频与音频")).tag(true).disabled(!hasSceneVideo)
            }.pickerStyle(.segmented)
            if includeVideo {
                Picker(t("動画テイク", "Video Take", "视频版本"), selection: $selectedVideoID) {
                    Text(t("最新のテイク", "Latest Take", "最新版本")).tag(Optional<UUID>.none)
                    ForEach(Array(videoTakes.enumerated()), id: \.element.id) { index, take in
                        Text(takeLabel(take, index: index)).tag(Optional(take.id))
                    }
                }
                ZStack {
                    PerformanceVideoSurface(player: playback.videoPlayer)
                    if !playback.hasVideo {
                        Text(t("再生するとシーン動画を準備します。", "Press Play to prepare the scene video.", "点击播放以准备场景视频。")).font(.caption).foregroundStyle(.white).padding(16)
                    }
                }.frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityLabel(t("シーン動画", "Scene Video", "场景视频"))
                Text(keepNativeAudio ? t("元動画の音声も再生します。", "Original video audio is also included.", "同时播放原视频音频。") : t("元動画の音声は再生しません。", "Original video audio is excluded.", "不播放原视频音频。")).font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Button(playback.isPlaying ? t("一時停止", "Pause", "暂停") : t("再生", "Play", "播放")) { togglePlayback() }
                    .buttonStyle(CinemaPrimaryActionButtonStyle()).disabled((includeVideo ? !hasSceneVideo : !hasAudio) || playback.isPreparing || playback.isStepping)
                Button(t("停止", "Stop", "停止")) {
                    stepping?.cancel(); stepping = nil
                    if playback.isPreparing { reset() } else { playback.stop() }
                }.disabled(!playback.isReady && !playback.isPreparing)
                if playback.isPreparing { ProgressView().controlSize(.small) }
                Spacer()
                Text(String(format: "%.3f / %.3f s", scrubbing ? seekPosition : playback.position, playback.duration)).font(.caption).monospacedDigit()
            }
            if includeVideo {
                HStack {
                    Button(t("1コマ戻る", "Previous Frame", "上一帧")) { step(forward: false) }
                    Button(t("1コマ進む", "Next Frame", "下一帧")) { step(forward: true) }
                    if playback.isStepping { ProgressView().controlSize(.small) }
                }.disabled(!playback.isReady || !playback.hasVideo || playback.isStepping)
            }
            Slider(value: Binding(get: { scrubbing ? seekPosition : playback.position }, set: { seekPosition = $0; if !scrubbing { playback.seek(to: $0) } }), in: 0...max(playback.duration, 0.001), onEditingChanged: { editing in
                if editing { seekPosition = playback.position; scrubbing = true }
                else { playback.seek(to: seekPosition); scrubbing = false }
            }).disabled(!playback.isReady).accessibilityLabel(t("再生位置", "Playback Position", "播放位置"))
            PerformanceLoopView(playback: playback, project: project, sceneID: sceneID, language: language)
            if let error = playback.error { Text(t("プレビューに失敗しました：", "Preview failed: ", "预览失败：") + error).font(.caption).foregroundStyle(.red) }
        }.padding(16).background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
            .onChange(of: project) { _, _ in
                if let selectedVideoID, !videoTakes.contains(where: { $0.id == selectedVideoID }) { self.selectedVideoID = nil }
                reset()
            }
            .onChange(of: audioData) { _, _ in reset() }
            .onChange(of: videoData) { _, _ in reset() }
            .onChange(of: documentURL) { _, _ in reset() }
            .onChange(of: keepNativeAudio) { _, _ in reset() }
            .onChange(of: includeVideo) { _, _ in reset() }
            .onChange(of: selectedVideoID) { _, _ in reset() }
            .onChange(of: hasSceneVideo) { _, exists in if !exists { includeVideo = false }; reset() }
            .onChange(of: sceneID) { _, _ in selectedVideoID = nil; reset() }
            .onDisappear { reset() }
    }
    private func togglePlayback() {
        if playback.isPlaying { playback.pause(); return }
        onPlay()
        if playback.isReady { playback.play(); return }
        preparation?.cancel()
        let snapshot = project; let bytes = audioData; let scene = sceneID
        let videos = videoData; let location = documentURL; let videoMode = includeVideo; let native = keepNativeAudio; let take = selectedVideoID
        preparation = Task { @MainActor in
            do {
                try await playback.prepare(project: snapshot, sceneID: scene, audioData: bytes, videoData: videos, documentURL: location, includeVideo: videoMode, keepNativeAudio: native, selectedVideoID: take)
                try Task.checkCancellation()
                playback.play()
            } catch { /* The transport publishes preparation errors; cancellation is silent. */ }
        }
    }
    private func takeLabel(_ take: SceneVideo, index: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language == "en" ? "en_US" : language == "zh-Hans" ? "zh_CN" : "ja_JP")
        formatter.dateStyle = .short; formatter.timeStyle = .medium
        return "\(index + 1) · \(take.title) · \(formatter.string(from: take.generatedAt))"
    }
    private func step(forward: Bool) {
        stepping?.cancel()
        stepping = Task { @MainActor in
            do { try await playback.stepFrame(forward: forward) } catch { }
        }
    }
    private func reset() { stepping?.cancel(); stepping = nil; preparation?.cancel(); preparation = nil; playback.invalidate(); scrubbing = false; seekPosition = 0 }
}
