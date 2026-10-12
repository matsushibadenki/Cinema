import XCTest
@testable import Cinema

final class StoryGraphTests: XCTestCase {
    func fixture() throws -> Data {
        try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: "story-workspace-v1", withExtension: "json", subdirectory: "Fixtures")))
    }

    func object(_ data: Data) throws -> NSDictionary {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }

    func testSharedFixtureRoundTripPreservesEveryField() throws {
        let source = try fixture()
        let document = try StoryGraphService.read(source)
        XCTAssertEqual(document.project.cuts.count, 5)
        XCTAssertTrue(document.project.cuts[0].action.contains("終電"))
        XCTAssertEqual(try object(StoryGraphService.write(document)), try object(source))
        let reopened = try StoryboardDocument(package: document.packageWrapper())
        XCTAssertEqual(reopened.storyGraphSource, source)
        XCTAssertEqual(try object(StoryGraphService.write(reopened)), try object(source))
    }

    func testV3EditUpdatesCanonicalAndAdapterWithoutDuplicatingManuscript() throws {
        let workspace = try JSONSerialization.jsonObject(with: fixture())
        let source = try StoryGraphService.encode(["format": StoryGraphService.format, "version": 3, "workspace": workspace])
        var document = try StoryGraphService.read(source)
        document.project.title = "映画 / Film / 电影"
        document.project.cuts[0].action = "新しい本文\nNew text\n新的内容 👨‍👩‍👧‍👦"
        document.project.cuts[0].subtitle = "新しい場面"
        let written = try StoryGraphService.write(document)
        let reopened = try StoryGraphService.read(written)
        XCTAssertEqual(reopened.project.title, document.project.title)
        XCTAssertEqual(reopened.project.cuts[0].action, document.project.cuts[0].action)
        XCTAssertEqual(reopened.project.cuts[0].subtitle, "新しい場面")
        let before = try StoryGraphService.parse(source)
        let after = try StoryGraphService.parse(written)
        XCTAssertEqual((before.native["graph"] as? NSDictionary)?["edges"] as? NSDictionary,
                       (after.native["graph"] as? NSDictionary)?["edges"] as? NSDictionary)
        let shared = try XCTUnwrap(after.workspace)
        let graph = shared["graph"] as! [String: Any]
        let ext = graph["extensions"] as! [String: Any]
        let native = ext[StoryGraphService.adapter] as! [String: Any]
        let nodes = (native["graph"] as! [String: Any])["nodes"] as! [String: [String: Any]]
        for node in nodes.values where node["type_id"] as? String == "story.scene" {
            XCTAssertNil((node["properties"] as! [String: Any])["canonical"])
        }
    }

    func testLegacyInlineAndCentralDocumentStore() throws {
        let native = try StoryGraphService.parse(fixture()).native
        for version in [1, 2] {
            var value = native
            if version == 2 {
                var graph = value["graph"] as! [String: Any]
                var nodes = graph["nodes"] as! [String: [String: Any]]
                var store: [String: Any] = [:]
                for (id, var node) in nodes where node["type_id"] as? String == "story.scene" {
                    var properties = node["properties"] as! [String: Any]
                    store[id] = properties["canonical"]
                    properties["canonical"] = ["documentRef": id]
                    node["properties"] = properties
                    nodes[id] = node
                }
                graph["nodes"] = nodes
                value["graph"] = graph
                value["extensions"] = [StoryGraphService.store: store]
            }
            let source = try StoryGraphService.encode(["format": StoryGraphService.format, "version": version, "document": value])
            var document = try StoryGraphService.read(source)
            document.project.cuts[0].action = "Edited"
            let output = try StoryGraphService.write(document)
            XCTAssertEqual(try StoryGraphService.read(output).project.cuts[0].action, "Edited")
        }
    }

    func testFreshExportIncludesDialogueAndSequentialEdges() throws {
        let cut = StoryboardCut(cutNumber: 1, situation: "駅", action: "歩く", dialogueLines: [DialogueLine(speaker: "灯", dialogue: "こんにちは")], subtitle: "場面一")
        let document = StoryboardDocument(project: StoryboardProject(title: "Cinema", cuts: [cut, StoryboardCut(cutNumber: 2, action: "雨", subtitle: "場面二")]))
        let output = try StoryGraphService.write(document)
        let restored = try StoryGraphService.read(output)
        XCTAssertEqual(restored.project.cuts.count, 2)
        XCTAssertEqual(restored.project.cuts[0].action, "駅\n歩く\n灯: こんにちは")
        XCTAssertEqual(((try StoryGraphService.parse(output).native["graph"] as? [String: Any])?["edges"] as? [String: Any])?.count, 1)
    }

    func testStructuralChangesRequireExplicitNewGraph() throws {
        var document = try StoryGraphService.read(fixture())
        document.project.cuts.removeFirst()
        XCTAssertThrowsError(try StoryGraphService.write(document))
        XCTAssertEqual(try StoryGraphService.read(StoryGraphService.write(document, asNewGraph: true)).project.cuts.count, 4)
    }

    func testBlankSceneHeadingsSurviveCinemaSaveAndReopen() throws {
        let source = try StoryGraphService.write(StoryboardDocument(project: StoryboardProject(cuts: [StoryboardCut(cutNumber: 1, action: "本文")])) )
        let imported = try StoryGraphService.read(source)
        let reopened = try StoryboardDocument(package: imported.packageWrapper())
        let before = try StoryGraphService.parse(source)
        let after = try StoryGraphService.parse(StoryGraphService.write(reopened))
        XCTAssertEqual(before.native as NSDictionary, after.native as NSDictionary)
    }

    func testRichProjectionUsesCodeAndImageCaptionContract() throws {
        XCTAssertEqual(try StoryGraphService.plainText(["type": "code_block", "source": "let value = 1"]), "let value = 1")
        XCTAssertEqual(try StoryGraphService.plainText(["type": "image", "altText": "駅", "caption": [["type": "text", "text": "の写真"]]]), "駅の写真")
    }

    func testInvalidAndFutureFormatsAreRejected() throws {
        for value: [String: Any] in [[:], ["format": StoryGraphService.format, "version": 4], ["format": StoryGraphService.format, "version": 3, "workspace": [:], "document": [:]]] {
            XCTAssertThrowsError(try StoryGraphService.read(StoryGraphService.encode(value)))
        }
        var root = try StoryGraphService.parse(fixture()).root
        var graph = root["graph"] as! [String: Any]
        graph["documentId"] = UUID().uuidString
        root["graph"] = graph
        XCTAssertThrowsError(try StoryGraphService.read(StoryGraphService.encode(root)))
    }

    func testRichTextPreservedAndSingleRunEditRetainsMarks() throws {
        var root = try StoryGraphService.parse(fixture()).root
        var canonical = root["document"] as! [String: Any]
        var blocks = canonical["content"] as! [[String: Any]]
        var paragraphs = blocks[2]["content"] as! [[String: Any]]
        var inline = paragraphs[0]["content"] as! [[String: Any]]
        inline[0]["marks"] = [["type": "bold"]]
        paragraphs[0]["content"] = inline
        blocks[2]["content"] = paragraphs
        canonical["content"] = blocks
        root["document"] = canonical
        let source = try StoryGraphService.encode(root)
        var document = try StoryGraphService.read(source)
        XCTAssertEqual(try object(source), try object(StoryGraphService.write(document)))
        document.project.cuts[0].action = "Edited"
        let reopened = try StoryboardDocument(package: document.packageWrapper())
        XCTAssertEqual(reopened.storyGraphSource, source)
        let written = try StoryGraphService.write(reopened)
        XCTAssertEqual(try StoryGraphService.read(written).project.cuts[0].action, "Edited")
        let snapshot = try StoryGraphService.parse(written)
        let originalSnapshot = try StoryGraphService.parse(source)
        XCTAssertEqual((snapshot.native["graph"] as? NSDictionary)?["edges"] as? NSDictionary,
                       (originalSnapshot.native["graph"] as? NSDictionary)?["edges"] as? NSDictionary)
        XCTAssertEqual(snapshot.native["placement"] as? NSDictionary, originalSnapshot.native["placement"] as? NSDictionary)
        let rich = try StoryGraphService.canonical(snapshot.scenes[0], native: snapshot.native)
        let editedBlocks = rich["content"] as! [[String: Any]]
        let editedInline = editedBlocks[0]["content"] as! [[String: Any]]
        XCTAssertEqual(editedInline[0]["marks"] as? NSArray, inline[0]["marks"] as? NSArray)
        XCTAssertNoThrow(try StoryGraphService.write(document, asNewGraph: true))
    }
}
