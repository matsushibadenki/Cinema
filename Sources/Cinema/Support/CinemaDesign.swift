// file:///Users/Shared/Program/Xcode/Cinema/Sources/Cinema/Support/CinemaDesign.swift
// CinemaDesign.swift
// アプリ全体のデザインシステム（カラーパレット、パネル装飾、ボタンスタイル、ステータス表示等）を統一管理するファイルです。

import AppKit
import SwiftUI

enum CinemaDesign {
    // MARK: - Base Theme

    static let keyColor = dynamicColor(
        light: (0.19, 0.19, 0.21, 1.0),
        dark: (0.78, 0.78, 0.81, 1.0)
    )

    static let keyColorSoft = dynamicColor(
        light: (0.19, 0.19, 0.21, 0.08),
        dark: (0.78, 0.78, 0.81, 0.12)
    )

    static let canvasBackground = dynamicColor(
        light: (0.955, 0.955, 0.958, 1.0),
        dark: (0.082, 0.082, 0.086, 1.0)
    )

    static let panelBackground = dynamicColor(
        light: (0.975, 0.975, 0.978, 0.99),
        dark: (0.102, 0.102, 0.108, 0.99)
    )

    static let railBackground = dynamicColor(
        light: (0.968, 0.968, 0.972, 0.99),
        dark: (0.094, 0.094, 0.100, 1.0)
    )

    static let cardSurface = dynamicColor(
        light: (0.992, 0.992, 0.994, 1.0),
        dark: (0.126, 0.126, 0.132, 1.0)
    )

    static let mainBlockSurface = dynamicColor(
        light: (0.966, 0.966, 0.970, 1.0),
        dark: (0.116, 0.116, 0.122, 1.0)
    )

    static let editorSurface = dynamicColor(
        light: (0.970, 0.970, 0.974, 1.0),
        dark: (0.120, 0.120, 0.126, 1.0)
    )

    static let focusedCutShellSurface = dynamicColor(
        light: (0.905, 0.910, 0.920, 1.0),
        dark: (0.154, 0.154, 0.162, 1.0)
    )

    static let focusedCutPanelSurface = dynamicColor(
        light: (0.868, 0.875, 0.888, 1.0),
        dark: (0.166, 0.166, 0.174, 1.0)
    )

    static let focusedCutEditorSurface = dynamicColor(
        light: (0.844, 0.852, 0.868, 1.0),
        dark: (0.178, 0.178, 0.186, 1.0)
    )

    static let insetSurface = dynamicColor(
        light: (0.944, 0.944, 0.950, 1.0),
        dark: (0.136, 0.136, 0.142, 1.0)
    )

    // MARK: - Semantic Colors

    static let pageShadow = dynamicColor(
        light: (0.18, 0.18, 0.22, 0.10),
        dark: (0.0, 0.0, 0.0, 0.32)
    )

    static let fineBorder = dynamicColor(
        light: (0.36, 0.37, 0.41, 0.14),
        dark: (1.0, 1.0, 1.0, 0.07)
    )

    static let strongBorder = dynamicColor(
        light: (0.32, 0.33, 0.38, 0.20),
        dark: (1.0, 1.0, 1.0, 0.13)
    )

    static let focusedCutBorder = dynamicColor(
        light: (0.24, 0.25, 0.30, 0.40),
        dark: (1.0, 1.0, 1.0, 0.18)
    )

    static let warmBorder = dynamicColor(
        light: (0.19, 0.19, 0.21, 0.24),
        dark: (0.78, 0.78, 0.81, 0.28)
    )

    static let ink = dynamicColor(
        light: (0.07, 0.08, 0.11, 1.0),
        dark: (0.95, 0.96, 0.99, 1.0)
    )

    static let mutedInk = dynamicColor(
        light: (0.36, 0.37, 0.41, 1.0),
        dark: (0.67, 0.68, 0.72, 1.0)
    )

    static let quietInk = dynamicColor(
        light: (0.56, 0.57, 0.61, 1.0),
        dark: (0.46, 0.47, 0.52, 1.0)
    )

    static let controlInactiveInk = dynamicColor(
        light: (0.52, 0.53, 0.57, 1.0),
        dark: (0.34, 0.35, 0.39, 1.0)
    )

