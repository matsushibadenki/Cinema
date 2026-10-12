import XCTest
import SwiftUI
import AppKit
@testable import Cinema

final class PerformanceRenderingTests: XCTestCase {
    /// Opt-in visual artifacts for manual QA without disturbing the user's Cinema window.
    @MainActor func testLocalizedLaneRendering() async throws {
        guard let path = ProcessInfo.processInfo.environment["CINEMA_AUDIO_UI_ARTIFACTS"] else { throw XCTSkip("Set CINEMA_AUDIO_UI_ARTIFACTS to capture visual fixtures") }
        let folder = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        _ = NSApplication.shared
        let line = DialogueLine(speaker: "Alice", dialogue: "Across the cut")
        var project = StoryboardProject(cuts: [StoryboardCut(cutNumber: 1, dialogueLines: [line])])
        let scene = try XCTUnwrap(project.cuts[0].sceneID)
        let asset = PerformanceAudioAsset(name: "Forest · 森の音 · 森林声音", fileName: "Audio/forest.wav", duration: PerformanceTime(ticks: 480000))
        project.performancePlan.audioAssets = [asset]
        project.performancePlan.cues = [PerformanceCue(sceneID: scene, cutID: project.cuts[0].id, dialogueID: line.id, start: PerformanceTime(ticks: 48000), end: PerformanceTime(ticks: 144000))]
        let mix = PerformanceAudioMixSettings(volume: 0.65, fadeIn: PerformanceTime(ticks: 48000), fadeOut: PerformanceTime(ticks: 96000))
        project.performancePlan.audioClips = [PerformanceAudioClip(sceneID: scene, audioAssetID: asset.id, lane: .music, end: asset.duration, mix: mix), PerformanceAudioClip(sceneID: scene, audioAssetID: asset.id, lane: .ambience, start: PerformanceTime(ticks: 48000), end: PerformanceTime(ticks: 336000), mix: mix)]
        project.performancePlan.laneStates = [PerformanceLaneState(sceneID: scene, lane: .music, isSolo: true), PerformanceLaneState(sceneID: scene, lane: .ambience, isMuted: true)]
        var sceneVideo = SceneVideo(title: "Fixture", videoFileName: "Videos/fixture.mp4"); sceneVideo.sceneID = scene
        var oldVideo = SceneVideo(title: "Earlier Take · 以前のテイク · 之前版本", videoFileName: "Videos/old.mp4", generatedAt: Date(timeIntervalSinceNow: -86400)); oldVideo.sceneID = scene
        project.sceneVideos = [oldVideo, sceneVideo]
        for language in ["ja", "en", "zh-Hans"] {
            for dark in [false, true] {
                for width in [420, 660] {
                    let root = VStack(alignment: .leading, spacing: 16) {
                        PerformancePreviewView(project: project, sceneID: scene, audioData: [:], language: language, playback: PerformancePreviewPlayer(), includeVideo: true)
                        PerformanceLanesView(project: .constant(project), sceneID: scene, language: language, playhead: 2.5)
                    }
                        .padding(.horizontal, 16).padding(.vertical, 16)
                        .frame(width: CGFloat(width), height: 1700, alignment: .topLeading)
                        .background(dark ? Color.black : Color.white)
                        .environment(\.colorScheme, dark ? .dark : .light)
                    let host = NSHostingView(rootView: root)
                    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 1700), styleMask: [.borderless], backing: .buffered, defer: false)
                    window.isReleasedWhenClosed = false
                    window.contentView = host
                    host.frame = window.contentView!.bounds
                    window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                    host.layoutSubtreeIfNeeded()
                    try await Task.sleep(nanoseconds: 50_000_000)
                    host.layoutSubtreeIfNeeded()
                    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    XCTAssertGreaterThan(png.count, 1000)
                    try png.write(to: folder.appendingPathComponent("\(language)-\(dark ? "dark" : "light")-\(width).png"))
                    window.close()
                }
            }
        }
    }
}
