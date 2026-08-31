import AppKit

protocol CinemaManagedContextMenuView: AnyObject {}

enum CinemaContextMenu {
    private static let allowedTextEditingActions: Set<String> = [
        "undo:",
        "redo:",
        "cut:",
        "copy:",
        "paste:",
        "pasteAsPlainText:",
        "delete:",
        "selectAll:"
    ]

    static func textEditingMenu(from baseMenu: NSMenu?) -> NSMenu {
        let filteredMenu = NSMenu()
        var separatorPending = false

        for item in baseMenu?.items ?? [] {
            if item.isSeparatorItem {
                separatorPending = !filteredMenu.items.isEmpty
                continue
            }

            guard let action = item.action,
                  allowedTextEditingActions.contains(NSStringFromSelector(action)),
                  let copiedItem = item.copy() as? NSMenuItem else {
                continue
            }

            if separatorPending, !filteredMenu.items.isEmpty {
                filteredMenu.addItem(.separator())
            }
            filteredMenu.addItem(copiedItem)
            separatorPending = false
        }

        return filteredMenu
    }
}

final class CinemaContextMenuMonitor {
    static let shared = CinemaContextMenuMonitor()
    private var eventMonitor: Any?

    private init() {}

    func start() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { event in
            Self.filterTextMenu(for: event)
            return event
        }
    }

    private static func filterTextMenu(for event: NSEvent) {
        guard let window = event.window,
              let hitView = window.contentView?.hitTest(event.locationInWindow) else {
            return
        }

        if let textView = nearestTextView(from: hitView), !(textView is CinemaManagedContextMenuView) {
            textView.menu = CinemaContextMenu.textEditingMenu(from: textView.menu(for: event))
            return
        }

        if let textField = nearestTextField(from: hitView) {
            textField.menu = CinemaContextMenu.textEditingMenu(from: textField.menu(for: event))
        }
    }

    private static func nearestTextView(from view: NSView) -> NSTextView? {
        var candidate: NSView? = view
        while let current = candidate {
            if let textView = current as? NSTextView { return textView }
            candidate = current.superview
        }
        return nil
    }

    private static func nearestTextField(from view: NSView) -> NSTextField? {
        var candidate: NSView? = view
        while let current = candidate {
            if let textField = current as? NSTextField { return textField }
            candidate = current.superview
        }
        return nil
    }
}
