import XCTest
@testable import Cinema

final class AudioAlignmentTests: XCTestCase {
    private func time(_ seconds: Double) -> PerformanceTime { var t = PerformanceTime(); t.seconds = seconds; return t }
    func testAssetRoundTripAndLegacyCompatibility() throws {
        var asset = PerformanceAudioAsset(name: "Voice", fileName: "Audio/voice.wav", duration: time(2))
        let segment = AudioAlignmentSegment(phoneme: "a", viseme: "open", start: time(0.1), end: time(0.3), performance: "soft")
        asset.alignment = [segment]
        let file = AudioAlignmentFile(audioAssetID: asset.id, segments: [segment])
        try file.validate(for: asset)
        let encoder = JSONEncoder()
        XCTAssertEqual(try JSONDecoder().decode(PerformanceAudioAsset.self, from: encoder.encode(asset)), asset)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(asset)) as? [String: Any])
        json.removeValue(forKey: "alignment")
        XCTAssertNil(try JSONDecoder().decode(PerformanceAudioAsset.self, from: JSONSerialization.data(withJSONObject: json)).alignment)
    }
    func testIdentityTimescaleAndRangeAreValidated() throws {
        let asset = PerformanceAudioAsset(name: "Voice", fileName: "Audio/voice.wav", duration: time(2))
        let segment = AudioAlignmentSegment(phoneme: "a", start: time(0), end: time(1))
        var file = AudioAlignmentFile(audioAssetID: UUID(), segments: [segment])
        XCTAssertThrowsError(try file.validate(for: asset))
        file.audioAssetID = asset.id; file.timescale = 24
        XCTAssertThrowsError(try file.validate(for: asset))
        file.timescale = PerformanceTime.timescale; file.segments[0].end = time(3)
        XCTAssertThrowsError(try file.validate(for: asset))
        file.segments[0].end = time(0)
        XCTAssertThrowsError(try file.validate(for: asset))
        file.segments = [segment, segment]
        XCTAssertThrowsError(try file.validate(for: asset))
    }
}
