import AppKit
import XCTest
@testable import Cinema

final class CinemaContextMenuTests: XCTestCase {
    func testTextEditingMenuKeepsOnlyEssentialEditingActions() {
        let baseMenu = NSMenu()
        baseMenu.addItem(NSMenuItem(title: "Copy", action: NSSelectorFromString("copy:"), keyEquivalent: ""))
        baseMenu.addItem(NSMenuItem(title: "Paste", action: NSSelectorFromString("paste:"), keyEquivalent: ""))
        baseMenu.addItem(.separator())
        baseMenu.addItem(NSMenuItem(title: "Font", action: NSSelectorFromString("orderFrontFontPanel:"), keyEquivalent: ""))
        baseMenu.addItem(NSMenuItem(title: "Speech", action: NSSelectorFromString("startSpeaking:"), keyEquivalent: ""))

        let result = CinemaContextMenu.textEditingMenu(from: baseMenu)
        let titles = result.items.filter { !$0.isSeparatorItem }.map(\.title)

        XCTAssertEqual(titles, ["Copy", "Paste"])
        XCTAssertFalse(result.items.last?.isSeparatorItem == true)
    }
}
