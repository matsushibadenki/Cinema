import XCTest
import SwiftUI
import AppKit
import AVFoundation
@testable import Cinema

final class MediaBrowserRenderingTests: XCTestCase {
    @MainActor func testEmbeddedVideoExtractionReplacementAndCleanup() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let movie = folder.appendingPathComponent("fixture.mp4")
        try await LocalVideoFixture.write(to: movie)
        let bytes = try Data(contentsOf: movie)
        var store: BrowserVideoSources? = BrowserVideoSources()
        try await store!.prepare(["Videos/nested/take.mp4": bytes])
        let firstDirectory = try XCTUnwrap(store?.directory)
        let extracted = try XCTUnwrap(store?.urls["Videos/nested/take.mp4"])
        XCTAssertEqual(try Data(contentsOf: extracted), bytes)
        let asset = AVURLAsset(url: extracted)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        XCTAssertEqual(tracks.count, 1)
        try await store!.prepare(["../../untrusted.mp4": bytes])
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstDirectory.path))
        let secondDirectory = try XCTUnwrap(store?.directory)
        XCTAssertTrue(try XCTUnwrap(store?.urls["../../untrusted.mp4"]).path.hasPrefix(secondDirectory.path + "/"))
        try await store!.prepare([:])
        XCTAssertTrue(store!.urls.isEmpty); XCTAssertNil(store!.directory)
        XCTAssertFalse(FileManager.default.fileExists(atPath: secondDirectory.path))
        try await store!.prepare(["video.mp4": bytes])
        let finalDirectory = try XCTUnwrap(store?.directory)
        store = nil
        XCTAssertFalse(FileManager.default.fileExists(atPath: finalDirectory.path))
    }

    @MainActor func testCancelledExtractionDoesNotPublishSources() async throws {
        let store = BrowserVideoSources()
        let task = Task { @MainActor in
            try await store.prepare(["video.mp4": Data(repeating: 0, count: 1_000_000)])
        }
        task.cancel()
        do { try await task.value; XCTFail("Expected cancellation") } catch is CancellationError { }
        XCTAssertTrue(store.urls.isEmpty); XCTAssertNil(store.directory)
        // Clear also invalidates an extraction already suspended on its worker.
        let running = Task { @MainActor in try await store.prepare(["video.mp4": Data(repeating: 0, count: 10_000_000)]) }
        while !store.isPreparing && store.directory == nil { await Task.yield() }
        store.clear()
        do { try await running.value } catch is CancellationError { }
        XCTAssertTrue(store.urls.isEmpty); XCTAssertNil(store.directory)
    }

    @MainActor func testPopulatedBrowserRendering() async throws {
        guard let path = ProcessInfo.processInfo.environment["CINEMA_BROWSER_UI_ARTIFACTS"] else { throw XCTSkip("Set CINEMA_BROWSER_UI_ARTIFACTS for native browser QA") }
        _ = NSApplication.shared
        let folder = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let movie = folder.appendingPathComponent("fixture.mp4")
        try await LocalVideoFixture.write(to: movie)
        let picture = NSImage(size: NSSize(width: 300, height: 180))
        picture.lockFocus()
        NSColor.systemIndigo.setFill(); NSRect(x: 0, y: 0, width: 300, height: 180).fill()
        NSColor.systemOrange.setFill(); NSRect(x: 80, y: 30, width: 140, height: 100).fill()
        picture.unlockFocus()
        let image = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(picture.tiffRepresentation))?.representation(using: .png, properties: [:]))
        let cut = StoryboardCut(cutNumber: 1, cutName: "Imported · 読み込み · 导入", imageFileName: "Images/imported.png", subtitle: "Harbor · 港 · 港口")
        var project = StoryboardProject(cuts: [cut])
        project.generatedImages = [GeneratedImage(cutID: cut.id, title: "Sunset · 夕暮れ · 日落", imageFileName: "Images/generated.png", prompt: "A quiet harbor at sunset. 夕暮れの静かな港。日落时宁静的港口。", context: "Lighting: warm\nCamera: wide\nStyle: cinematic", provider: "fixture", model: "image-model", aspectRatio: 1.667)]
        var video = SceneVideo(title: cut.subtitle, videoFileName: "Videos/scene.mp4"); video.sceneID = project.cuts[0].sceneID
        project.sceneVideos = [video, SceneVideo(title: "Missing · 不明 · 缺失", videoFileName: "Videos/missing.mp4")]
        let document = StoryboardDocument(project: project, imageData: ["Images/generated.png": image, "Images/imported.png": image], videoData: [video.videoFileName: try Data(contentsOf: movie)])
        for language in ["ja", "en", "zh-Hans"] {
            for dark in [false, true] {
                for width in [420, 780] {
                    for tab in [0, 1, 2] {
                        let view = MediaBrowserView(document: document, documentURL: folder.appendingPathComponent("Fixture.cinema"), languageOverride: language, tab: tab)
                        try await capture(view, width: width, dark: dark, to: folder.appendingPathComponent("\(language)-\(dark ? "dark" : "light")-\(width)-tab\(tab).png"))
                    }
                }
                try await capture(BrowserImagePreview(image: project.generatedImages[0], data: image, language: language), width: 420, dark: dark, to: folder.appendingPathComponent("image-detail-\(language)-\(dark ? "dark" : "light").png"))
                try await capture(BrowserVideoPreview(selection: BrowserVideoSelection(url: movie, title: video.title), language: language), width: 420, dark: dark, to: folder.appendingPathComponent("preview-\(language)-\(dark ? "dark" : "light").png"))
            }
        }
    }

    @MainActor private func capture<V: View>(_ view: V, width: Int, dark: Bool, to output: URL) async throws {
        let root = view.frame(width: CGFloat(width), height: 600).background(dark ? Color.black : Color.white).environment(\.colorScheme, dark ? .dark : .light)
        let host = NSHostingView(rootView: root)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 600), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        host.frame = window.contentView!.bounds
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(nanoseconds: 250_000_000)
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        XCTAssertGreaterThan(png.count, 1000)
        try png.write(to: output)
        window.close()
    }
}
