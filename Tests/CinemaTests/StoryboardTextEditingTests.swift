import AppKit
import XCTest
@testable import Cinema

@MainActor
final class StoryboardTextEditingTests: XCTestCase {
    func testEmptyEditorCoversViewportAndCanReceiveClicksAfterResize() {
        let scroll = StoryboardEditorScrollView(frame: NSRect(x: 0, y: 0, width: 480, height: 220))
        let text = NSTextView(frame: .zero)
        text.isEditable = true
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.textContainer?.widthTracksTextView = true
        text.autoresizingMask = [.width]
        scroll.documentView = text
        for size in [NSSize(width: 480, height: 220), NSSize(width: 210, height: 360)] {
            scroll.setFrameSize(size)
            scroll.layout()
            XCTAssertEqual(text.frame.width, scroll.contentView.bounds.width, accuracy: 0.1)
            XCTAssertGreaterThanOrEqual(text.frame.height, scroll.contentView.bounds.height)
            let point = NSPoint(x: text.bounds.midX, y: text.bounds.midY)
            XCTAssertTrue(text.hitTest(point) === text)
        }
    }

    func testLayoutKeepsScrollableManuscriptHeight() {
        let scroll = StoryboardEditorScrollView(frame: NSRect(x: 0, y: 0, width: 320, height: 180))
        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 320, height: 900))
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        text.textContainer?.widthTracksTextView = true
        text.string = Array(repeating: "本文 / Dialogue / 台词", count: 200).joined(separator: "\n")
        scroll.documentView = text
        scroll.layout()
        text.sizeToFit()
        scroll.layout()
        XCTAssertGreaterThan(text.frame.height, scroll.contentView.bounds.height)
    }
}
