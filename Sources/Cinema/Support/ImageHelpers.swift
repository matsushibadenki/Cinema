import AppKit
import Foundation

enum ImageHelpers {
    static func nsImage(from data: Data?) -> NSImage? {
        guard let data else { return nil }
        return NSImage(data: data)
    }

    static func pngDataByCropping(_ data: Data, toAspectRatio aspectRatio: CGFloat) -> Data {
        guard aspectRatio > 0,
              let image = NSImage(data: data),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return data
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        guard width > 0, height > 0 else { return data }

        let currentRatio = width / height
        let cropRect: CGRect
        if currentRatio > aspectRatio {
            let cropWidth = height * aspectRatio
            cropRect = CGRect(x: (width - cropWidth) / 2, y: 0, width: cropWidth, height: height)
        } else {
            let cropHeight = width / aspectRatio
            cropRect = CGRect(x: 0, y: (height - cropHeight) / 2, width: width, height: cropHeight)
        }

        guard let cropped = cgImage.cropping(to: cropRect.integral) else { return data }
        let bitmap = NSBitmapImageRep(cgImage: cropped)
        return bitmap.representation(using: .png, properties: [:]) ?? data
    }
}
