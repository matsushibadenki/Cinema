// file:///Users/Shared/Program/Xcode/Cinema/Sources/Cinema/Support/CinemaDesign.swift
// CinemaDesign.swift
// Cinema アプリ全体のデザインシステム。カラーパレット、パネルスタイル、ボタンスタイル、アニメーション定数を管理する。
// 参考デザイン: 白基調のコマンドセンター、細いダークレール、極薄ボーダー、ソフトシャドウ。

import SwiftUI

enum CinemaDesign {
    // MARK: - Canvas & Panel Backgrounds

    /// メインキャンバス背景: ほぼ白のクールグレーグラデーション
    static let canvasBackground = LinearGradient(
        colors: [
            Color(red: 0.936, green: 0.944, blue: 0.950),
            Color(red: 0.920, green: 0.932, blue: 0.940)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// パネル背景: ほぼ白、わずかにクールグレー
    static let panelBackground = LinearGradient(
        colors: [
            Color(red: 0.985, green: 0.990, blue: 0.995).opacity(0.98),
            Color(red: 0.945, green: 0.960, blue: 0.972).opacity(0.94)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let railBackground = LinearGradient(
        colors: [
            Color(red: 0.115, green: 0.115, blue: 0.115),
            Color(red: 0.235, green: 0.235, blue: 0.235)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// カード表面: ほぼピュアホワイト
    static let cardSurface = Color(red: 0.955, green: 0.962, blue: 0.968)
    static let mainBlockSurface = Color(red: 0.935, green: 0.944, blue: 0.950)
    static let editorSurface = Color(red: 0.965, green: 0.970, blue: 0.975)

    // MARK: - Semantic Colors

    static let pageShadow = Color(red: 0.48, green: 0.54, blue: 0.62).opacity(0.12)
    /// 極薄ボーダー: ほとんど見えない程度
    static let fineBorder = Color(red: 0.62, green: 0.66, blue: 0.70).opacity(0.28)
    /// 暖色ボーダー（ストーリーボード用紙周り）
    static let warmBorder = Color(red: 0.72, green: 0.62, blue: 0.42).opacity(0.22)
    /// メインインク: ダークネイビー
    static let ink = Color(red: 0.07, green: 0.075, blue: 0.085)
    /// 補助テキスト: ライトグレー
    static let mutedInk = Color(red: 0.40, green: 0.45, blue: 0.50)
    static let quietInk = Color(red: 0.62, green: 0.66, blue: 0.70)

    // MARK: - Accent & AI Colors

    /// キーカラー: 黒100%
    static let keyColor = Color.black
    static let aiSparkle = Color.black
    static let aiSparkleLight = Color.black.opacity(0.06)

    // MARK: - Section / Header

    static let sectionHeader = Color(red: 0.16, green: 0.18, blue: 0.24)

    // MARK: - Toolbar

    static let toolbarBackground = LinearGradient(
        colors: [
            Color.white.opacity(0.78),
            Color(red: 0.94, green: 0.955, blue: 0.968).opacity(0.86)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let toolbarSeparator = LinearGradient(
        colors: [
            Color(red: 0.78, green: 0.82, blue: 0.86).opacity(0.0),
            Color(red: 0.78, green: 0.82, blue: 0.86).opacity(0.30),
            Color(red: 0.78, green: 0.82, blue: 0.86).opacity(0.30),
            Color(red: 0.78, green: 0.82, blue: 0.86).opacity(0.0)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Panel Modifier

struct CinemaPanelModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var isHighlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(CinemaDesign.cardSurface.opacity(isHighlighted ? 0.96 : 0.88))
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isHighlighted
                            ? CinemaDesign.fineBorder.opacity(0.6)
                            : CinemaDesign.fineBorder.opacity(0.3),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: Color.white.opacity(0.58), radius: 1, x: 0, y: -1)
            .shadow(color: Color(red: 0.48, green: 0.54, blue: 0.62).opacity(0.055), radius: 2, x: 0, y: 1)
            .shadow(color: Color(red: 0.48, green: 0.54, blue: 0.62).opacity(0.075), radius: 14, x: 0, y: 7)
    }
}

extension View {
    func cinemaPanel(cornerRadius: CGFloat = 14, isHighlighted: Bool = false) -> some View {
        modifier(CinemaPanelModifier(cornerRadius: cornerRadius, isHighlighted: isHighlighted))
    }
}

// MARK: - Toolbar Button Style

struct CinemaToolbarButtonStyle: ButtonStyle {
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isActive ? CinemaDesign.ink : CinemaDesign.mutedInk)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isActive
                        ? Color.white.opacity(0.96)
                        : (configuration.isPressed
                           ? Color.white.opacity(0.70)
                           : Color.white.opacity(0.58))
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isActive
                        ? CinemaDesign.fineBorder.opacity(0.5)
                        : CinemaDesign.fineBorder.opacity(0.2),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: Color(red: 0.65, green: 0.70, blue: 0.78).opacity(isActive ? 0.10 : 0.04), radius: isActive ? 6 : 2, x: 0, y: isActive ? 3 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Status Pill

struct CinemaStatusPill: View {
    var text: String
    var icon: String? = nil
    var isAnimating: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if isAnimating {
                ProgressView()
                    .controlSize(.mini)
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
                .fill(Color.white.opacity(0.80))
        }
        .overlay {
            Capsule(style: .continuous)
                .stroke(CinemaDesign.fineBorder.opacity(0.25), lineWidth: 0.5)
        }
        .shadow(color: Color(red: 0.65, green: 0.70, blue: 0.78).opacity(0.06), radius: 4, x: 0, y: 2)
    }
}
