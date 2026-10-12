import SwiftUI
import AppKit
import AVFoundation

/// Uses the same player as the transport so video and mixed audio share one clock.
struct PerformanceVideoSurface: NSViewRepresentable {
    var player: AVPlayer?
    func makeNSView(context: Context) -> PerformanceVideoHost { PerformanceVideoHost() }
    func updateNSView(_ view: PerformanceVideoHost, context: Context) { view.videoLayer.player = player }
    static func dismantleNSView(_ view: PerformanceVideoHost, coordinator: ()) { view.videoLayer.player = nil }
}

final class PerformanceVideoHost: NSView {
    let videoLayer = AVPlayerLayer()
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        videoLayer.videoGravity = .resizeAspect
        videoLayer.backgroundColor = NSColor.black.cgColor
        layer = videoLayer
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func layout() { super.layout(); videoLayer.frame = bounds }
}
