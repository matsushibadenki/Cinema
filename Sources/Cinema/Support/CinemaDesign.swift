import AppKit
import SwiftUI

enum CinemaDesign {
    // MARK: - Base Theme

    static let keyColor = dynamicColor(
        light: (0.41, 0.29, 0.96, 1.0),
        dark: (0.47, 0.34, 1.0, 1.0)
    )

    static let keyColorSoft = dynamicColor(
        light: (0.41, 0.29, 0.96, 0.12),
        dark: (0.47, 0.34, 1.0, 0.18)
    )

    static let canvasBackground = dynamicColor(
        light: (0.965, 0.970, 0.978, 1.0),
        dark: (0.095, 0.100, 0.112, 1.0)
    )

    static let panelBackground = dynamicColor(
        light: (0.978, 0.982, 0.990, 0.99),
        dark: (0.110, 0.115, 0.128, 0.99)
    )

    static let railBackground = dynamicColor(
        light: (0.972, 0.976, 0.985, 0.99),
        dark: (0.102, 0.106, 0.118, 1.0)
    )

    static let cardSurface = dynamicColor(
        light: (0.990, 0.993, 0.998, 1.0),
        dark: (0.135, 0.140, 0.152, 1.0)
    )

    static let mainBlockSurface = dynamicColor(
        light: (0.968, 0.973, 0.980, 1.0),
        dark: (0.126, 0.130, 0.140, 1.0)
    )

    static let editorSurface = dynamicColor(
        light: (0.967, 0.972, 0.979, 1.0),
        dark: (0.129, 0.133, 0.143, 1.0)
    )

    static let insetSurface = dynamicColor(
        light: (0.958, 0.964, 0.974, 1.0),
        dark: (0.136, 0.140, 0.151, 1.0)
    )

    // MARK: - Semantic Colors

    static let pageShadow = dynamicColor(
        light: (0.26, 0.30, 0.36, 0.08),
        dark: (0.0, 0.0, 0.0, 0.18)
    )

    static let fineBorder = dynamicColor(
        light: (0.45, 0.49, 0.58, 0.19),
        dark: (1.0, 1.0, 1.0, 0.08)
    )

    static let strongBorder = dynamicColor(
        light: (0.40, 0.44, 0.52, 0.24),
        dark: (1.0, 1.0, 1.0, 0.14)
    )

    static let warmBorder = dynamicColor(
        light: (0.41, 0.29, 0.96, 0.24),
        dark: (0.47, 0.34, 1.0, 0.34)
    )

    static let ink = dynamicColor(
        light: (0.08, 0.09, 0.12, 1.0),
        dark: (0.94, 0.95, 0.98, 1.0)
    )

    static let mutedInk = dynamicColor(
        light: (0.40, 0.43, 0.50, 1.0),
        dark: (0.66, 0.69, 0.78, 1.0)
    )

    static let quietInk = dynamicColor(
        light: (0.56, 0.60, 0.67, 1.0),
        dark: (0.48, 0.52, 0.60, 1.0)
    )

    static let inverseInk = dynamicColor(
        light: (1.0, 1.0, 1.0, 1.0),
        dark: (0.96, 0.97, 1.0, 1.0)
    )

    static let aiSparkle = keyColor
    static let aiSparkleLight = keyColorSoft
    static let sectionHeader = ink

