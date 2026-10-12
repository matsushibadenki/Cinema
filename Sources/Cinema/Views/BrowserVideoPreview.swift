import SwiftUI
import AVKit

struct BrowserVideoSelection: Identifiable {
    var id = UUID()
    var url: URL
    var title: String
    var fileName: String? = nil
}

struct BrowserVideoPreview: View {
    var selection: BrowserVideoSelection
    var language: String
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var failure: String?
    @State private var observation: NSKeyValueObservation?
    private func text(_ ja: String, _ en: String, _ zh: String) -> String { language == "en" ? en : language == "zh-Hans" ? zh : ja }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(selection.title).font(.headline).lineLimit(2)
                Spacer()
                Button(text("閉じる", "Close", "关闭")) { dismiss() }
            }
            BrowserVideoSurface(player: player).frame(minHeight: 240)
            if let failure { Text(text("動画を再生できません：", "Unable to play video: ", "无法播放视频：") + failure).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
            Text(selection.fileName ?? selection.url.lastPathComponent).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }.padding(16).frame(minWidth: 380, idealWidth: 680, minHeight: 360, idealHeight: 480)
            .onAppear {
                let item = AVPlayerItem(url: selection.url)
                player = AVPlayer(playerItem: item)
                observation = item.observe(\.status, options: [.initial, .new]) { observed, _ in
                    guard observed.status == .failed else { return }
                    let message = observed.error?.localizedDescription ?? ""
                    Task { @MainActor in failure = message }
                }
            }
            .onDisappear {
                observation = nil
                player?.pause(); player?.replaceCurrentItem(with: nil); player = nil
            }
    }
}

private struct BrowserVideoSurface: NSViewRepresentable {
    var player: AVPlayer?
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .inline
        view.showsSharingServiceButton = false
        view.videoGravity = .resizeAspect
        view.player = player
        return view
    }
    func updateNSView(_ view: AVPlayerView, context: Context) { view.player = player }
    static func dismantleNSView(_ view: AVPlayerView, coordinator: ()) { view.player = nil }
}
