import SwiftUI
import UniformTypeIdentifiers

@main
struct CinemaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("showsCutActionControls") private var showsCutActionControls = true
    @AppStorage("storyboardTextBaseFontSize") private var storyboardTextBaseFontSize = 11.0

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

                Divider()

                Menu("内容 / ト書きの文字サイズ") {
                    textSizeButton("小", size: 9.0)
                    textSizeButton("標準", size: 11.0)
                    textSizeButton("大", size: 13.0)
                    textSizeButton("特大", size: 15.0)
                }
            }
        }

        Settings {
            SettingsView()
        }
        .windowResizability(.contentMinSize)
    }

    private func textSizeButton(_ title: String, size: Double) -> some View {
        Button {
            storyboardTextBaseFontSize = size
        } label: {
            if storyboardTextBaseFontSize == size {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
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
