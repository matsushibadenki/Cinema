import Foundation
import Combine
@preconcurrency import AVFoundation

/// Owns temporary source files until the player releases its composition.
@MainActor final class PerformancePreviewPlayer: ObservableObject {
    @Published private(set) var isPreparing = false
    @Published private(set) var isReady = false
    @Published private(set) var isPlaying = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var error: String?
    @Published private(set) var loopRange: PreviewLoopRange?
    private var wantsPlayback = false
    private var player: AVPlayer?
    @Published private(set) var videoPlayer: AVPlayer?
    @Published private(set) var hasVideo = false
    private var observer: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private(set) var sourceDirectory: URL?
    private var request = UUID()
    private var seekRevision = UUID()
    private var isSeeking = false
    private var videoSource: URL?
    private var frameTimes: [Double] = []
    @Published private(set) var isStepping = false

    deinit {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let observer { player?.removeTimeObserver(observer) }
        player?.pause(); player?.replaceCurrentItem(with: nil)
        if let sourceDirectory { try? FileManager.default.removeItem(at: sourceDirectory) }
    }

    func prepare(project: StoryboardProject, sceneID: UUID, audioData: [String: Data], videoData: [String: Data] = [:], documentURL: URL? = nil, includeVideo: Bool = false, keepNativeAudio: Bool = false, selectedVideoID: UUID? = nil) async throws {
        invalidate()
        let token = request
        isPreparing = true
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("CinemaPreview-" + UUID().uuidString)
        var retained = false
        defer {
            if !retained { try? FileManager.default.removeItem(at: temporary) }
            if request == token { isPreparing = false }
        }
        do {
            var snapshot = project
            snapshot.cuts = snapshot.cuts.filter { $0.sceneID == sceneID }
            snapshot.performancePlan.cues = snapshot.performancePlan.cues.filter { $0.sceneID == sceneID }
            snapshot.performancePlan.audioClips = snapshot.performancePlan.audioClips.filter { $0.sceneID == sceneID }
            guard !snapshot.cuts.isEmpty, snapshot.performancePlan.issues(in: snapshot).isEmpty else { throw PerformanceAudioService.AudioError.invalidTiming }
            let ids = Set(snapshot.performancePlan.cues.compactMap(\.audioAssetID) + snapshot.performancePlan.audioClips.map(\.audioAssetID))
            guard !ids.isEmpty || includeVideo else { throw PerformanceAudioService.AudioError.missingAsset }
            try Task.checkCancellation()
            try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
            var urls: [UUID: URL] = [:]
            for asset in snapshot.performancePlan.audioAssets where ids.contains(asset.id) {
                guard let data = audioData[asset.fileName], !data.isEmpty else { throw PerformanceAudioService.AudioError.missingAsset }
                let url = temporary.appendingPathComponent(asset.id.uuidString).appendingPathExtension(URL(fileURLWithPath: asset.fileName).pathExtension)
                try data.write(to: url, options: .atomic); urls[asset.id] = url
            }
            let placements = try PerformanceAudioService.placements(plan: snapshot.performancePlan, sceneID: sceneID, urls: urls)
            var videos: [URL] = []
            if includeVideo {
                let takes = project.sceneVideos.filter { $0.sceneID == sceneID }
                guard let video = (selectedVideoID == nil ? takes.max(by: { $0.generatedAt < $1.generatedAt }) : takes.first(where: { $0.id == selectedVideoID })) else { throw PreviewError.missingSceneVideo }
                let destination = temporary.appendingPathComponent("scene.mp4")
                if let bytes = videoData[video.videoFileName] {
                    guard !bytes.isEmpty else { throw PreviewError.missingSceneVideo }
                    try bytes.write(to: destination, options: .atomic)
                } else {
                    guard let source = GeneratedVideoStorageService.fileURL(for: video.videoFileName, documentURL: documentURL), let documentURL else { throw PreviewError.missingSceneVideo }
                    let access = documentURL.startAccessingSecurityScopedResource()
                    defer { if access { documentURL.stopAccessingSecurityScopedResource() } }
                    let root = documentURL.deletingLastPathComponent().appendingPathComponent("movies").resolvingSymlinksInPath().standardizedFileURL
                    guard source.resolvingSymlinksInPath().standardizedFileURL.path.hasPrefix(root.path + "/") else { throw GeneratedVideoStorageService.StorageError.invalidStoredPath }
                    try FileManager.default.copyItem(at: source, to: destination)
                }
                videos = [destination]
            }
            let composition = try await PerformanceAudioService.composition(videoURLs: videos, audio: placements, keepNativeAudio: includeVideo && keepNativeAudio)
            let mix = try await PerformanceAudioService.audioMix(for: composition, audio: placements)
            try Task.checkCancellation()
            guard token == request else { throw CancellationError() }
            let seconds = composition.duration.seconds
            guard seconds.isFinite, seconds > 0 else { throw PerformanceAudioService.AudioError.invalidTiming }
            let item = AVPlayerItem(asset: composition); item.audioMix = mix
            let playback = AVPlayer(playerItem: item)
            videoSource = videos.first
            player = playback; videoPlayer = includeVideo ? playback : nil; hasVideo = includeVideo; sourceDirectory = temporary; duration = seconds; isReady = true; retained = true
            statusObservation = item.observe(\.status, options: [.new]) { [weak self] observed, _ in
                guard observed.status == .failed else { return }
                let message = observed.error?.localizedDescription ?? PerformanceAudioService.AudioError.invalidAudio.localizedDescription
                Task { @MainActor [weak self] in
                    guard let self, self.request == token else { return }
                    self.error = message; self.pause(); self.isReady = false
                }
            }
            endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.request == token, self.wantsPlayback, !self.isSeeking else { return }
                    if let range = self.loopRange {
                        self.seek(to: range.start)
                    } else {
                        self.pause(); self.position = self.loopRange?.end ?? self.duration
                    }
                }
            }
            observer = playback.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.request == token else { return }
                    let seconds = self.player?.currentTime().seconds ?? 0
                    if !self.isSeeking, seconds.isFinite { self.position = min(max(seconds, 0), self.duration) }
                    self.isPlaying = self.wantsPlayback

                }
            }
        } catch {
            if token == request, !(error is CancellationError) { self.error = error.localizedDescription }
            throw error
        }
    }

    enum PreviewError: LocalizedError {
        case missingSceneVideo, invalidLoopRange
        var errorDescription: String? {
            self == .missingSceneVideo ? "The selected scene video is unavailable. Generate or restore it first." : "The loop must be at least 50 ms and fit within the prepared preview."
        }
    }

    func stepFrame(forward: Bool) async throws {
        guard isReady, hasVideo, let videoSource, !isStepping else { return }
        try Task.checkCancellation()
        pause()
        let token = request; let seekToken = seekRevision
        isStepping = true
        defer { if token == request { isStepping = false } }
        do {
            if frameTimes.isEmpty {
                let times = try await VideoFrameIndexService.timestamps(at: videoSource)
                try Task.checkCancellation()
                guard token == request else { throw CancellationError() }
                frameTimes = times.filter { $0 < duration }
            }
            guard token == request, seekToken == seekRevision else { throw CancellationError() }
            if let target = VideoFrameIndexService.target(in: frameTimes, position: position, forward: forward) { seek(to: target) }
        } catch {
            if token == request, !(error is CancellationError) { self.error = error.localizedDescription }
            throw error
        }
    }

    func setLoopRange(_ range: PreviewLoopRange?) throws {
        if let range { guard isReady, range.isValid(duration: duration) else { throw PreviewError.invalidLoopRange } }
        loopRange = range
        player?.currentItem?.forwardPlaybackEndTime = range.map { CMTime(seconds: $0.end, preferredTimescale: 600_000_000) } ?? .invalid
        if wantsPlayback { seek(to: position) }
    }

    func play() {
        guard isReady else { return }
        wantsPlayback = true; isPlaying = true
        if let range = loopRange {
            if !range.contains(position) { seek(to: range.start) } else { player?.play() }
        }
        else if position >= duration - 0.05 { seek(to: 0) }
        else { player?.play() }
    }
    func pause() { wantsPlayback = false; player?.pause(); isPlaying = false }
    func stop() { pause(); seek(to: 0) }
    func seek(to seconds: Double) {
        guard isReady, seconds.isFinite else { return }
        seekRevision = UUID()
        let bounded = min(max(seconds, 0), duration)
        position = wantsPlayback && loopRange?.contains(bounded) == false ? loopRange!.start : bounded
        player?.pause()
        isSeeking = true
        let token = seekRevision
        player?.seek(to: CMTime(seconds: position, preferredTimescale: 600_000_000), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] completed in
            Task { @MainActor [weak self] in
                guard let self, self.seekRevision == token else { return }
                self.isSeeking = false
                if completed, self.wantsPlayback { self.player?.play(); self.isPlaying = true }
            }
        }
    }
    func invalidate() {
        request = UUID(); seekRevision = UUID()
        loopRange = nil
        videoSource = nil; frameTimes = []; isStepping = false; isSeeking = false
        pause()
        if let observer { player?.removeTimeObserver(observer) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        videoPlayer = nil; statusObservation = nil; endObserver = nil; observer = nil; player?.replaceCurrentItem(with: nil); player = nil
        if let sourceDirectory { try? FileManager.default.removeItem(at: sourceDirectory) }
        sourceDirectory = nil; hasVideo = false; isPreparing = false; isReady = false; duration = 0; position = 0; error = nil
    }
}
