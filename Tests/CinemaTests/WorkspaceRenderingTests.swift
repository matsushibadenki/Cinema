import XCTest
import SwiftUI
import AppKit
@testable import Cinema

final class WorkspaceRenderingTests: XCTestCase {
    @MainActor func testLocalizedNarrowWorkspace() async throws {
        guard let path = ProcessInfo.processInfo.environment["CINEMA_WORKSPACE_UI_ARTIFACTS"] else { throw XCTSkip("Set CINEMA_WORKSPACE_UI_ARTIFACTS for full workspace QA") }
        _ = NSApplication.shared
        let folder = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("movies"), withIntermediateDirectories: true)
        let movie = folder.appendingPathComponent("movies/fixture.mp4")
        try await LocalVideoFixture.write(to: movie)
        let cut = StoryboardCut(cutNumber: 1, dialogueLines: [DialogueLine(speaker: "Alice", dialogue: "The ships return at sunset. 夕暮れに船が戻る。船在日落时返回。")], subtitle: "Harbor · 港 · 港口")
        var project = StoryboardProject(cuts: [cut])
        var clip = GeneratedCutVideo(sceneTitle: cut.subtitle, cutID: cut.id, videoFileName: "fixture.mp4")
        clip.sceneID = project.cuts[0].sceneID
        project.generatedCutVideos = [clip]
        let document = StoryboardDocument(project: project)
        let suite = "CinemaWorkspaceQA-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        for language in ["ja", "en", "zh-Hans"] {
            defaults.set(language, forKey: "appLanguage")
            for dark in [false, true] {
                for width in [1000, 1280] {
                    let root = ContentView(document: .constant(document), documentURL: folder.appendingPathComponent("Fixture.cinemaboard"))
                        .defaultAppStorage(defaults)
                        .environment(\.colorScheme, dark ? .dark : .light)
                        .frame(width: CGFloat(width), height: 820)
                    let host = NSHostingView(rootView: root)
                    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 820), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
                    window.isReleasedWhenClosed = false; window.contentView = host
                    window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                    host.layoutSubtreeIfNeeded()
                    try await Task.sleep(nanoseconds: 300_000_000)
                    // Allow the real workspace's initial window configuration, then enforce the QA size.
                    window.setContentSize(NSSize(width: width, height: 820))
                    host.frame = NSRect(x: 0, y: 0, width: width, height: 820)
                    host.layoutSubtreeIfNeeded()
                    try await Task.sleep(nanoseconds: 150_000_000)
                    host.layoutSubtreeIfNeeded()
                    XCTAssertEqual(host.bounds.width, CGFloat(width), accuracy: 1)
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
