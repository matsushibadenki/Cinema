import XCTest
import AppKit
import SwiftUI
@testable import Cinema

final class DocumentMoveServiceTests: XCTestCase {
    @MainActor func testMoveSavesEditsAndUpdatesDocumentURL() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("destination")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("Edited.txt")
        try Data("old".utf8).write(to: source)
        let document = MoveFixtureDocument()
        document.fileURL = source; document.fileType = "public.plain-text"
        document.value = "saved before move"; document.updateChangeCount(.changeDone)
        try await DocumentMoveService.move(document, to: folder)
        let target = folder.appendingPathComponent("Edited.txt")
        XCTAssertEqual(document.fileURL?.standardizedFileURL, target.standardizedFileURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "saved before move")
        document.close()
    }

    @MainActor func testExistingProjectIsNotOverwrittenAndSameFolderIsNoOp() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("target")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("Project.cinemaboard")
        let target = folder.appendingPathComponent(source.lastPathComponent)
        try Data([1]).write(to: source); try Data([2]).write(to: target)
        XCTAssertNil(try DocumentMoveService.destination(source: source, folder: root))
        XCTAssertThrowsError(try DocumentMoveService.destination(source: source, folder: folder))
        XCTAssertEqual(try Data(contentsOf: source), Data([1]))
        XCTAssertEqual(try Data(contentsOf: target), Data([2]))
    }

    @MainActor func testLocalizedFolderPickerAndRecoveryRendering() async throws {
        _ = NSApplication.shared
        let source = URL(fileURLWithPath: "/tmp/Project.cinemaboard")
        for language in ["ja", "en", "zh-Hans"] {
            let picker = DocumentMoveService.panel(language: language, source: source)
            XCTAssertFalse(picker.canChooseFiles); XCTAssertTrue(picker.canChooseDirectories)
            XCTAssertFalse(picker.allowsMultipleSelection)
            XCTAssertEqual(picker.directoryURL?.standardizedFileURL, source.deletingLastPathComponent().standardizedFileURL)
            XCTAssertFalse(picker.message.isEmpty); XCTAssertFalse(picker.prompt.isEmpty)
            guard let path = ProcessInfo.processInfo.environment["CINEMA_RECOVERY_UI_ARTIFACTS"] else { continue }
            let folder = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let labels = MediaRecoveryLabels(language: language)
            for dark in [false, true] {
                let root = VStack(alignment: .leading, spacing: 16) {
                    MediaRecoveryMenu(language: language, isSaved: true, isGenerating: false, canRetry: true, retry: {}, choose: {})
                    Text(labels.retry); Text(labels.choose)
                    Text(labels.help(isSaved: true, isGenerating: false)).font(.caption)
                    Divider()
                    MediaRecoveryMenu(language: language, isSaved: false, isGenerating: false, canRetry: false, retry: {}, choose: {})
                    Text(labels.help(isSaved: false, isGenerating: false)).font(.caption)
                    Divider()
                    MediaRecoveryMenu(language: language, isSaved: true, isGenerating: true, canRetry: false, retry: {}, choose: {})
                    Text(labels.help(isSaved: true, isGenerating: true)).font(.caption)
                    Text(ProjectMediaRelocation.RelocationError.conflict("scene.mp4").message(language: language)).font(.caption)
                }.padding(16).frame(width: 420, height: 420, alignment: .topLeading)
                    .background(dark ? Color.black : Color.white).environment(\.colorScheme, dark ? .dark : .light)
                let host = NSHostingView(rootView: root)
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 420), styleMask: [.borderless], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false; window.contentView = host
                window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                host.frame = window.contentView!.bounds; host.layoutSubtreeIfNeeded()
                try await Task.sleep(nanoseconds: 50_000_000)
                host.layoutSubtreeIfNeeded()
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent("\(language)-\(dark ? "dark" : "light").png"))
                window.close()
            }
        }
    }
}

private final class MoveFixtureDocument: NSDocument {
    var value = ""
    override func data(ofType typeName: String) throws -> Data { Data(value.utf8) }
}
