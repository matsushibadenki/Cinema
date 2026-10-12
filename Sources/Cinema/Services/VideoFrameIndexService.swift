import Foundation
@preconcurrency import AVFoundation

/// Read compressed sample presentation timestamps without decoding video frames.
enum VideoFrameIndexService {
    enum IndexError: LocalizedError {
        case unreadable, tooLarge
        var errorDescription: String? { self == .tooLarge ? "The video exceeds the frame inspection limit." : "Video frame timestamps could not be read." }
    }
    static func timestamps(at url: URL) async throws -> [Double] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw IndexError.unreadable }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw IndexError.unreadable }
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? IndexError.unreadable }
        defer { reader.cancelReading() }
        var times: [Double] = []
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            // Empty edit-list markers are not video frames. AVAssetReader supplies output
            // timestamps mapped onto the track playback clock, including media-time offsets.
            guard CMSampleBufferGetNumSamples(sample) > 0,
                  CMSampleBufferGetDataBuffer(sample) != nil || CMSampleBufferGetImageBuffer(sample) != nil else { continue }
            let time = CMSampleBufferGetOutputPresentationTimeStamp(sample).seconds
            if time.isFinite && time >= 0 { times.append(time) }
            guard times.count <= 500_000 else { throw IndexError.tooLarge }
        }
        guard reader.status == .completed, !times.isEmpty else { throw reader.error ?? IndexError.unreadable }
        return Array(Set(times)).sorted()
    }
    static func target(in times: [Double], position: Double, forward: Bool) -> Double? {
        guard !times.isEmpty, position.isFinite else { return nil }
        var low = 0; var high = times.count
        let threshold = position + (forward ? 0.000001 : -0.000001)
        while low < high {
            let middle = (low + high) / 2
            if forward ? times[middle] <= threshold : times[middle] < threshold { low = middle + 1 } else { high = middle }
        }
        return times[forward ? min(low, times.count - 1) : max(0, low - 1)]
    }
}
