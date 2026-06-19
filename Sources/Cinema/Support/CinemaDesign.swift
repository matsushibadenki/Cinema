// file:///Users/Shared/Program/Xcode/Cinema/Sources/Cinema/Support/CinemaDesign.swift
// CinemaDesign.swift
// Cinema アプリ全体のデザインシステム。カラーパレット、パネルスタイル、ボタンスタイル、アニメーション定数を管理する。

import SwiftUI

enum CinemaDesign {
    // MARK: - Canvas & Panel Backgrounds

    static let canvasBackground = LinearGradient(
        colors: [
            Color(red: 0.965, green: 0.962, blue: 0.95),
            Color(red: 0.925, green: 0.935, blue: 0.948)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let panelBackground = LinearGradient(
        colors: [
            Color.white.opacity(0.96),
            Color(red: 0.96, green: 0.965, blue: 0.975).opacity(0.94)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Semantic Colors

    static let pageShadow = Color.black.opacity(0.14)
    static let fineBorder = Color.black.opacity(0.07)
    static let warmBorder = Color(red: 0.72, green: 0.62, blue: 0.42).opacity(0.30)
    static let ink = Color(red: 0.10, green: 0.09, blue: 0.08)
    static let mutedInk = Color(red: 0.38, green: 0.37, blue: 0.34)

    // MARK: - Accent & AI Colors

    static let accentGradient = LinearGradient(
        colors: [
            Color(red: 0.25, green: 0.58, blue: 0.68),
            Color(red: 0.55, green: 0.42, blue: 0.72)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let aiSparkle = Color(red: 0.45, green: 0.38, blue: 0.72)
    static let aiSparkleLight = Color(red: 0.45, green: 0.38, blue: 0.72).opacity(0.10)

    // MARK: - Section / Header

    static let sectionHeader = Color(red: 0.30, green: 0.29, blue: 0.27)

    // MARK: - Toolbar background

    static let toolbarBackground = LinearGradient(
        colors: [
            Color(red: 0.97, green: 0.97, blue: 0.98).opacity(0.92),
            Color(red: 0.95, green: 0.955, blue: 0.965).opacity(0.88)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let toolbarSeparator = LinearGradient(
        colors: [
            Color.black.opacity(0.0),
            Color.black.opacity(0.10),
            Color.black.opacity(0.10),
            Color.black.opacity(0.0)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Panel Modifier

struct CinemaPanelModifier: ViewModifier {
    var cornerRadius: CGFloat = 10
    var isHighlighted = false

    func body(content: Content) -> some View {
        content
            .background(CinemaDesign.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isHighlighted ? CinemaDesign.warmBorder : CinemaDesign.fineBorder,
                        lineWidth: isHighlighted ? 1.2 : 0.8
                    )
            }
            .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
}

extension View {
    func cinemaPanel(cornerRadius: CGFloat = 10, isHighlighted: Bool = false) -> some View {
        modifier(CinemaPanelModifier(cornerRadius: cornerRadius, isHighlighted: isHighlighted))
    }
}

// MARK: - Toolbar Icon Button Style

struct CinemaToolbarButtonStyle: ButtonStyle {
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isActive ? Color.accentColor : CinemaDesign.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        isActive
                        ? Color.accentColor.opacity(0.10)
                        : (configuration.isPressed
                           ? Color.black.opacity(0.06)
                           : Color.white.opacity(0.65))
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(
                        isActive
                        ? Color.accentColor.opacity(0.25)
                        : Color.black.opacity(configuration.isPressed ? 0.10 : 0.06),
                        lineWidth: 0.6
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Status Pill Style

struct CinemaStatusPill: View {
    var text: String
    var icon: String? = nil
    var isAnimating: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if isAnimating {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.7)
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }

            Text(text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(CinemaDesign.mutedInk)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background {
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.75))
        }
        .overlay {
            Capsule(style: .continuous)
                .stroke(CinemaDesign.fineBorder, lineWidth: 0.6)
        }
    }
}
