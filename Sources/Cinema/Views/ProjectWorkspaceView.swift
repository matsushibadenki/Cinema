import SwiftUI

/// Both tabs edit the same document bindings; switching tabs does not copy project state.
struct ProjectWorkspaceView: View {
    enum Tab: Hashable { case design, performance }

    @Binding var project: StoryboardProject
    @Binding var audioData: [String: Data]
    @Binding var videoData: [String: Data]
    var documentURL: URL?
    var language: String
    @State private var selection: Tab = .design
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Picker(t("プロジェクト", "Project", "项目"), selection: $selection) {
                    Text(CinemaStrings.text(.projectSettings, language: language)).tag(Tab.design)
                    Text(t("声・演技タイムライン", "Voice / Performance Timeline", "声音与表演时间线")).tag(Tab.performance)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                Button(CinemaStrings.text(.close, language: language)) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
            Divider()
            // Keep each tab mounted so its editors, scroll position and playback state survive switching.
            ZStack {
                ProjectSettingsView(context: $project.projectContext, appLanguage: language, isEmbedded: true)
                    .opacity(selection == .design ? 1 : 0)
                    .allowsHitTesting(selection == .design)
                    .disabled(selection != .design)
                    .accessibilityHidden(selection != .design)
                PerformancePlanView(project: $project, audioData: $audioData, videoData: $videoData,
                                    documentURL: documentURL, language: language, isEmbedded: true)
                    .opacity(selection == .performance ? 1 : 0)
                    .allowsHitTesting(selection == .performance)
                    .disabled(selection != .performance)
                    .accessibilityHidden(selection != .performance)
            }
        }
        .frame(minWidth: 740, idealWidth: 860, minHeight: 660, idealHeight: 740)
        .background(CinemaDesign.panelBackground)
    }

    private func t(_ ja: String, _ en: String, _ zh: String) -> String {
        language == "en" ? en : language == "zh-Hans" ? zh : ja
    }
}
