import AppKit
@preconcurrency import AVFoundation
import Foundation

enum VideoAssemblyService {
    enum AssemblyError: LocalizedError {
        case videoTrackMissing
        case exportSessionUnavailable
        case exportFailed(String)
        case frameExtractionFailed

        var errorDescription: String? {
            switch self {
            case .videoTrackMissing:
                return "生成動画に映像トラックが見つかりませんでした。"
            case .exportSessionUnavailable:
                return "動画を結合するエクスポート処理を開始できませんでした。"
            case .exportFailed(let message):
                return "動画の結合に失敗しました: \(message)"
            case .frameExtractionFailed:
                return "前のカットから接続用フレームを取得できませんでした。"
            }
        }
    }

    static func concatenate(_ clips: [Data]) async throws -> Data {
        guard clips.count > 1 else { return clips.first ?? Data() }

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CinemaVideoAssembly-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let clipURLs = try clips.enumerated().map { index, data in
            let url = temporaryDirectory.appendingPathComponent("clip-\(index).mp4")
            try data.write(to: url, options: .atomic)
            return url
        }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AssemblyError.videoTrackMissing
        }
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var insertionTime = CMTime.zero
        for url in clipURLs {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            guard let sourceVideoTrack = videoTracks.first else {
                throw AssemblyError.videoTrackMissing
            }

            try videoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: sourceVideoTrack,
                at: insertionTime
            )
            if insertionTime == .zero {
                videoTrack.preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
            }

            if let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                try audioTrack?.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: sourceAudioTrack,
                    at: insertionTime
                )
            }
            insertionTime = CMTimeAdd(insertionTime, duration)
        }

        let outputURL = temporaryDirectory.appendingPathComponent("assembled.mp4")
        guard let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw AssemblyError.exportSessionUnavailable
        }
        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true

        let exporterBox = SendableExportSession(exporter)
        try await withCheckedThrowingContinuation { continuation in
            exporterBox.value.exportAsynchronously {
                switch exporterBox.value.status {
                case .completed:
                    continuation.resume()
                case .failed, .cancelled:
                    continuation.resume(throwing: AssemblyError.exportFailed(
                        exporterBox.value.error?.localizedDescription ?? "不明なエラー"
                    ))
                default:
                    continuation.resume(throwing: AssemblyError.exportFailed("エクスポートが完了しませんでした。"))
                }
            }
        }

        return try Data(contentsOf: outputURL)
    }

    static func lastFramePNG(from videoData: Data) async throws -> Data {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CinemaLastFrame-\(UUID().uuidString).mp4")
        try videoData.write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let requestedTime = CMTimeMaximum(
            .zero,
            CMTimeSubtract(duration, CMTime(value: 1, timescale: 30))
        )
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        let image = try await withCheckedThrowingContinuation { continuation in
            generator.generateCGImageAsynchronously(for: requestedTime) { image, _, error in
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: error ?? AssemblyError.frameExtractionFailed)
                }
            }
        }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw AssemblyError.frameExtractionFailed
        }
        return data
    }
}

private final class SendableExportSession: @unchecked Sendable {
    let value: AVAssetExportSession

    init(_ value: AVAssetExportSession) {
        self.value = value
    }
}
