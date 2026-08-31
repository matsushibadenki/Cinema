import SwiftUI

struct ProjectSettingsView: View {
    @Binding var context: ProjectContext
    var appLanguage: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CinemaDesign.ink)

                Text(t(.projectSettings))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CinemaDesign.ink)

                Spacer()

                Button(t(.close)) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .frame(height: 52)

            Rectangle()
                .fill(CinemaDesign.strongBorder)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 10) {
                Text(t(.projectDirective))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CinemaDesign.ink)

                Text(t(.projectSettingsHelp))
                    .font(.system(size: 11))
                    .foregroundStyle(CinemaDesign.mutedInk)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $context.productionDirective)
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                        .padding(8)

                    if context.productionDirective.isEmpty {
                        Text(t(.projectDirectivePlaceholder))
                            .font(.system(size: 13))
                            .foregroundStyle(CinemaDesign.quietInk)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 17)
                            .allowsHitTesting(false)
                    }
                }
                .background(CinemaDesign.insetSurface)
                .overlay {
                    Rectangle()
                        .stroke(CinemaDesign.strongBorder, lineWidth: 0.8)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 620, idealWidth: 720, minHeight: 420, idealHeight: 520)
        .background(CinemaDesign.panelBackground)
    }

    private func t(_ key: CinemaTextKey) -> String {
        CinemaStrings.text(key, language: appLanguage)
    }
}