    static let placeholderInk = dynamicColor(
        light: (0.58, 0.59, 0.63, 1.0),
        dark: (0.38, 0.39, 0.43, 1.0)
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
            dynamicColor(light: (0.988, 0.988, 0.990, 0.96), dark: (0.104, 0.104, 0.110, 0.98)),
            dynamicColor(light: (0.974, 0.974, 0.978, 0.96), dark: (0.094, 0.094, 0.100, 0.98))
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let toolbarSeparator = LinearGradient(
        colors: [
            fineBorder.opacity(0.0),
            fineBorder.opacity(0.85),
            fineBorder.opacity(0.85),
            fineBorder.opacity(0.0)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let raisedShadow = dynamicColor(
        light: (0.20, 0.24, 0.32, 0.06),
        dark: (0.0, 0.0, 0.0, 0.22)
    )

    static let topHighlight = dynamicColor(
        light: (1.0, 1.0, 1.0, 0.45),
        dark: (1.0, 1.0, 1.0, 0.05)
    )

    static let railIconBackground = dynamicColor(
        light: (0.948, 0.948, 0.954, 0.94),
        dark: (1.0, 1.0, 1.0, 0.06)
    )

    static let railIconStroke = dynamicColor(
        light: (0.34, 0.35, 0.40, 0.10),
        dark: (1.0, 1.0, 1.0, 0.10)
    )

    static let selectedRowSurface = dynamicColor(
        light: (0.19, 0.19, 0.21, 0.055),
        dark: (0.78, 0.78, 0.81, 0.09)
    )

    // The structure rail is the single colored wayfinding mark in the interface.
    static let sidebarStructureAccent = dynamicColor(
        light: (0.42, 0.34, 0.74, 1.0),
        dark: (0.55, 0.50, 0.84, 1.0)
    )

    static let cardStroke = dynamicColor(
        light: (0.35, 0.36, 0.40, 0.12),
        dark: (1.0, 1.0, 1.0, 0.08)
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
    var cornerRadius: CGFloat = 0
    var isHighlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                Rectangle()
                    .fill(
                        isHighlighted
                        ? CinemaDesign.keyColorSoft.opacity(0.42)
                        : CinemaDesign.cardSurface.opacity(0.44)
                    )
            )
            .overlay(alignment: .topLeading) {
                Rectangle()
                    .fill(isHighlighted ? CinemaDesign.keyColor.opacity(0.72) : CinemaDesign.strongBorder)
                    .frame(width: isHighlighted ? 2 : 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isHighlighted ? CinemaDesign.warmBorder.opacity(0.72) : CinemaDesign.fineBorder)
                    .frame(height: 1)
            }
    }
}

extension View {
    func cinemaPanel(cornerRadius: CGFloat = 0, isHighlighted: Bool = false) -> some View {
        modifier(CinemaPanelModifier(cornerRadius: cornerRadius, isHighlighted: isHighlighted))
    }
}

struct CinemaToolbarButtonStyle: ButtonStyle {
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(isActive ? CinemaDesign.ink : CinemaDesign.controlInactiveInk)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .padding(.vertical, 5.5)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(CinemaDesign.insetSurface.opacity(configuration.isPressed ? 0.98 : 0.72))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(
                        isActive ? CinemaDesign.strongBorder : CinemaDesign.fineBorder,
                        lineWidth: isActive ? 0.9 : 0.6
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct CinemaActionButtonStyle: ButtonStyle {
    var isActive: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: isActive ? .semibold : .medium))
            .foregroundStyle(isActive ? CinemaDesign.ink : CinemaDesign.controlInactiveInk)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(minHeight: 30)
            .background(CinemaDesign.insetSurface.opacity(configuration.isPressed ? 0.98 : 0.72))
            .overlay {
                Rectangle()
                    .stroke(isActive ? CinemaDesign.strongBorder : CinemaDesign.fineBorder, lineWidth: isActive ? 0.9 : 0.6)
            }
            .opacity(configuration.isPressed ? 0.76 : 1)
            .contentShape(Rectangle())
    }
}

struct CinemaStateButtonStyle: ButtonStyle {
    var isActive: Bool
    var expands: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: isActive ? .semibold : .medium))
            .foregroundStyle(isActive ? CinemaDesign.ink : CinemaDesign.controlInactiveInk)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .frame(maxWidth: expands ? .infinity : nil)
            .background(Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isActive ? CinemaDesign.ink.opacity(0.76) : Color.clear)
                    .frame(height: 1)
            }
            .opacity(configuration.isPressed ? 0.70 : 1)
            .contentShape(Rectangle())
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
                    .font(.system(size: 10, weight: .semibold))
            }

            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(CinemaDesign.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background {
            Capsule(style: .continuous)
                .fill(CinemaDesign.cardSurface.opacity(0.96))
        }
        .overlay {
            Capsule(style: .continuous)
                .stroke(CinemaDesign.warmBorder.opacity(0.6), lineWidth: 0.8)
        }
        .shadow(color: CinemaDesign.raisedShadow.opacity(0.4), radius: 5, x: 0, y: 2)
    }
}
