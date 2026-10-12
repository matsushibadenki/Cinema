import XCTest
import AVFoundation
import SwiftUI
import AppKit
@testable import Cinema

final class PerformanceAudioTests: XCTestCase {
    private func time(_ seconds: Double) -> PerformanceTime { var t = PerformanceTime(); t.seconds = seconds; return t }
    private func fixture(in folder: URL) throws -> URL {
        let url = folder.appendingPathComponent("tone.wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 96000))
        buffer.frameLength = 96000
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        for i in 0..<96000 { samples[i] = Float(sin(Double(i) * 2 * .pi * 440 / 48000)) * 0.1 }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
    func testOverlappingTracksAndAudioExport() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try fixture(in: folder)
        let duration = try await PerformanceAudioService.inspect(url)
        XCTAssertEqual(duration.seconds, 2, accuracy: 0.001)
        let audio = [PerformanceAudioPlacement(url: url, start: time(0.5), end: time(1.5), sourceOffset: time(0)), PerformanceAudioPlacement(url: url, start: time(1), end: time(2), sourceOffset: time(0.5))]
        let composition = try await PerformanceAudioService.composition(videoURLs: [], audio: audio, keepNativeAudio: false)
        let tracks = try await composition.loadTracks(withMediaType: .audio)
        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(composition.duration.seconds, 2, accuracy: 0.001)
        let output = folder.appendingPathComponent("result.m4a")
        try await PerformanceAudioService.export(videoURLs: [], audio: audio, keepNativeAudio: false, to: output)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        let exportedDuration = try await PerformanceAudioService.inspect(output)
        XCTAssertEqual(exportedDuration.seconds, 2, accuracy: 0.1)
    }
    func testOutOfRangeAudioIsRejected() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try fixture(in: folder)
        do {
            _ = try await PerformanceAudioService.composition(videoURLs: [], audio: [PerformanceAudioPlacement(url: url, start: time(0), end: time(2), sourceOffset: time(1))], keepNativeAudio: false)
            XCTFail("Expected duration rejection")
        } catch PerformanceAudioService.AudioError.durationExceeded { }
    }
    func testAudioPackageStorageAndLegacyPlan() throws {
        var document = StoryboardDocument()
        document.audioData["Audio/test.wav"] = Data([1, 2, 3])
        let wrapper = try document.packageWrapper()
        XCTAssertEqual(StoryboardDocument.readData(from: try XCTUnwrap(wrapper.fileWrappers?["Audio"]), prefix: "Audio"), document.audioData)
        let old = Data("{\"format\":\"cinema.performance-plan\",\"schemaVersion\":\"1.0.0\",\"timescale\":48000,\"characters\":[],\"cues\":[]}".utf8)
        XCTAssertTrue(try JSONDecoder().decode(PerformancePlan.self, from: old).audioAssets.isEmpty)
    }
    func testVideoWithIndependentAudioExport() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let video = folder.appendingPathComponent("silent.mp4")
        try await silentVideo(at: video)
        let audio = try fixture(in: folder)
        let output = folder.appendingPathComponent("mixed.mp4")
        try await PerformanceAudioService.export(videoURLs: [video], audio: [PerformanceAudioPlacement(url: audio, start: time(0.1), end: time(0.8), sourceOffset: time(0))], keepNativeAudio: false, to: output)
        let asset = AVURLAsset(url: output)
        let videos = try await asset.loadTracks(withMediaType: .video)
        let audios = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertEqual(videos.count, 1)
        XCTAssertEqual(audios.count, 1)
        let duration = try await asset.load(.duration)
        XCTAssertEqual(duration.seconds, 1, accuracy: 0.05)
    }

    private func silentVideo(at video: URL, frames: Int = 30, timescale: Int32 = 30, presentationTimes: [Int64]? = nil) async throws {
        try await LocalVideoFixture.write(to: video, frames: frames, timescale: timescale, presentationTimes: presentationTimes)
    }

    func testSpeechSpansTwoCutsWithMusicAndAmbience() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = folder.appendingPathComponent("first.mp4")
        let second = folder.appendingPathComponent("second.mp4")
        try await silentVideo(at: first)
        try await silentVideo(at: second)
        let url = try fixture(in: folder)
        let scene = UUID()
        let asset = PerformanceAudioAsset(name: "Tone", fileName: "tone.wav", duration: time(2))
        var plan = PerformancePlan(); plan.audioAssets = [asset]
        plan.cues = [PerformanceCue(sceneID: scene, cutID: UUID(), dialogueID: UUID(), audioAssetID: asset.id, start: time(0.5), end: time(1.5))]
        plan.audioClips = [PerformanceAudioClip(sceneID: scene, audioAssetID: asset.id, lane: .music, end: time(2)), PerformanceAudioClip(sceneID: scene, audioAssetID: asset.id, lane: .ambience, start: time(0.75), end: time(1.75), sourceOffset: time(0.25))]
        let placements = try PerformanceAudioService.placements(plan: plan, sceneID: scene, urls: [asset.id: url])
        XCTAssertEqual(placements.count, 3)
        let composition = try await PerformanceAudioService.composition(videoURLs: [first, second], audio: placements, keepNativeAudio: false)
        let tracks = try await composition.loadTracks(withMediaType: .audio)
        XCTAssertEqual(tracks.count, 3)
        let segments = try await tracks[0].load(.segments)
        let speech = try XCTUnwrap(segments.last)
        XCTAssertEqual(speech.timeMapping.target.start.seconds, 0.5, accuracy: 0.001)
        XCTAssertEqual(speech.timeMapping.target.duration.seconds, 1, accuracy: 0.001)
        let output = folder.appendingPathComponent("cross-cut.mp4")
        try await PerformanceAudioService.export(videoURLs: [first, second], audio: placements, keepNativeAudio: false, to: output)
        let exported = AVURLAsset(url: output)
        let duration = try await exported.load(.duration)
        XCTAssertEqual(duration.seconds, 2, accuracy: 0.05)
    }

    private func rms(_ url: URL, at seconds: Double) throws -> Double {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let count = AVAudioFrameCount(format.sampleRate * 0.05)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count))
        file.framePosition = AVAudioFramePosition(format.sampleRate * seconds)
        try file.read(into: buffer, frameCount: count)
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        XCTAssertGreaterThan(buffer.frameLength, 0)
        return sqrt((0..<Int(buffer.frameLength)).reduce(0.0) { $0 + Double(samples[$1] * samples[$1]) } / Double(buffer.frameLength))
    }

    func testGainFadesAndMuteReachExportedAudio() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try fixture(in: folder)
        let settings = PerformanceAudioMixSettings(volume: 0.4, fadeIn: time(0.5), fadeOut: time(0.5))
        let output = folder.appendingPathComponent("fades.m4a")
        try await PerformanceAudioService.export(videoURLs: [], audio: [PerformanceAudioPlacement(url: source, start: time(0), end: time(2), sourceOffset: time(0), mix: settings)], keepNativeAudio: false, to: output)
        let plateau = try rms(output, at: 0.8)
        XCTAssertEqual(plateau, 0.1 / sqrt(2) * 0.4, accuracy: 0.004)
        XCTAssertLessThan(try rms(output, at: 0.05), plateau * 0.4)
        XCTAssertLessThan(try rms(output, at: 1.9), plateau * 0.4)
        let muted = folder.appendingPathComponent("mute.m4a")
        try await PerformanceAudioService.export(videoURLs: [], audio: [PerformanceAudioPlacement(url: source, start: time(0), end: time(2), sourceOffset: time(0), mix: PerformanceAudioMixSettings(volume: 0))], keepNativeAudio: false, to: muted)
        XCTAssertLessThan(try rms(muted, at: 0.8), 0.0001)
    }

    func testInvalidFadeSumRejected() async throws {
        let placement = PerformanceAudioPlacement(url: URL(fileURLWithPath: "/missing.wav"), start: time(0), end: time(1), sourceOffset: time(0), mix: PerformanceAudioMixSettings(fadeIn: time(0.75), fadeOut: time(0.5)))
        do { _ = try await PerformanceAudioService.composition(videoURLs: [], audio: [placement], keepNativeAudio: false); XCTFail() }
        catch PerformanceAudioService.AudioError.invalidTiming { }
    }

    @MainActor func testMixedPreviewPreparationSeekingAndCleanup() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try fixture(in: folder)
        let line = DialogueLine(dialogue: "Preview")
        var project = StoryboardProject(cuts: [StoryboardCut(cutNumber: 1, dialogueLines: [line])])
        let scene = try XCTUnwrap(project.cuts[0].sceneID)
        let asset = PerformanceAudioAsset(name: "Tone", fileName: "Audio/tone.wav", duration: time(2))
        project.performancePlan.audioAssets = [asset]
        project.performancePlan.cues = [PerformanceCue(sceneID: scene, cutID: project.cuts[0].id, dialogueID: line.id, audioAssetID: asset.id, mix: PerformanceAudioMixSettings(volume: 0.4, fadeIn: time(0.25), fadeOut: time(0.25)), start: time(0.25), end: time(1.75))]
        project.performancePlan.audioClips = [PerformanceAudioClip(sceneID: scene, audioAssetID: asset.id, lane: .ambience, end: time(2))]
        let playback = PerformancePreviewPlayer()
        try await playback.prepare(project: project, sceneID: scene, audioData: [asset.fileName: try Data(contentsOf: source)])
        XCTAssertTrue(playback.isReady); XCTAssertFalse(playback.isPlaying)
        XCTAssertEqual(playback.duration, 2, accuracy: 0.001)
        let sources = try XCTUnwrap(playback.sourceDirectory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sources.path))
        playback.seek(to: 0.75); XCTAssertEqual(playback.position, 0.75)
        playback.seek(to: 99); XCTAssertEqual(playback.position, 2)
        playback.seek(to: .nan); XCTAssertEqual(playback.position, 2)
        playback.stop(); XCTAssertEqual(playback.position, 0)
        playback.invalidate()
        XCTAssertFalse(playback.isReady); XCTAssertNil(playback.sourceDirectory)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sources.path))
        do { try await playback.prepare(project: project, sceneID: scene, audioData: [:]); XCTFail() } catch { }
        XCTAssertFalse(playback.isReady); XCTAssertFalse(playback.isPreparing); XCTAssertNotNil(playback.error)
        playback.invalidate()
        let cancelled = Task { @MainActor in
            try await playback.prepare(project: project, sceneID: scene, audioData: [asset.fileName: try Data(contentsOf: source)])
        }
        cancelled.cancel()
        do { try await cancelled.value; XCTFail() } catch is CancellationError { }
        XCTAssertFalse(playback.isReady); XCTAssertFalse(playback.isPreparing)
        XCTAssertNil(playback.sourceDirectory); XCTAssertNil(playback.error)
    }

    func testSoloAndMuteReachExportWithoutShorteningTimeline() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try fixture(in: folder)
        let scene = UUID()
        let asset = PerformanceAudioAsset(name: "Tone", fileName: "tone.wav", duration: time(2))
        var plan = PerformancePlan(); plan.audioAssets = [asset]
        plan.cues = [PerformanceCue(sceneID: scene, cutID: UUID(), dialogueID: UUID(), audioAssetID: asset.id, end: time(2))]
        plan.audioClips = [PerformanceAudioClip(sceneID: scene, audioAssetID: asset.id, lane: .music, end: time(2)), PerformanceAudioClip(sceneID: scene, audioAssetID: asset.id, lane: .ambience, end: time(2))]
        plan.laneStates = [PerformanceLaneState(sceneID: scene, lane: .music, isSolo: true)]
        let placements = try PerformanceAudioService.placements(plan: plan, sceneID: scene, urls: [asset.id: source])
        XCTAssertEqual(placements.map { $0.mix.volume }, [0, 1, 0])
        let output = folder.appendingPathComponent("solo.m4a")
        try await PerformanceAudioService.export(videoURLs: [], audio: placements, keepNativeAudio: false, to: output)
        XCTAssertEqual(try rms(output, at: 0.8), 0.1 / sqrt(2), accuracy: 0.004)
        plan.laneStates[0].isMuted = true
        let muted = try PerformanceAudioService.placements(plan: plan, sceneID: scene, urls: [asset.id: source])
        XCTAssertEqual(muted.map { $0.mix.volume }, [0, 0, 0])
        let silence = folder.appendingPathComponent("muted.m4a")
        try await PerformanceAudioService.export(videoURLs: [], audio: muted, keepNativeAudio: false, to: silence)
        XCTAssertLessThan(try rms(silence, at: 0.8), 0.0001)
        let duration = try await PerformanceAudioService.inspect(silence)
        XCTAssertEqual(duration.seconds, 2, accuracy: 0.05)
        plan.cues[0].mix = PerformanceAudioMixSettings(volume: -1)
        XCTAssertThrowsError(try PerformanceAudioService.placements(plan: plan, sceneID: scene, urls: [asset.id: source]))
    }

    @MainActor func testVideoPreviewUsesOneClockAndNativeAudioOption() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let silent = folder.appendingPathComponent("silent.mp4")
        try await silentVideo(at: silent)
        let source = try fixture(in: folder)
        let movie = folder.appendingPathComponent("native.mp4")
        try await PerformanceAudioService.export(videoURLs: [silent], audio: [PerformanceAudioPlacement(url: source, start: time(0), end: time(1), sourceOffset: time(0))], keepNativeAudio: false, to: movie)
        let line = DialogueLine(dialogue: "Sync")
        var project = StoryboardProject(cuts: [StoryboardCut(cutNumber: 1, dialogueLines: [line])])
        let scene = try XCTUnwrap(project.cuts[0].sceneID)
        let audio = PerformanceAudioAsset(name: "Voice", fileName: "Audio/voice.wav", duration: time(2))
        project.performancePlan.audioAssets = [audio]
        project.performancePlan.cues = [PerformanceCue(sceneID: scene, cutID: project.cuts[0].id, dialogueID: line.id, audioAssetID: audio.id, mix: PerformanceAudioMixSettings(volume: 0.2), start: time(0.1), end: time(0.8))]
        var video = SceneVideo(title: "Scene", videoFileName: "scene/native.mp4"); video.sceneID = scene
        var old = SceneVideo(title: "Old", videoFileName: "unavailable.mp4", generatedAt: Date(timeIntervalSinceNow: -86400)); old.sceneID = scene
        project.sceneVideos = [old, video]
        let audioData = [audio.fileName: try Data(contentsOf: source)]
        let embedded = [video.videoFileName: try Data(contentsOf: movie)]
        let playback = PerformancePreviewPlayer()
        for native in [false, true] {
            try await playback.prepare(project: project, sceneID: scene, audioData: audioData, videoData: embedded, includeVideo: true, keepNativeAudio: native)
            XCTAssertTrue(playback.hasVideo); XCTAssertTrue(playback.isReady)
            XCTAssertEqual(playback.duration, 1, accuracy: 0.05)
            let item = try XCTUnwrap(playback.videoPlayer?.currentItem)
            let videos = try await item.asset.loadTracks(withMediaType: .video)
            let audios = try await item.asset.loadTracks(withMediaType: .audio)
            XCTAssertEqual(videos.count, 1); XCTAssertEqual(audios.count, native ? 2 : 1)
            XCTAssertEqual(item.audioMix?.inputParameters.count, 1)
            playback.seek(to: 0.5); XCTAssertEqual(playback.position, 0.5)
            let temporary = try XCTUnwrap(playback.sourceDirectory)
            XCTAssertTrue(FileManager.default.fileExists(atPath: temporary.appendingPathComponent("scene.mp4").path))
            playback.invalidate()
            XCTAssertFalse(FileManager.default.fileExists(atPath: temporary.path))
        }
        let stored = folder.appendingPathComponent("movies/scene", isDirectory: true)
        try FileManager.default.createDirectory(at: stored, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: movie, to: stored.appendingPathComponent("native.mp4"))
        let document = folder.appendingPathComponent("project.cinema")
        try await playback.prepare(project: project, sceneID: scene, audioData: audioData, documentURL: document, includeVideo: true)
        XCTAssertTrue(playback.hasVideo)
        playback.invalidate()
        XCTAssertTrue(FileManager.default.fileExists(atPath: stored.appendingPathComponent("native.mp4").path))
        project.performancePlan.cues[0].end = time(1.5)
        do { try await playback.prepare(project: project, sceneID: scene, audioData: audioData, videoData: embedded, includeVideo: true); XCTFail() }
        catch PerformanceAudioService.AudioError.durationExceeded { }
        XCTAssertFalse(playback.isReady); XCTAssertFalse(playback.hasVideo); XCTAssertNil(playback.sourceDirectory)
    }

    @MainActor func testVideoOnlyPreviewAndMissingVideoFailure() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("silent.mp4")
        try await silentVideo(at: source)
        var project = StoryboardProject()
        let scene = try XCTUnwrap(project.cuts[0].sceneID)
        var video = SceneVideo(title: "Scene", videoFileName: "Videos/scene.mp4"); video.sceneID = scene
        project.sceneVideos = [video]
        let playback = PerformancePreviewPlayer()
        try await playback.prepare(project: project, sceneID: scene, audioData: [:], videoData: [video.videoFileName: try Data(contentsOf: source)], includeVideo: true)
        XCTAssertTrue(playback.hasVideo); XCTAssertEqual(playback.duration, 1, accuracy: 0.05)
        playback.stop(); XCTAssertEqual(playback.position, 0)
        do { try await playback.prepare(project: project, sceneID: scene, audioData: [:], includeVideo: true); XCTFail() }
        catch PerformancePreviewPlayer.PreviewError.missingSceneVideo { }
        XCTAssertFalse(playback.isReady); XCTAssertFalse(playback.isPreparing); XCTAssertFalse(playback.hasVideo)
        XCTAssertNil(playback.sourceDirectory); XCTAssertNotNil(playback.error)
    }

    @MainActor func testSavedPackageReopensForMixedPreview() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let audioURL = try fixture(in: folder)
        let videoURL = folder.appendingPathComponent("source.mp4")
        try await silentVideo(at: videoURL, frames: 60)
        let line = DialogueLine(speaker: "Alice", dialogue: "The saved scene · 保存したシーン · 已保存场景")
        var project = StoryboardProject(cuts: [StoryboardCut(cutNumber: 1, dialogueLines: [line])])
        let scene = try XCTUnwrap(project.cuts[0].sceneID)
        let character = ProjectCharacter(name: "Alice", voiceID: "stable-voice")
        let audio = PerformanceAudioAsset(name: "Locked speech", fileName: "Audio/Locked/speech.wav", duration: time(2))
        let mix = PerformanceAudioMixSettings(volume: 0.65, fadeIn: time(0.1), fadeOut: time(0.1))
        project.performancePlan.characters = [character]
        project.performancePlan.audioAssets = [audio]
        project.performancePlan.cues = [PerformanceCue(sceneID: scene, cutID: project.cuts[0].id, dialogueID: line.id, characterID: character.id, audioAssetID: audio.id, sourceOffset: time(0.2), mix: mix, start: time(0.3), end: time(1.3), mode: .audioFirst)]
        project.performancePlan.audioClips = [PerformanceAudioClip(sceneID: scene, audioAssetID: audio.id, lane: .music, end: time(2), mix: mix)]
        project.performancePlan.laneStates = [PerformanceLaneState(sceneID: scene, lane: .music, isMuted: true)]
        var video = SceneVideo(title: "Saved Take", videoFileName: "Videos/Takes/scene.mp4"); video.sceneID = scene
        project.sceneVideos = [video]
        project.normalizeSceneIdentities()
        var document = StoryboardDocument(project: project, videoData: [video.videoFileName: try Data(contentsOf: videoURL)])
        document.audioData = [audio.fileName: try Data(contentsOf: audioURL)]
        let saved = folder.appendingPathComponent("RoundTrip.cinema")
        try document.packageWrapper().write(to: saved, options: .atomic, originalContentsURL: nil)
        try FileManager.default.removeItem(at: audioURL)
        try FileManager.default.removeItem(at: videoURL)
        let reopened = try StoryboardDocument(package: FileWrapper(url: saved, options: .immediate))
        XCTAssertEqual(reopened.project.performancePlan, project.performancePlan)
        XCTAssertEqual(reopened.videoData, document.videoData)
        XCTAssertEqual(reopened.audioData, document.audioData)
        XCTAssertEqual(reopened.project.sceneVideos, project.sceneVideos)
        let playback = PerformancePreviewPlayer()
        defer { playback.invalidate() }
        try await playback.prepare(project: reopened.project, sceneID: scene, audioData: reopened.audioData, videoData: reopened.videoData, documentURL: saved, includeVideo: true)
        let item = try XCTUnwrap(playback.videoPlayer?.currentItem)
        let composition = try XCTUnwrap(item.asset as? AVComposition)
        let tracks = try await composition.loadTracks(withMediaType: .audio)
        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(playback.duration, 2, accuracy: 0.001)
        playback.seek(to: 1.1)
        try await playback.stepFrame(forward: true)
        XCTAssertGreaterThan(playback.position, 1.1)
        try playback.setLoopRange(.init(start: 0.1, end: 1.5))
        playback.stop(); XCTAssertEqual(playback.position, 0)

        // Render enabled controls in isolated native windows, leaving the user's document untouched.
        if let path = ProcessInfo.processInfo.environment["CINEMA_AUDIO_UI_ARTIFACTS"] {
            let destination = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            _ = NSApplication.shared
            for language in ["ja", "en", "zh-Hans"] {
                for dark in [false, true] {
                    let playback = PerformancePreviewPlayer()
                    defer { playback.invalidate() }
                    try await playback.prepare(project: reopened.project, sceneID: scene, audioData: reopened.audioData, videoData: reopened.videoData, includeVideo: true)
                    try playback.setLoopRange(.init(start: 0.1, end: 1.5))
                    let view = PerformancePreviewView(project: reopened.project, sceneID: scene, audioData: reopened.audioData, language: language, videoData: reopened.videoData, playback: playback, includeVideo: true)
                        .padding(.horizontal, 16).padding(.vertical, 16)
                        .frame(width: 420, height: 850, alignment: .topLeading)
                        .background(dark ? Color.black : Color.white)
                        .environment(\.colorScheme, dark ? .dark : .light)
                    let host = NSHostingView(rootView: view)
                    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 850), styleMask: [.borderless], backing: .buffered, defer: false)
                    window.isReleasedWhenClosed = false
                    window.contentView = host
                    window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                    host.frame = window.contentView!.bounds
                    host.layoutSubtreeIfNeeded()
                    try await Task.sleep(nanoseconds: 100_000_000)
                    host.layoutSubtreeIfNeeded()
                    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: destination.appendingPathComponent("ready-\(language)-\(dark ? "dark" : "light").png"))
                    window.close()
                }
            }
        }
    }

    func testPreviewLoopRangeValidation() {
        XCTAssertTrue(PreviewLoopRange(start: 0.1, end: 0.15).isValid(duration: 1))
        XCTAssertTrue(PreviewLoopRange(start: 0.2, end: 0.5).isValid(duration: 1))
        for range in [PreviewLoopRange(start: -1, end: 0.5), .init(start: 0.5, end: 0.2), .init(start: 0, end: 1.1), .init(start: 0, end: 0.01), .init(start: .nan, end: 1), .init(start: 0, end: .infinity)] {
            XCTAssertFalse(range.isValid(duration: 1))
        }
        let range = PreviewLoopRange(start: 0.2, end: 0.5)
        XCTAssertTrue(range.contains(0.2)); XCTAssertFalse(range.contains(0.5))
    }

    @MainActor func testPreviewLoopPlaybackAndTransport() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("silent.mp4")
        try await silentVideo(at: source)
        var project = StoryboardProject()
        let scene = try XCTUnwrap(project.cuts[0].sceneID)
        var video = SceneVideo(title: "Scene", videoFileName: "Videos/scene.mp4"); video.sceneID = scene
        project.sceneVideos = [video]
        let playback = PerformancePreviewPlayer()
        defer { playback.invalidate() }
        try await playback.prepare(project: project, sceneID: scene, audioData: [:], videoData: [video.videoFileName: try Data(contentsOf: source)], includeVideo: true)
        let range = PreviewLoopRange(start: 0.2, end: 0.5)
        try playback.setLoopRange(range)
        XCTAssertEqual(try XCTUnwrap(playback.videoPlayer?.currentItem).forwardPlaybackEndTime.seconds, 0.5, accuracy: 0.000001)
        XCTAssertThrowsError(try playback.setLoopRange(.init(start: 0.8, end: 1.5)))
        XCTAssertEqual(playback.loopRange, range)
        playback.play()
        var previous = 0.0
        var repeats = 0
        for _ in 0..<200 {
            try await Task.sleep(nanoseconds: 20_000_000)
            let current = playback.videoPlayer?.currentTime().seconds ?? 0
            if previous > 0.4 && current < 0.3 { repeats += 1 }
            previous = current
            if repeats >= 2 { break }
        }
        XCTAssertGreaterThanOrEqual(repeats, 2, "The actual AVPlayer should traverse the range twice")
        XCTAssertTrue(playback.isPlaying)
        playback.pause()
        try await Task.sleep(nanoseconds: 100_000_000)
        let paused = try XCTUnwrap(playback.videoPlayer).currentTime().seconds
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(playback.videoPlayer?.currentTime().seconds ?? -1, paused, accuracy: 0.01)
        XCTAssertFalse(playback.isPlaying)
        playback.stop(); XCTAssertEqual(playback.position, 0); XCTAssertEqual(playback.loopRange, range)
        try playback.setLoopRange(nil)
        XCTAssertFalse(try XCTUnwrap(playback.videoPlayer?.currentItem).forwardPlaybackEndTime.isValid)
        playback.seek(to: 0.8); XCTAssertEqual(playback.position, 0.8)
        playback.invalidate(); XCTAssertNil(playback.loopRange)
    }

    @MainActor func testTakeSelectionAndFrameStepping() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let firstURL = folder.appendingPathComponent("first.mp4")
        let latestURL = folder.appendingPathComponent("latest.mp4")
        try await silentVideo(at: firstURL, frames: 24, timescale: 24)
        try await silentVideo(at: latestURL, frames: 60, timescale: 30)
        var project = StoryboardProject()
        let scene = try XCTUnwrap(project.cuts[0].sceneID)
        var first = SceneVideo(title: "First", videoFileName: "first.mp4", generatedAt: Date(timeIntervalSinceNow: -86400)); first.sceneID = scene
        var latest = SceneVideo(title: "Latest", videoFileName: "latest.mp4"); latest.sceneID = scene
        project.sceneVideos = [first, latest]
        let data = [first.videoFileName: try Data(contentsOf: firstURL), latest.videoFileName: try Data(contentsOf: latestURL)]
        let playback = PerformancePreviewPlayer()
        try await playback.prepare(project: project, sceneID: scene, audioData: [:], videoData: data, includeVideo: true)
        XCTAssertEqual(playback.duration, 2, accuracy: 0.05)
        try await playback.prepare(project: project, sceneID: scene, audioData: [:], videoData: data, includeVideo: true, selectedVideoID: first.id)
        XCTAssertEqual(playback.duration, 1, accuracy: 0.05)
        try await playback.stepFrame(forward: true)
        XCTAssertEqual(playback.position, 1.0 / 24, accuracy: 0.000001)
        try await playback.stepFrame(forward: true)
        XCTAssertEqual(playback.position, 2.0 / 24, accuracy: 0.000001)
        try await playback.stepFrame(forward: false)
        XCTAssertEqual(playback.position, 1.0 / 24, accuracy: 0.000001)
        XCTAssertFalse(playback.isPlaying); XCTAssertFalse(playback.isStepping)
        playback.seek(to: 1)
        try await playback.stepFrame(forward: false)
        XCTAssertEqual(playback.position, 23.0 / 24, accuracy: 0.000001)
        playback.stop()
        try await playback.stepFrame(forward: false)
        XCTAssertEqual(playback.position, 0)
        let frames = try await VideoFrameIndexService.timestamps(at: firstURL)
        XCTAssertEqual(frames.count, 24)
        XCTAssertEqual(frames.last!, 23.0 / 24, accuracy: 0.000001)
        playback.invalidate()
        do { try await playback.prepare(project: project, sceneID: scene, audioData: [:], videoData: data, includeVideo: true, selectedVideoID: UUID()); XCTFail() }
        catch PerformancePreviewPlayer.PreviewError.missingSceneVideo { }
        XCTAssertFalse(playback.isReady)
    }

    func testIrregularVideoFrameTimesMapToPlaybackClock() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let video = folder.appendingPathComponent("irregular.mp4")
        try await silentVideo(at: video, frames: 4, timescale: 1000, presentationTimes: [0, 33, 100, 150])
        let times = try await VideoFrameIndexService.timestamps(at: video)
        XCTAssertEqual(times.count, 4)
        for (actual, expected) in zip(times, [0.0, 0.033, 0.1, 0.15]) { XCTAssertEqual(actual, expected, accuracy: 0.000001) }
    }

    func testVariableFrameTimestampNavigation() {
        let times = [0.0, 0.033, 0.1, 0.15]
        XCTAssertEqual(VideoFrameIndexService.target(in: times, position: 0.033, forward: true), 0.1)
        XCTAssertEqual(VideoFrameIndexService.target(in: times, position: 0.1, forward: false), 0.033)
        XCTAssertEqual(VideoFrameIndexService.target(in: times, position: 0.08, forward: false), 0.033)
        XCTAssertEqual(VideoFrameIndexService.target(in: times, position: 0.08, forward: true), 0.1)
        XCTAssertEqual(VideoFrameIndexService.target(in: times, position: 9, forward: true), 0.15)
        XCTAssertNil(VideoFrameIndexService.target(in: [], position: 0, forward: true))
    }

    func testWaveformStreamsIntoBoundedPeakBins() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try fixture(in: folder)
        let peaks = try AudioWaveformService.peaks(at: url, bins: 120)
        XCTAssertEqual(peaks.count, 120)
        XCTAssertTrue(peaks.allSatisfy { $0 > 0.09 && $0 <= 0.101 })
        XCTAssertEqual(try AudioWaveformService.peaks(at: url, bins: 10000).count, 2048)
    }

}
