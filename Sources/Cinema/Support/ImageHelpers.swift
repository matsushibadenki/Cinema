import AppKit
import Foundation

enum ImageHelpers {
    static func nsImage(from data: Data?) -> NSImage? {
        guard let data else { return nil }
        return NSImage(data: data)
    }
}
