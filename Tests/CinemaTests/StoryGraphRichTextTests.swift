import XCTest
@testable import Cinema

final class StoryGraphRichTextTests: XCTestCase {
    typealias Object = StoryGraphService.Object
    func run(_ text: String, mark: String = "bold") -> Object {
        ["type": "text", "text": text, "marks": [["type": mark]], "extensions": ["custom": "retain"]]
    }
    func document(_ runs: [Object]) -> Object {
        ["type": "document", "content": [["id": "stable-paragraph", "type": "paragraph", "attrs": ["dir": "rtl"], "content": runs], ["id": "image", "type": "image", "altText": "写真", "src": "asset.png", "caption": [run("caption")]]], "metadata": ["keep": true]]
    }
    func testUnicodeEditPreservesParagraphMarksImageAndMetadata() throws {
        let original = document([run("朝 👨‍👩‍👧‍👦 駅"), run(" remains", mark: "italic")])
        var expected = original
        var blocks = original["content"] as! [Object]
        var runs = blocks[0]["content"] as! [Object]
        runs[0]["text"] = "夜 👨‍👩‍👧‍👦 港"
        blocks[0]["content"] = runs
        expected["content"] = blocks
        // A change within one run may contain multiple changed characters.
        let result = try StoryGraphRichText.replacing(original, with: "夜 👨‍👩‍👧‍👦 港 remains\n写真caption")
        XCTAssertEqual(result as NSDictionary, expected as NSDictionary)
    }
    func testCrossFormattingAndImageEditsAreRejected() throws {
        let original = document([run("Bold"), run("Italic", mark: "italic")])
        for text in ["Changed\n写真caption", "BoldItalic\n違うcaption", "Bold!Italic\n写真caption", "BoldItalic 写真caption"] {
            XCTAssertThrowsError(try StoryGraphRichText.replacing(original, with: text))
        }
    }
    func testMultipleParagraphsKeepTheirBoundariesAndIDs() throws {
        let first = StoryGraphService.paragraph("First")
        let second = StoryGraphService.paragraph("第二段落")
        let original: Object = ["type": "document", "content": [first, second]]
        let result = try StoryGraphRichText.replacing(original, with: "First\n第二本文")
        let blocks = result["content"] as! [Object]
        XCTAssertEqual(blocks[0] as NSDictionary, first as NSDictionary)
        XCTAssertEqual(blocks[1]["id"] as? String, second["id"] as? String)
        XCTAssertThrowsError(try StoryGraphRichText.replacing(original, with: "First 第二段落"))
    }
    func testUnchangedTreeAndEmptyRunInsertion() throws {
        let original = document([run("")])
        XCTAssertEqual(try StoryGraphRichText.replacing(original, with: "\n写真caption") as NSDictionary, original as NSDictionary)
        XCTAssertEqual(try StoryGraphService.plainText(StoryGraphRichText.replacing(original, with: "New\n写真caption")), "New\n写真caption")
    }
}
