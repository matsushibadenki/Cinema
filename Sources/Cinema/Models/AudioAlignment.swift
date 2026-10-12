import Foundation

struct AudioAlignmentSegment: Codable, Identifiable, Equatable {
    var id = UUID()
    var phoneme = ""
    var viseme = ""
    /// Times are relative to the original audio asset, not scene or cue start.
    var start = PerformanceTime()
    var end = PerformanceTime()
    var performance = ""
}

struct AudioAlignmentFile: Codable, Equatable {
    var format = "cinema.audio-alignment"
    var schemaVersion = "1.0.0"
    var timescale = PerformanceTime.timescale
    var audioAssetID: UUID
    var segments: [AudioAlignmentSegment]

    func validate(for asset: PerformanceAudioAsset) throws {
        guard format == "cinema.audio-alignment", schemaVersion == "1.0.0", timescale == PerformanceTime.timescale, audioAssetID == asset.id else { throw AlignmentError.incompatible }
        guard Set(segments.map(\.id)).count == segments.count else { throw AlignmentError.invalidTiming }
        for segment in segments {
            guard segment.start.ticks >= 0, segment.end.ticks > segment.start.ticks, segment.end.ticks <= asset.duration.ticks else { throw AlignmentError.invalidTiming }
        }
    }
    enum AlignmentError: LocalizedError {
        case incompatible, invalidTiming
        var errorDescription: String? { self == .incompatible ? "Alignment format or audio asset identity does not match." : "Alignment has invalid or out-of-range timing." }
    }
}
