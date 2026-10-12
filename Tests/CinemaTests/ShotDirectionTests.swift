import XCTest
import SwiftUI
import AppKit
@testable import Cinema

final class ShotDirectionTests: XCTestCase {
    func testAllPresetsAndFreeTextReachPromptAndPersist() throws {
        XCTAssertEqual(ShotDirectionPreset.all.map(\.id), Array(1...24))
        for group in 0...2 { XCTAssertEqual(ShotDirectionPreset.all.filter { $0.group == group }.count, 8) }
        for preset in ShotDirectionPreset.all {
            var cut = StoryboardCut(cutNumber: 1)
            switch preset.group {
            case 0: cut.aiShotSettings.cameraMovement = preset.value + " 3 seconds, slowly toward Alice"
            case 1: cut.aiShotSettings.shootingTechnique = preset.value + " 自由入力／自由输入"
            default: cut.aiShotSettings.transition = preset.value
            }
            XCTAssertTrue(AIPromptBuilder.cutPrompt(for: cut).contains(preset.instruction))
            let document = StoryboardDocument(project: StoryboardProject(cuts: [cut]))
            let reopened = try StoryboardDocument(package: document.packageWrapper())
            XCTAssertEqual(reopened.project.cuts[0].aiShotSettings, cut.aiShotSettings)
            for language in ["ja", "en", "zh-Hans"] { XCTAssertFalse(preset.name(language).isEmpty) }
        }
        var settings = AIShotSettings(cameraMovement: "任意のカメラ指示", transition: "自由な切り替え")
        settings.shootingTechnique = "Custom timing"
        XCTAssertTrue(settings.promptText.contains("Custom timing"))
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as! [String: Any]
        legacy.removeValue(forKey: "shootingTechnique")
        let decoded = try JSONDecoder().decode(AIShotSettings.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(decoded.shootingTechnique)
        XCTAssertEqual(decoded.cameraMovement, settings.cameraMovement)
        XCTAssertFalse(AIPromptBuilder.requestsContinuityReset(StoryboardCut(cutNumber: 1, aiShotSettings: AIShotSettings(transition: ShotDirectionPreset.all[16].value))))
    }
    @MainActor func testDirectionRendering() async throws {
        guard let path = ProcessInfo.processInfo.environment["CINEMA_SHOT_UI"] else { throw XCTSkip("Set CINEMA_SHOT_UI for visual QA") }
        _ = NSApplication.shared
        let folder = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var settings = AIShotSettings(cameraMovement: ShotDirectionPreset.all[2].value + " 3 seconds, slowly toward Alice", transition: ShotDirectionPreset.all[22].value)
        settings.shootingTechnique = ShotDirectionPreset.all[12].value
        for language in ["ja", "en", "zh-Hans"] {
            for dark in [false, true] {
                let root = ShotDirectionView(settings: .constant(settings), language: language).padding(16)
                    .frame(width: 420, height: 480).background(CinemaDesign.canvasBackground)
                    .environment(\.colorScheme, dark ? .dark : .light)
                let host = NSHostingView(rootView: root)
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 480), styleMask: [.titled], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false; window.contentView = host
                window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                host.layoutSubtreeIfNeeded(); try await Task.sleep(nanoseconds: 100_000_000); host.layoutSubtreeIfNeeded()
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: folder.appendingPathComponent("\(language)-\(dark).png"))
                window.close()
            }
        }
    }
}
