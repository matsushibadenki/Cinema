import XCTest
import SwiftUI
import AppKit
@testable import Cinema

final class StoryGraphEditingTests: XCTestCase {
    typealias Object = StoryGraphService.Object
    func source() throws -> Data {
        try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: "story-workspace-v1", withExtension: "json", subdirectory: "Fixtures")))
    }
    func testSharedAndV3ExplicitEditsPreserveGraphMediaAndPackage() throws {
        for wrapped in [false, true] {
            let data = try source()
            let input = wrapped ? try StoryGraphService.encode(["format": StoryGraphService.format, "version": 3, "workspace": JSONSerialization.jsonObject(with: data)]) : data
            var document = try StoryGraphService.read(input)
            document.imageData["keep.png"] = Data([1, 2]); document.audioData["keep.wav"] = Data([3]); document.videoData["keep.mp4"] = Data([4])
            let id = document.project.cuts[0].sceneID!
            let baseline = try StoryGraphEditingService.draft(document, sceneID: id)
            var edits = baseline.runs
            edits[0].text = "本文\nEdited 👨‍👩‍👧‍👦\n正文"
            edits[0].styles = ["bold", "italic"]
            let changed = try StoryGraphEditingService.applying(edits, draft: baseline, to: document)
            XCTAssertEqual(changed.imageData, document.imageData); XCTAssertEqual(changed.audioData, document.audioData); XCTAssertEqual(changed.videoData, document.videoData)
            XCTAssertEqual(changed.project.id, document.project.id)
            let reopened = try StoryboardDocument(package: changed.packageWrapper())
            XCTAssertEqual(reopened.project.cuts[0].action, edits[0].text)
            let result = try StoryGraphService.parse(StoryGraphService.write(reopened))
            let original = try StoryGraphService.parse(input)
            XCTAssertEqual((result.native["graph"] as? NSDictionary)?["edges"] as? NSDictionary, (original.native["graph"] as? NSDictionary)?["edges"] as? NSDictionary)
            XCTAssertEqual(result.native["placement"] as? NSDictionary, original.native["placement"] as? NSDictionary)
            let draft = try StoryGraphEditingService.draft(reopened, sceneID: id)
            XCTAssertEqual(draft.runs[0], edits[0])
        }
    }
    func testLegacyStoreMultipleRunsLinksImagesAndParagraphs() throws {
        for version in [1, 2] {
            var native = try StoryGraphService.parse(source()).native
            var graph = native["graph"] as! Object
            var nodes = graph["nodes"] as! [String: Object]
            let scene = try StoryGraphService.parse(source()).scenes[0]
            let id = scene["id"] as! String
            var canonical = try StoryGraphService.canonical(scene, native: native)
            let link: Object = ["type": "link", "href": "https://example.com", "extensions": ["keep": true]]
            var first = StoryGraphService.paragraph("First")
            first["content"] = [["type": "text", "text": "First", "marks": [link, ["type": "bold", "extra": "keep"]]], ["type": "text", "text": "Second", "marks": [["type": "italic"]]]]
            let second = StoryGraphService.paragraph("第三段落")
            let image: Object = ["type": "image", "id": "keep-image", "altText": "写真", "caption": [], "src": "unchanged.png"]
            canonical["content"] = [first, second, image]
            var properties = scene["properties"] as! Object
            properties["canonical"] = canonical
            var node = scene; node["properties"] = properties; nodes[id] = node
            if version == 2 {
                var documents: Object = [:]
                for (key, var item) in nodes where item["type_id"] as? String == "story.scene" {
                    var props = item["properties"] as! Object
                    documents[key] = props["canonical"]; props["canonical"] = ["documentRef": key]
                    item["properties"] = props; nodes[key] = item
                }
                native["extensions"] = [StoryGraphService.store: documents]
            }
            graph["nodes"] = nodes; native["graph"] = graph
            let data = try StoryGraphService.encode(["format": StoryGraphService.format, "version": version, "document": native])
            let document = try StoryGraphService.read(data)
            let draft = try StoryGraphEditingService.draft(document, sceneID: UUID(uuidString: id)!)
            var edits = draft.runs
            edits[0].text = "Edited"; edits[0].styles.insert("underline")
            edits[1].text = "Changed"; edits[1].styles.remove("italic")
            edits[2].text = "第三本文"
            let result = try StoryGraphService.parse(StoryGraphService.write(StoryGraphEditingService.applying(edits, draft: draft, to: document)))
            let changed = try StoryGraphService.canonical(result.scenes[0], native: result.native)
            let blocks = changed["content"] as! [Object]
            XCTAssertEqual(blocks[2] as NSDictionary, image as NSDictionary)
            XCTAssertEqual(blocks[0]["id"] as? String, first["id"] as? String)
            XCTAssertEqual(blocks[1]["id"] as? String, second["id"] as? String)
            let marks = ((blocks[0]["content"] as! [Object])[0]["marks"] as! [Object])
            XCTAssertEqual(marks[0] as NSDictionary, link as NSDictionary)
            XCTAssertEqual(marks[1]["extra"] as? String, "keep")
            XCTAssertEqual(try StoryGraphService.plainText(changed), "EditedChanged\n第三本文\n写真")
        }
    }
    func testStaleAndIncompatibleEditsLeaveDocumentUnchanged() throws {
        var document = try StoryGraphService.read(source())
        let id = document.project.cuts[0].sceneID!
        let draft = try StoryGraphEditingService.draft(document, sceneID: id)
        var invalidDraft = draft
        invalidDraft.runs[0].path = [999]
        XCTAssertThrowsError(try StoryGraphEditingService.applying(invalidDraft.runs, draft: invalidDraft, to: document))
        document.project.cuts[0].action += " edited elsewhere"
        XCTAssertThrowsError(try StoryGraphEditingService.applying(draft.runs, draft: draft, to: document))
        document.project.cuts[0].situation = "Separate Cinema field"
        XCTAssertThrowsError(try StoryGraphEditingService.draft(document, sceneID: id))
        XCTAssertThrowsError(try StoryGraphEditingService.draft(StoryboardDocument(), sceneID: id))
    }
    @MainActor func testEditorRendering() async throws {
        guard let path = ProcessInfo.processInfo.environment["CINEMA_STORY_EDITOR_UI"] else { throw XCTSkip("Set CINEMA_STORY_EDITOR_UI for editor rendering") }
        _ = NSApplication.shared
        let folder = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let document = try StoryGraphService.read(source())
        for language in ["ja", "en", "zh-Hans"] {
            for dark in [false, true] {
                let root = StoryGraphEditorView(document: .constant(document), language: language)
                    .environment(\.colorScheme, dark ? .dark : .light).frame(width: 480, height: 600)
                let host = NSHostingView(rootView: root)
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false; window.contentView = host
                window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                host.layoutSubtreeIfNeeded(); try await Task.sleep(nanoseconds: 150_000_000); host.layoutSubtreeIfNeeded()
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent("\(language)-\(dark ? "dark" : "light").png"))
                window.close()
            }
        }
    }
}
