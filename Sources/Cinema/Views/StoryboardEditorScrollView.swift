import AppKit

/// An empty manuscript must still have a text view covering its visible editor.
final class StoryboardEditorScrollView: NSScrollView {
    override func layout() {
        super.layout()
        guard let textView = documentView as? NSTextView else { return }
        let viewport = contentView.bounds.size
        guard viewport.width > 0, viewport.height > 0 else { return }
        textView.minSize = NSSize(width: 0, height: viewport.height)
        let size = NSSize(width: viewport.width, height: max(textView.frame.height, viewport.height))
        if textView.frame.size != size {
            textView.setFrameSize(size)
        }
    }
}
