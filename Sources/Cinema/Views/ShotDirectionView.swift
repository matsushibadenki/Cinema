import SwiftUI

struct ShotDirectionView: View {
    @Binding var settings: AIShotSettings
    var language: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            direction(t("カメラワーク", "Camera Movement", "镜头运动"), group: 0, value: $settings.cameraMovement)
            direction(t("撮り方・時間演出", "Shooting / Time", "拍摄／时间效果"), group: 1, value: Binding(get: { settings.shootingTechnique ?? "" }, set: { settings.shootingTechnique = $0.isEmpty ? nil : $0 }))
            direction(t("次への切り替え", "Transition to Next Cut", "下一镜头转场"), group: 2, value: $settings.transition)
        }
    }
    private func direction(_ title: String, group: Int, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.bold())
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .help(t("プリセットを選び、秒数・速さ・被写体・方向などを自由に追記できます。選択し直すと、この欄の内容を置き換えます。生成AIへの指示であり、動画編集効果の自動適用ではありません。", "Choose a preset, then freely edit duration, speed, subject or direction. Choosing another replaces this field. These are AI instructions; they do not automatically apply video editing effects.", "选择预设后，可自由补充时长、速度、主体或方向。重新选择会替换此栏内容。这些是AI指令，不会自动应用视频剪辑效果。"))
                Spacer()
                Menu(t("プリセット", "Presets", "预设")) {
                    Button(t("なし", "None", "无")) { value.wrappedValue = "" }
                    Divider()
                    ForEach(ShotDirectionPreset.all.filter { $0.group == group }) { preset in
                        Button(String(format: "%02d", preset.id) + "  " + preset.name(language)) { value.wrappedValue = preset.value }
                    }
                }
                .fixedSize()
            }
            TextField(t("自由入力", "Free text", "自由输入"), text: value, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
        }
    }
    private func t(_ ja: String, _ en: String, _ zh: String) -> String { language == "en" ? en : language == "zh-Hans" ? zh : ja }
}
