import SwiftUI
import UniformTypeIdentifiers

@main
struct CinemaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("showsCutActionControls") private var showsCutActionControls = true

    var body: some Scene {
        DocumentGroup(newDocument: StoryboardDocument()) { file in
            ContentView(document: file.$document)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("現在のページをプリント...") {
                    NotificationCenter.default.post(name: .printCurrentStoryboardPage, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }

            CommandMenu("絵コンテ") {
                Toggle("ト書き下のボタンを表示", isOn: $showsCutActionControls)
                    .keyboardShortcut("b", modifiers: [.command, .option])
            }
        }

        Settings {
            SettingsView()
        }
    }
}

extension Notification.Name {
    static let printCurrentStoryboardPage = Notification.Name("printCurrentStoryboardPage")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
