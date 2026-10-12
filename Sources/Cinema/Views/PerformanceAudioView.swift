import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers

struct PerformanceAudioView: View {
    @Binding var project: StoryboardProject
    @Binding var audioData: [String: Data]
    @Binding var videoData: [String: Data]
    var documentURL: URL?
    var language: String
    @State private var busy = false
    @State private var message: String?
    @State private var selectedScene: UUID?
    @State private var keepNativeAudio = false
    @State private var player: AVAudioPlayer?
    @State private var assetPlaybackRevision = 0
    @StateObject private var playback = PerformancePreviewPlayer()
    private func t(_ ja: String, _ en: String, _ zh: String) -> String { language == "en" ? en : language == "zh-Hans" ? zh : ja }
    private var sceneIDs: [UUID] { Array(Set(project.cuts.compactMap(\.sceneID))).sorted { $0.uuidString < $1.uuidString } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(t("確定音声素材", "Locked Audio Assets", "确定音频素材")).font(.headline)
                Spacer()
                if busy { ProgressView().controlSize(.small) }
                Button(t("音声を読み込む", "Import Audio", "导入音频")) { importAudio() }.disabled(busy)
            }
            ForEach($project.performancePlan.audioAssets) { $asset in
                VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(asset.name).lineLimit(1)
                    Text(String(format: "%.2f s", asset.duration.seconds)).foregroundStyle(.secondary)
                    Spacer()
                    Button(t("再生", "Play", "播放")) { play(asset) }
                    Button(t("停止", "Stop", "停止")) { player?.stop() }
                }
                AudioAlignmentView(asset: $asset, data: audioData[asset.fileName], language: language)
                }
            }
            Picker(t("書き出すシーン", "Scene to Export", "导出场景"), selection: $selectedScene) {
                Text(t("選択してください", "Choose a Scene", "请选择场景")).tag(Optional<UUID>.none)
                ForEach(sceneIDs, id: \.self) { id in
                    let cut = project.cuts.first { $0.sceneID == id }
                    Text(cut?.subtitle.isEmpty == false ? cut!.subtitle : "\(cut?.cutNumber ?? 0)").tag(Optional(id))
                }
            }
            Toggle(t("元動画の音声も残す（声が重なる場合があります）", "Keep Original Video Audio (voices may overlap)", "保留原视频音频（声音可能重叠）"), isOn: $keepNativeAudio)
            if let selectedScene {
                PerformancePreviewView(project: project, sceneID: selectedScene, audioData: audioData, language: language, videoData: videoData, documentURL: documentURL, keepNativeAudio: keepNativeAudio, onPlay: { player?.stop() }, playback: playback).id(assetPlaybackRevision)
                PerformanceLanesView(project: $project, sceneID: selectedScene, language: language, playhead: playback.position, previewDuration: playback.duration, onSeek: playback.isReady ? { playback.seek(to: $0) } : nil)
            }
            HStack {
                Button(t("配置音声を書き出す", "Export Placed Audio", "导出安排的音频")) { export(video: false) }
                Button(t("音声付き動画を書き出す", "Export Mixed Video", "导出混合视频")) { export(video: true) }
            }.disabled(busy || selectedScene == nil)
            HStack {
                Button(t("同期Bundle v2を書き出す", "Export Sync Bundle v2", "导出同步Bundle v2")) { exportBundle() }.disabled(busy || selectedScene == nil)
                Button(t("同期結果Bundleを読み込む", "Import Sync Result Bundle", "导入同步结果Bundle")) { importBundle() }.disabled(busy)
            }
            if let message { Text(message).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
        }.onDisappear { player?.stop(); playback.invalidate() }
    }

    private func exportBundle() {
        guard let sceneID = selectedScene else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            var document = StoryboardDocument(project: project, videoData: videoData); document.audioData = audioData
            let (_, receipt) = try PerformanceBundleService.export(document: document, sceneID: sceneID, to: url)
            project.performanceBundleReceipts.append(receipt)
            message = t("同期Bundle v2を書き出しました。結果の読み込みに備えてプロジェクトを保存してください。", "Sync Bundle v2 exported. Save the project before importing results.", "已导出同步Bundle v2。请保存项目以便导入结果。")
        } catch { message = error.localizedDescription }
    }

    private func importBundle() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let originalProject = project; let originalAudio = audioData; let originalVideo = videoData
        busy = true
        Task { @MainActor in
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() }; busy = false }
            do {
                var document = StoryboardDocument(project: originalProject, videoData: originalVideo); document.audioData = originalAudio
                let count = try await PerformanceBundleService.importResult(at: url, into: &document)
                guard project == originalProject, audioData == originalAudio, videoData == originalVideo else { throw PerformanceBundleService.BundleError.stale }
                project = document.project; audioData = document.audioData; videoData = document.videoData
                message = t("同期結果を読み込みました：", "Sync results imported: ", "已导入同步结果：") + String(count)
            } catch { message = error.localizedDescription }
        }
    }

    private func importAudio() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.audio]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        busy = true
        Task { @MainActor in
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() }; busy = false }
            do {
                let duration = try await PerformanceAudioService.inspect(url)
                let data = try Data(contentsOf: url)
                let path = "Audio/\(UUID().uuidString).\(url.pathExtension.lowercased())"
                audioData[path] = data
                project.performancePlan.audioAssets.append(PerformanceAudioAsset(name: url.lastPathComponent, fileName: path, duration: duration))
                message = t("音声を保存しました。発話の「確定音声」で選択できます。", "Audio saved. Assign it using Locked Audio on a dialogue cue.", "音频已保存。可在对白的确定音频中选择。")
            } catch { message = t("音声を読み込めませんでした：", "Could not import audio: ", "无法导入音频：") + error.localizedDescription }
        }
    }

    private func play(_ asset: PerformanceAudioAsset) {
        do {
            guard let data = audioData[asset.fileName] else { throw PerformanceAudioService.AudioError.missingAsset }
            playback.invalidate()
            assetPlaybackRevision += 1
            player?.stop(); player = try AVAudioPlayer(data: data); player?.play()
        } catch { message = error.localizedDescription }
    }

    private func export(video: Bool) {
        guard let sceneID = selectedScene else { return }
        let snapshot = project; let bytes = audioData
        let cues = snapshot.performancePlan.cues.filter { $0.sceneID == sceneID }
        guard cues.contains(where: { $0.audioAssetID != nil }) || snapshot.performancePlan.audioClips.contains(where: { $0.sceneID == sceneID }), cues.allSatisfy({ cue in snapshot.cuts.contains { $0.id == cue.cutID && $0.sceneID == cue.sceneID && $0.dialogueLines.contains { $0.id == cue.dialogueID } } }) else {
            message = t("有効な発話と確定音声を割り当ててください。", "Assign locked audio to valid dialogue cues.", "请为有效对白分配确定音频。"); return
        }
        let sceneVideo = snapshot.sceneVideos.filter { $0.sceneID == sceneID }.max { $0.generatedAt < $1.generatedAt }
        guard !video || sceneVideo != nil else { message = t("先にシーン動画を生成してください。", "Generate a scene video first.", "请先生成场景视频。"); return }
        let panel = NSSavePanel(); panel.allowedContentTypes = video ? [.mpeg4Movie] : [.mpeg4Audio]; panel.nameFieldStringValue = video ? "performance.mp4" : "performance.m4a"
        guard panel.runModal() == .OK, let output = panel.url else { return }
        let native = keepNativeAudio; let location = documentURL
        busy = true
        Task { @MainActor in
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("CinemaAudio-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: folder); busy = false }
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                var urls: [UUID: URL] = [:]
                let needed = Set(cues.compactMap(\.audioAssetID) + snapshot.performancePlan.audioClips.filter { $0.sceneID == sceneID }.map(\.audioAssetID))
                for asset in snapshot.performancePlan.audioAssets where needed.contains(asset.id) {
                    guard let data = bytes[asset.fileName] else { throw PerformanceAudioService.AudioError.missingAsset }
                    let url = folder.appendingPathComponent(asset.id.uuidString + "." + URL(fileURLWithPath: asset.fileName).pathExtension)
                    try data.write(to: url, options: .atomic); urls[asset.id] = url
                }
                var videoURLs: [URL] = []
                if video, let sceneVideo {
                    if let data = snapshotVideoData(sceneVideo.videoFileName) {
                        let url = folder.appendingPathComponent("source.mp4"); try data.write(to: url); videoURLs = [url]
                    } else if let url = GeneratedVideoStorageService.fileURL(for: sceneVideo.videoFileName, documentURL: location) { videoURLs = [url] }
                    else { throw PerformanceAudioService.AudioError.missingAsset }
                }
                let placements = try PerformanceAudioService.placements(plan: snapshot.performancePlan, sceneID: sceneID, urls: urls)
                // Export to a fresh temporary URL, then atomically replace only the user-selected destination.
                let temporaryOutput = folder.appendingPathComponent(video ? "result.mp4" : "result.m4a")
                try await PerformanceAudioService.export(videoURLs: videoURLs, audio: placements, keepNativeAudio: native, to: temporaryOutput)
                if FileManager.default.fileExists(atPath: output.path) { _ = try FileManager.default.replaceItemAt(output, withItemAt: temporaryOutput) }
                else { try FileManager.default.moveItem(at: temporaryOutput, to: output) }
                message = t("書き出しました。口形補正は行っていません。", "Exported. Lip-sync correction was not applied.", "已导出，未进行口型修正。")
            } catch { message = t("書き出しに失敗しました：", "Export failed: ", "导出失败：") + error.localizedDescription }
        }
    }

    private func snapshotVideoData(_ path: String) -> Data? { videoData[path] }
}
