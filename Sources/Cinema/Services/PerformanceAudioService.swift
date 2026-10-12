import Foundation
@preconcurrency import AVFoundation

struct PerformanceAudioPlacement {
    var url: URL
    var start: PerformanceTime
    var end: PerformanceTime
    var sourceOffset: PerformanceTime
    var mix = PerformanceAudioMixSettings()
}

enum PerformanceAudioService {
    enum AudioError: LocalizedError {
        case invalidAudio, invalidTiming, missingAsset, durationExceeded, exportFailed
        var errorDescription: String? {
            switch self {
            case .invalidAudio: "The file has no readable audio track."
            case .invalidTiming: "Audio timing is invalid."
            case .missingAsset: "An assigned audio asset is missing."
            case .durationExceeded: "Audio placement exceeds the source or video duration."
            case .exportFailed: "Media export failed."
            }
        }
    }

    static func inspect(_ url: URL) async throws -> PerformanceTime {
        let asset = AVURLAsset(url: url)
        guard !(try await asset.loadTracks(withMediaType: .audio)).isEmpty else { throw AudioError.invalidAudio }
        let duration = try await asset.load(.duration)
        guard duration.seconds.isFinite, duration.seconds > 0 else { throw AudioError.invalidAudio }
        var time = PerformanceTime(); time.seconds = duration.seconds
        return time
    }

    static func placements(plan: PerformancePlan, sceneID: UUID, urls: [UUID: URL]) throws -> [PerformanceAudioPlacement] {
        let dialogue: [PerformanceAudioPlacement] = try plan.cues.filter { $0.sceneID == sceneID }.compactMap { cue in
            guard let id = cue.audioAssetID else {
                if cue.mode == .audioFirst { throw AudioError.missingAsset }
                return nil
            }
            guard let url = urls[id], plan.audioAssets.contains(where: { $0.id == id }) else { throw AudioError.missingAsset }
            var mix = cue.mix ?? PerformanceAudioMixSettings()
            guard mix.isValid(start: cue.start, end: cue.end) else { throw AudioError.invalidTiming }
            if !plan.laneIsAudible(.dialogue, sceneID: sceneID) { mix.volume = 0 }
            return PerformanceAudioPlacement(url: url, start: cue.start, end: cue.end, sourceOffset: cue.sourceOffset ?? PerformanceTime(), mix: mix)
        }
        let background = try plan.audioClips.filter { $0.sceneID == sceneID }.map { clip in
            guard let url = urls[clip.audioAssetID], plan.audioAssets.contains(where: { $0.id == clip.audioAssetID }) else { throw AudioError.missingAsset }
            var mix = clip.mix ?? PerformanceAudioMixSettings()
            guard mix.isValid(start: clip.start, end: clip.end) else { throw AudioError.invalidTiming }
            if !plan.laneIsAudible(clip.lane == .music ? .music : .ambience, sceneID: sceneID) { mix.volume = 0 }
            return PerformanceAudioPlacement(url: url, start: clip.start, end: clip.end, sourceOffset: clip.sourceOffset, mix: mix)
        }
        return dialogue + background
    }

