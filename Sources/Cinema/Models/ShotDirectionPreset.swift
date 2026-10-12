import Foundation

struct ShotDirectionPreset: Identifiable {
    let id: Int
    let ja: String
    let en: String
    let zh: String
    let instruction: String
    var group: Int { (id - 1) / 8 }
    func name(_ language: String) -> String { language == "en" ? en : language == "zh-Hans" ? zh : ja }
    static let all: [Self] = [
        .init(id: 1, ja: "パン", en: "Pan", zh: "水平摇摄", instruction: "Pan the camera horizontally."),
        .init(id: 2, ja: "ティルト", en: "Tilt", zh: "垂直摇摄", instruction: "Tilt the camera vertically."),
        .init(id: 3, ja: "ドリーイン", en: "Dolly in", zh: "推进", instruction: "Move the camera physically toward the subject."),
        .init(id: 4, ja: "ズームイン", en: "Zoom in", zh: "变焦拉近", instruction: "Zoom in with the lens; keep the camera position fixed."),
        .init(id: 5, ja: "トラッキング", en: "Tracking shot", zh: "跟拍", instruction: "Move the camera alongside the moving subject."),
        .init(id: 6, ja: "オービット", en: "Orbit (Arc shot)", zh: "环绕拍摄", instruction: "Move the camera in an arc around the subject."),
        .init(id: 7, ja: "クレーンアップ", en: "Crane up", zh: "升降上移", instruction: "Raise the camera upward on a crane."),
        .init(id: 8, ja: "ドリーズーム", en: "Dolly zoom (Vertigo)", zh: "滑动变焦", instruction: "Dolly and counter-zoom to keep the subject size constant while changing background perspective."),
        .init(id: 9, ja: "ラックフォーカス", en: "Rack focus", zh: "焦点转移", instruction: "Shift focus from foreground to background."),
        .init(id: 10, ja: "手持ち風", en: "Handheld", zh: "手持拍摄", instruction: "Use subtle handheld camera shake."),
        .init(id: 11, ja: "FPV", en: "FPV drone shot", zh: "FPV无人机", instruction: "Use a dynamic first-person drone flight shot."),
        .init(id: 12, ja: "ダッチアングル", en: "Dutch angle", zh: "荷兰角", instruction: "Tilt the camera roll axis to create a slanted horizon."),
        .init(id: 13, ja: "スローモーション", en: "Slow motion", zh: "慢动作", instruction: "Present the action in slow motion."),
        .init(id: 14, ja: "スピードランプ", en: "Speed ramp", zh: "速度渐变", instruction: "Ramp playback speed between slow and fast motion."),
        .init(id: 15, ja: "タイムラプス", en: "Time-lapse", zh: "延时摄影", instruction: "Compress a long passage of time into a time-lapse shot."),
        .init(id: 16, ja: "フリーズフレーム", en: "Freeze frame", zh: "定格", instruction: "Hold the action on a frozen frame."),
        .init(id: 17, ja: "ジャンプカット", en: "Jump cut", zh: "跳切", instruction: "Jump forward in time within the same framing."),
        .init(id: 18, ja: "マッチカット", en: "Match cut", zh: "匹配剪辑", instruction: "Match shape or motion across the cut."),
        .init(id: 19, ja: "ホイップパン", en: "Whip pan", zh: "甩镜转场", instruction: "Use a fast whip pan into the next shot."),
        .init(id: 20, ja: "クロスディゾルブ", en: "Cross dissolve", zh: "交叉溶解", instruction: "Overlap the outgoing and incoming shots in a cross dissolve."),
        .init(id: 21, ja: "ワイプ", en: "Wipe", zh: "划像", instruction: "Replace the outgoing shot with the incoming shot across a moving boundary."),
        .init(id: 22, ja: "スマッシュカット", en: "Smash cut", zh: "突切", instruction: "Cut abruptly from a quiet shot to a dramatically contrasting shot."),
        .init(id: 23, ja: "Jカット", en: "J-cut", zh: "J剪辑", instruction: "Begin the incoming shot's audio before its picture appears."),
        .init(id: 24, ja: "Lカット", en: "L-cut", zh: "L剪辑", instruction: "Continue the outgoing shot's audio over the next shot's picture.")
    ]
    var value: String { "\(en): \(instruction)" }
}
