import AVFoundation
import Foundation

enum AudioWaveformService {
    /// Stream decoded PCM in bounded chunks; retain only the requested peak bins.
    static func peaks(at url: URL, bins: Int = 240) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard file.length > 0 else { return [] }
        let count = max(1, min(bins, 2048))
        var peaks = [Float](repeating: 0, count: count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 8192) else { return [] }
        while file.framePosition < file.length {
            try Task.checkCancellation()
            let position = file.framePosition
            try file.read(into: buffer)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { break }
            for frame in 0..<Int(buffer.frameLength) {
                let index = min(count - 1, Int(Double(position + Int64(frame)) / Double(file.length) * Double(count)))
                for channel in 0..<Int(file.processingFormat.channelCount) {
                    let value = abs(channels[channel][frame])
                    if value.isFinite { peaks[index] = max(peaks[index], min(value, 1)) }
                }
            }
        }
        return peaks
    }
}