    /// Every placement owns a track, allowing overlapping dialogue and continuous speech across cuts.
    static func composition(videoURLs: [URL], audio: [PerformanceAudioPlacement], keepNativeAudio: Bool) async throws -> AVMutableComposition {
        let composition = AVMutableComposition()
        var videoDuration = CMTime.zero
        if !videoURLs.isEmpty {
            guard let destination = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw AudioError.exportFailed }
            for url in videoURLs {
                try Task.checkCancellation()
                let asset = AVURLAsset(url: url)
                let duration = try await asset.load(.duration)
                guard duration.seconds.isFinite, duration.seconds > 0,
                      let source = try await asset.loadTracks(withMediaType: .video).first else { throw AudioError.durationExceeded }
                try destination.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: source, at: videoDuration)
                if videoDuration == .zero { destination.preferredTransform = try await source.load(.preferredTransform) }
                if keepNativeAudio, let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first,
                   let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceAudio, at: videoDuration)
                }
                videoDuration = CMTimeAdd(videoDuration, duration)
            }
        }
        for placement in audio {
            try Task.checkCancellation()
            guard placement.start.ticks >= 0, placement.end.ticks > placement.start.ticks, placement.sourceOffset.ticks >= 0, placement.mix.isValid(start: placement.start, end: placement.end) else { throw AudioError.invalidTiming }
            let start = CMTime(value: placement.start.ticks, timescale: PerformanceTime.timescale)
            let duration = CMTime(value: placement.end.ticks - placement.start.ticks, timescale: PerformanceTime.timescale)
            let offset = CMTime(value: placement.sourceOffset.ticks, timescale: PerformanceTime.timescale)
            let source = AVURLAsset(url: placement.url)
            let sourceDuration = try await source.load(.duration)
            guard CMTimeCompare(CMTimeAdd(offset, duration), sourceDuration) <= 0,
                  videoURLs.isEmpty || CMTimeCompare(CMTimeAdd(start, duration), videoDuration) <= 0 else { throw AudioError.durationExceeded }
            guard let sourceTrack = try await source.loadTracks(withMediaType: .audio).first,
                  let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw AudioError.invalidAudio }
            try track.insertTimeRange(CMTimeRange(start: offset, duration: duration), of: sourceTrack, at: start)
        }
        return composition
    }

    /// Composition appends one track per placement after any native video audio tracks.
    static func audioMix(for composition: AVComposition, audio: [PerformanceAudioPlacement]) async throws -> AVMutableAudioMix {
        let tracks = try await composition.loadTracks(withMediaType: .audio)
        guard tracks.count >= audio.count else { throw AudioError.exportFailed }
        let mix = AVMutableAudioMix()
        mix.inputParameters = try zip(tracks.suffix(audio.count), audio).map { track, placement in
            guard placement.mix.isValid(start: placement.start, end: placement.end) else { throw AudioError.invalidTiming }
            let parameters = AVMutableAudioMixInputParameters(track: track)
            let start = CMTime(value: placement.start.ticks, timescale: PerformanceTime.timescale)
            let end = CMTime(value: placement.end.ticks, timescale: PerformanceTime.timescale)
            let gain = Float(placement.mix.volume)
            parameters.setVolume(gain, at: start)
            if placement.mix.fadeIn.ticks > 0 {
                parameters.setVolumeRamp(fromStartVolume: 0, toEndVolume: gain, timeRange: CMTimeRange(start: start, duration: CMTime(value: placement.mix.fadeIn.ticks, timescale: PerformanceTime.timescale)))
            }
            if placement.mix.fadeOut.ticks > 0 {
                let duration = CMTime(value: placement.mix.fadeOut.ticks, timescale: PerformanceTime.timescale)
                parameters.setVolumeRamp(fromStartVolume: gain, toEndVolume: 0, timeRange: CMTimeRange(start: CMTimeSubtract(end, duration), duration: duration))
            }
            return parameters
        }
        return mix
    }

    static func export(videoURLs: [URL], audio: [PerformanceAudioPlacement], keepNativeAudio: Bool, to url: URL) async throws {
        let composition = try await composition(videoURLs: videoURLs, audio: audio, keepNativeAudio: keepNativeAudio)
        guard let exporter = AVAssetExportSession(asset: composition, presetName: videoURLs.isEmpty ? AVAssetExportPresetAppleM4A : AVAssetExportPresetHighestQuality) else { throw AudioError.exportFailed }
        exporter.audioMix = try await audioMix(for: composition, audio: audio)
        exporter.outputURL = url
        exporter.outputFileType = videoURLs.isEmpty ? .m4a : .mp4
        let box = PerformanceExportSession(exporter)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            box.value.exportAsynchronously {
                if box.value.status == .completed { continuation.resume() }
                else { continuation.resume(throwing: box.value.error ?? AudioError.exportFailed) }
            }
        }
    }
}
private final class PerformanceExportSession: @unchecked Sendable {
    let value: AVAssetExportSession
    init(_ value: AVAssetExportSession) { self.value = value }
}
