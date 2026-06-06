import AppKit
import SwiftUI

@MainActor
enum PrintService {
    static func printPage(document: StoryboardDocument, pageIndex: Int) {
        let pageSize = NSSize(width: 595, height: 842)
        let view = NSHostingView(rootView: PrintablePageView(document: document, pageIndex: pageIndex))
        print(view: view, pageSize: pageSize)
    }

    static func printScriptPage(document: StoryboardDocument, pageIndex: Int) {
        let pageSize = NSSize(width: ScriptPageLayout.pageSize.width, height: ScriptPageLayout.pageSize.height)
        let view = NSHostingView(
            rootView: ScriptPageView(
                cuts: document.project.cuts,
                pageIndex: pageIndex,
                documentTitle: document.project.title
            )
        )
        print(view: view, pageSize: pageSize)
    }

    private static func print(view: NSView, pageSize: NSSize) {
        view.frame = CGRect(origin: .zero, size: pageSize)
        view.layoutSubtreeIfNeeded()

        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.paperSize = pageSize
        info.topMargin = 0
        info.bottomMargin = 0
        info.leftMargin = 0
        info.rightMargin = 0
        info.horizontalPagination = .fit
        info.verticalPagination = .fit

        let operation = NSPrintOperation(view: view, printInfo: info)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
    }
}
