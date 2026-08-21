// SoftwareUpdateController.swift
// Sparkleの更新確認をSwiftUIのメニューから呼び出すための窓口です。

import Foundation
import Sparkle

final class SoftwareUpdateController: NSObject {
    static let shared = SoftwareUpdateController()

    private let updaterController: SPUStandardUpdaterController

    private override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
