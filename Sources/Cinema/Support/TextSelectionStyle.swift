import AppKit

struct TextSelectionStyle {
    var fontFamily: String
    var fontSize: CGFloat
    var color: NSColor
    var isBold: Bool
    var isItalic: Bool
    var isUnderline: Bool
    var letterSpacing: CGFloat
    var lineSpacing: CGFloat
    var alignment: NSTextAlignment
}

enum TextSelectionStyleApplicator {
    static var activeTextView: NSTextView?

    static func apply(_ style: TextSelectionStyle) {
        guard let textView = activeTextView ?? NSApp.keyWindow?.firstResponder as? NSTextView else { return }

        let range = textView.selectedRange()
        let targetRange = range.length > 0
            ? range
            : NSRange(location: range.location, length: 0)
        let font = makeFont(from: style)
        let paragraphRange = paragraphRange(in: textView.string, for: targetRange)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = style.alignment
        paragraphStyle.lineSpacing = max(style.lineSpacing - 1, 0) * style.fontSize

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: style.color,
            .kern: style.letterSpacing,
            .paragraphStyle: paragraphStyle
        ]
        if style.isUnderline {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        } else {
            attributes[.underlineStyle] = 0
        }

        textView.typingAttributes.merge(attributes) { _, new in new }

        guard range.length > 0 else { return }
        textView.textStorage?.beginEditing()
        textView.textStorage?.addAttributes(attributes, range: range)
        if paragraphRange.length > 0 {
            textView.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: paragraphRange)
        }
        textView.textStorage?.endEditing()
    }

    private static func makeFont(from style: TextSelectionStyle) -> NSFont {
        let traits = NSFontTraitMask(
            rawValue: (style.isBold ? NSFontTraitMask.boldFontMask.rawValue : 0)
                | (style.isItalic ? NSFontTraitMask.italicFontMask.rawValue : 0)
        )
        if style.fontFamily == "System" {
            let weight: NSFont.Weight = style.isBold ? .bold : .regular
            let baseFont = NSFont.systemFont(ofSize: style.fontSize, weight: weight)
            return style.isItalic
                ? NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                : baseFont
        }

        return NSFontManager.shared.font(
            withFamily: style.fontFamily,
            traits: traits,
            weight: style.isBold ? 9 : 5,
            size: style.fontSize
        ) ?? NSFont.systemFont(ofSize: style.fontSize, weight: style.isBold ? .bold : .regular)
    }

    private static func paragraphRange(in text: String, for range: NSRange) -> NSRange {
        let nsText = text as NSString
        let safeLocation = min(range.location, nsText.length)
        let safeLength = min(range.length, max(nsText.length - safeLocation, 0))
        return nsText.paragraphRange(for: NSRange(location: safeLocation, length: safeLength))
    }
}
