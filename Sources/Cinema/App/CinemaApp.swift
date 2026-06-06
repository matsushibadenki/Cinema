import SwiftUI
import UniformTypeIdentifiers

@main
struct CinemaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("showsCutActionControls") private var showsCutActionControls = true
    @AppStorage("storyboardTextBaseFontSize") private var storyboardTextBaseFontSize = 11.0
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.japanese.rawValue
    private let settingsWindowID = "settings-window"

    var body: some Scene {
        DocumentGroup(newDocument: StoryboardDocument()) { file in
            ContentView(document: file.$document)
        }
        .commands {
            AppCommands(
                showsCutActionControls: $showsCutActionControls,
                storyboardTextBaseFontSize: $storyboardTextBaseFontSize,
                appLanguage: appLanguage,
                settingsWindowID: settingsWindowID
            )
        }

        Window("設定", id: settingsWindowID) {
            SettingsView()
        }
        .defaultSize(width: 700, height: 700)
    }
}

private struct AppCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @Binding var showsCutActionControls: Bool
    @Binding var storyboardTextBaseFontSize: Double
    var appLanguage: String
    var settingsWindowID: String

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("設定...") {
                openWindow(id: settingsWindowID)
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(after: .newItem) {
            Button(CinemaStrings.text(.print, language: appLanguage) + "...") {
                NotificationCenter.default.post(name: .printCurrentStoryboardPage, object: nil)
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }

        CommandMenu(CinemaStrings.text(.storyboard, language: appLanguage)) {
            Toggle(CinemaStrings.text(.dialogue, language: appLanguage), isOn: $showsCutActionControls)
                .keyboardShortcut("b", modifiers: [.command, .option])

            Divider()

            Menu("\(CinemaStrings.text(.content, language: appLanguage)) / \(CinemaStrings.text(.dialogue, language: appLanguage))") {
                textSizeButton("小", size: 9.0)
                textSizeButton("標準", size: 11.0)
                textSizeButton("大", size: 13.0)
                textSizeButton("特大", size: 15.0)
            }
        }
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
