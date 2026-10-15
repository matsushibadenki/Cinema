import XCTest
@testable import Cinema

final class StoryGraphParagraphTests: XCTestCase {
    typealias Object = StoryGraphService.Object
    func variants() throws -> [Data] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "story-workspace-v1", withExtension: "json", subdirectory: "Fixtures"))
        let shared = try Data(contentsOf: url)
        let snapshot = try StoryGraphService.parse(shared)
        var native = snapshot.native
        var graph = native["graph"] as! Object
        var nodes = graph["nodes"] as! [String: Object]
        var store: Object = [:]
        for (id, var node) in nodes where node["type_id"] as? String == "story.scene" {
            var props = node["properties"] as! Object
            store[id] = props["canonical"]; props["canonical"] = ["documentRef": id]
            node["properties"] = props; nodes[id] = node
        }
        graph["nodes"] = nodes; native["graph"] = graph
        native["extensions"] = [StoryGraphService.store: store]
        return [shared,
            try StoryGraphService.encode(["format": StoryGraphService.format, "version": 3, "workspace": snapshot.root]),
            try StoryGraphService.encode(["format": StoryGraphService.format, "version": 1, "document": snapshot.native]),
            try StoryGraphService.encode(["format": StoryGraphService.format, "version": 2, "document": native])]
    }
    func testParagraphAndLinkOperationsInEveryEnvelope() throws {
        for source in try variants() {
            var document = try StoryGraphService.read(source)
            document.audioData["Audio/keep.wav"] = Data([1, 2, 3])
            let id = document.project.cuts[0].sceneID!
            let draft = try StoryGraphEditingService.draft(document, sceneID: id)
            var edits = draft.runs
            edits[0].link = "https://example.com/scene?q=1"
            let appended = try StoryGraphEditingService.applying(edits, draft: draft, to: document, appending: ["新しい段落 👨‍👩‍👧‍👦", "New paragraph / 新段落"])
            let reopened = try StoryboardDocument(package: appended.packageWrapper())
            XCTAssertEqual(reopened.audioData, document.audioData)
            let next = try StoryGraphEditingService.draft(reopened, sceneID: id)
            XCTAssertEqual(next.runs[0].link, edits[0].link)
            XCTAssertEqual(next.runs.suffix(2).map(\.text), ["新しい段落 👨‍👩‍👧‍👦", "New paragraph / 新段落"])
            let originalCanonical = try JSONSerialization.jsonObject(with: draft.canonical) as! Object
            let nextCanonical = try JSONSerialization.jsonObject(with: next.canonical) as! Object
            let originalBlocks = originalCanonical["content"] as! [Object]
            let nextBlocks = nextCanonical["content"] as! [Object]
            XCTAssertEqual(originalBlocks[0]["id"] as? String, nextBlocks[0]["id"] as? String)
            XCTAssertNotEqual(nextBlocks[nextBlocks.count - 1]["id"] as? String, nextBlocks[nextBlocks.count - 2]["id"] as? String)
            var unlinked = next.runs; unlinked[0].link = nil
            let removed = try StoryGraphEditingService.applying(unlinked, draft: next, to: reopened, removing: [nextBlocks.count - 1])
            let final = try StoryGraphEditingService.draft(removed, sceneID: id)
            XCTAssertNil(final.runs[0].link)
            XCTAssertEqual(final.runs.last?.text, "新しい段落 👨‍👩‍👧‍👦")
            let before = try StoryGraphService.parse(source).native["graph"] as! Object
            let after = try StoryGraphService.parse(StoryGraphService.write(removed)).native["graph"] as! Object
            XCTAssertEqual(before["edges"] as? NSDictionary, after["edges"] as? NSDictionary)
            XCTAssertEqual(removed.project.id, document.project.id)
        }
    }
    func testReferencedParagraphRemovalIsAtomic() throws {
        let original = try variants()[0]
        let document = try StoryGraphService.read(original)
        let id = document.project.cuts[0].sceneID!
        let draft = try StoryGraphEditingService.draft(document, sceneID: id)
        let canonical = try JSONSerialization.jsonObject(with: draft.canonical) as! Object
        let paragraphID = (canonical["content"] as! [Object])[0]["id"] as! String
        var root = try StoryGraphService.parse(original).root
        var graph = root["graph"] as! Object
        var ext = graph["extensions"] as! Object
        ext["custom.paragraphReference"] = ["nodeId": "https://example.com/#" + paragraphID.uppercased()]
        graph["extensions"] = ext; root["graph"] = graph
        let linked = try StoryGraphService.read(StoryGraphService.encode(root))
        let linkedDraft = try StoryGraphEditingService.draft(linked, sceneID: id)
        XCTAssertThrowsError(try StoryGraphEditingService.applying(linkedDraft.runs, draft: linkedDraft, to: linked, removing: [0], appending: ["Replacement"])) {
            XCTAssertEqual($0 as? StoryGraphEditingService.EditError, .referencedParagraph)
        }
        XCTAssertEqual(linked.storyGraphSource, try StoryGraphService.encode(root))
    }
    func testLinkAttributesAndInlineAnnotationsArePreserved() throws {
        var snapshot = try StoryGraphService.parse(variants()[2])
        var native = snapshot.native
        var graph = native["graph"] as! Object
        var nodes = graph["nodes"] as! [String: Object]
        var scene = snapshot.scenes[0]
        let id = scene["id"] as! String
        var props = scene["properties"] as! Object
        var canonical = props["canonical"] as! Object
        var blocks = canonical["content"] as! [Object]
        var runs = blocks[0]["content"] as! [Object]
        let link: Object = ["type": "link", "href": "https://example.com/old", "extensions": ["annotation": "keep"]]
        runs[0]["marks"] = [link, ["type": "bold"]]
        blocks[0]["content"] = runs; canonical["content"] = blocks
        props["canonical"] = canonical; scene["properties"] = props
        nodes[id] = scene; graph["nodes"] = nodes; native["graph"] = graph
        snapshot.root["document"] = native
        let document = try StoryGraphService.read(StoryGraphService.encode(snapshot.root))
        let draft = try StoryGraphEditingService.draft(document, sceneID: UUID(uuidString: id)!)
        var edits = draft.runs; edits[0].link = "mailto:new@example.com"
        let updated = try StoryGraphEditingService.applying(edits, draft: draft, to: document)
        let result = try StoryGraphEditingService.draft(updated, sceneID: draft.sceneID)
        let value = try JSONSerialization.jsonObject(with: result.canonical) as! Object
        let resultBlocks = value["content"] as! [Object]
        let marks = (resultBlocks[0]["content"] as! [Object])[0]["marks"] as! [Object]
        XCTAssertEqual(marks[0]["extensions"] as? NSDictionary, link["extensions"] as? NSDictionary)
        XCTAssertEqual(marks[0]["href"] as? String, "mailto:new@example.com")
        XCTAssertEqual(marks[1]["type"] as? String, "bold")
        XCTAssertThrowsError(try StoryGraphEditingService.applying(result.runs, draft: result, to: updated, removing: [0], appending: ["Replacement"]))
    }
    func testLinkValidationAndEmptyScene() throws {
        for url in ["https://example.com/a", "http://example.com", "mailto:hello@example.com"] { XCTAssertNoThrow(try StoryGraphEditingService.validateLink(url)) }
        for url in ["javascript:alert(1)", "file:///tmp/a", "data:text/plain,abc", "/relative", "https://", "https://example.com\n", String(repeating: "x", count: 2049)] {
            XCTAssertThrowsError(try StoryGraphEditingService.validateLink(url))
        }
        let source = try StoryGraphService.write(StoryboardDocument(project: StoryboardProject(cuts: [StoryboardCut(cutNumber: 1)])))
        let document = try StoryGraphService.read(source)
        let draft = try StoryGraphEditingService.draft(document, sceneID: document.project.cuts[0].sceneID!)
        XCTAssertTrue(draft.runs.isEmpty)
        let edited = try StoryGraphEditingService.applying([], draft: draft, to: document, appending: ["Start here"])
        XCTAssertEqual(edited.project.cuts[0].action, "\nStart here")
        XCTAssertThrowsError(try StoryGraphEditingService.applying([], draft: draft, to: document, removing: [0]))
        XCTAssertThrowsError(try StoryGraphEditingService.applying([], draft: draft, to: document, removing: [999]))
    }
}
