import SwiftUI

struct PerformanceMixView: View {
    @Binding var mix: PerformanceAudioMixSettings?
    var start: PerformanceTime
    var end: PerformanceTime
    var language: String
    private func t(_ ja: String, _ en: String, _ zh: String) -> String { language == "en" ? en : language == "zh-Hans" ? zh : ja }
    private var settings: Binding<PerformanceAudioMixSettings> {
        Binding(get: { mix ?? PerformanceAudioMixSettings() }, set: { mix = $0 })
    }
    private func seconds(_ value: Binding<PerformanceTime>) -> Binding<Double> {
        Binding(get: { value.wrappedValue.seconds }, set: { value.wrappedValue.seconds = $0 })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("書き出し時の音量・フェード", "Export Volume / Fades", "导出音量与淡入淡出")).font(.caption).foregroundStyle(.secondary)
            HStack {
                Text(t("音量", "Volume", "音量"))
                Slider(value: settings.volume, in: 0...1)
                    .accessibilityLabel(t("音量", "Volume", "音量"))
                Text(String(format: "%.0f%%", settings.wrappedValue.volume * 100)).monospacedDigit().frame(width: 48)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { fadeIn; fadeOut }
                VStack(alignment: .leading, spacing: 8) { fadeIn; fadeOut }
            }
            if !settings.wrappedValue.isValid(start: start, end: end) {
                Text(t("フェードの合計を配置の長さ以内にしてください。", "Total fade duration must fit within the placement.", "淡入淡出总时长必须在片段长度内。")).font(.caption).foregroundStyle(.orange)
            }
        }
    }
    private var fadeIn: some View {
        HStack {
            Text(t("フェードイン秒", "Fade In (s)", "淡入秒"))
            TextField("0", value: seconds(settings.fadeIn), format: .number).frame(width: 80)
        }.textFieldStyle(.roundedBorder)
    }
    private var fadeOut: some View {
        HStack {
            Text(t("フェードアウト秒", "Fade Out (s)", "淡出秒"))
            TextField("0", value: seconds(settings.fadeOut), format: .number).frame(width: 80)
        }.textFieldStyle(.roundedBorder)
    }
}