    static let toolbarBackground = LinearGradient(
        colors: [
            dynamicColor(light: (0.985, 0.988, 0.994, 0.94), dark: (0.112, 0.116, 0.128, 0.96)),
            dynamicColor(light: (0.978, 0.982, 0.989, 0.94), dark: (0.108, 0.112, 0.124, 0.96))
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let toolbarSeparator = LinearGradient(
        colors: [
            fineBorder.opacity(0.0),
            fineBorder.opacity(0.9),
            fineBorder.opacity(0.9),
            fineBorder.opacity(0.0)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let raisedShadow = dynamicColor(
        light: (0.26, 0.30, 0.38, 0.05),
        dark: (0.0, 0.0, 0.0, 0.18)
    )

    static let topHighlight = dynamicColor(
        light: (1.0, 1.0, 1.0, 0.34),
        dark: (1.0, 1.0, 1.0, 0.03)
    )

    static let railIconBackground = dynamicColor(
        light: (0.955, 0.962, 0.985, 0.92),
        dark: (1.0, 1.0, 1.0, 0.08)
    )

    static let railIconStroke = dynamicColor(
        light: (0.42, 0.46, 0.56, 0.10),
        dark: (1.0, 1.0, 1.0, 0.12)
    )

    static let selectedRowSurface = dynamicColor(
        light: (0.41, 0.29, 0.96, 0.10),
        dark: (0.47, 0.34, 1.0, 0.20)
    )

    static let cardStroke = dynamicColor(
        light: (0.44, 0.48, 0.58, 0.13),
        dark: (1.0, 1.0, 1.0, 0.09)
    )

    static let storyboardPaper = Color(red: 0.996, green: 0.994, blue: 0.986)
    static let storyboardPaperAccent = Color(red: 0.985, green: 0.980, blue: 0.962)
    static let storyboardInk = Color(red: 0.10, green: 0.10, blue: 0.11)
    static let storyboardGrid = Color(red: 0.14, green: 0.14, blue: 0.16).opacity(0.92)
    static let storyboardFrameBorder = Color.black.opacity(0.12)
    static let storyboardScreenColumn = Color(red: 0.33, green: 0.33, blue: 0.34)
    static let storyboardDialogueColumn = storyboardPaper
    static let storyboardToolChrome = Color.black.opacity(0.22)
    static let storyboardToolIcon = Color.black.opacity(0.82)

    private static func dynamicColor(
        light: (CGFloat, CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat, CGFloat)
    ) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                let components = isDark ? dark : light
                return NSColor(
                    calibratedRed: components.0,
                    green: components.1,
                    blue: components.2,
                    alpha: components.3
                )
            }
        )
    }
}

struct CinemaPanelModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var isHighlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(CinemaDesign.cardSurface.opacity(isHighlighted ? 0.98 : 0.92))
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isHighlighted ? CinemaDesign.warmBorder : CinemaDesign.cardStroke,
                        lineWidth: isHighlighted ? 0.9 : 0.6
                    )
            }
            .shadow(color: CinemaDesign.raisedShadow.opacity(0.5), radius: 4, x: 0, y: 1)
    }
}

extension View {
    func cinemaPanel(cornerRadius: CGFloat = 14, isHighlighted: Bool = false) -> some View {
        modifier(CinemaPanelModifier(cornerRadius: cornerRadius, isHighlighted: isHighlighted))
    }
}

struct CinemaToolbarButtonStyle: ButtonStyle {
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(
                isActive
                ? CinemaDesign.inverseInk
                : CinemaDesign.ink
            )
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isActive
                        ? CinemaDesign.keyColor
                        : (configuration.isPressed
                           ? CinemaDesign.insetSurface.opacity(0.95)
                           : CinemaDesign.cardSurface.opacity(0.84))
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isActive ? CinemaDesign.keyColor.opacity(0.95) : CinemaDesign.cardStroke,
                        lineWidth: isActive ? 0.9 : 0.6
                    )
            }
            .shadow(color: isActive ? CinemaDesign.keyColor.opacity(0.14) : CinemaDesign.raisedShadow.opacity(0.22), radius: isActive ? 5 : 2, x: 0, y: 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct CinemaStatusPill: View {
    var text: String
    var icon: String? = nil
    var isAnimating: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if isAnimating {
                ProgressView()
                    .controlSize(.mini)
                    .tint(CinemaDesign.keyColor)
                    .scaleEffect(0.7)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
            }

            Text(text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(CinemaDesign.mutedInk)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background {
            Capsule(style: .continuous)
                .fill(CinemaDesign.insetSurface.opacity(0.94))
        }
        .overlay {
            Capsule(style: .continuous)
                .stroke(CinemaDesign.cardStroke, lineWidth: 0.6)
        }
        .shadow(color: CinemaDesign.raisedShadow.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}
