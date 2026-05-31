import AppKit
import SwiftUI

@MainActor
enum PrintService {
    static func printPage(document: StoryboardDocument, pageIndex: Int) {
        let pageSize = NSSize(width: 595, height: 842)
        let view = NSHostingView(rootView: PrintablePageView(document: document, pageIndex: pageIndex))
        view.frame = CGRect(origin: .zero, size: pageSize)
        view.layoutSubtreeIfNeeded()

        let printableView = PrintableBitmapView(image: renderedImage(from: view, pageSize: pageSize))
        printableView.frame = CGRect(origin: .zero, size: pageSize)

        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.paperSize = pageSize
        info.topMargin = 0
        info.bottomMargin = 0
        info.leftMargin = 0
        info.rightMargin = 0
        info.horizontalPagination = .fit
        info.verticalPagination = .fit

        let operation = NSPrintOperation(view: printableView, printInfo: info)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
    }

    private static func renderedImage(from view: NSView, pageSize: NSSize) -> NSImage {
        let scale: CGFloat = 2
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pageSize.width * scale),
            pixelsHigh: Int(pageSize.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )

        guard let rep else {
            return NSImage(size: pageSize)
        }

        rep.size = pageSize
        view.cacheDisplay(in: view.bounds, to: rep)

        let image = NSImage(size: pageSize)
        image.addRepresentation(rep)
        return image
    }
}

private final class PrintableBitmapView: NSView {
    private let image: NSImage

    init(image: NSImage) {
        self.image = image
        super.init(frame: CGRect(origin: .zero, size: image.size))
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()
        image.draw(in: bounds, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
    }
}
