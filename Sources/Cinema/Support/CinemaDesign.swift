import SwiftUI

enum CinemaDesign {
    static let canvasBackground = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.975, blue: 0.96),
            Color(red: 0.93, green: 0.945, blue: 0.955)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let panelBackground = LinearGradient(
        colors: [
            Color.white.opacity(0.94),
            Color(red: 0.965, green: 0.97, blue: 0.975).opacity(0.92)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let pageShadow = Color.black.opacity(0.16)
    static let fineBorder = Color.black.opacity(0.08)
    static let warmBorder = Color(red: 0.78, green: 0.68, blue: 0.48).opacity(0.34)
    static let ink = Color(red: 0.08, green: 0.075, blue: 0.065)
    static let mutedInk = Color(red: 0.36, green: 0.35, blue: 0.32)
}

struct CinemaPanelModifier: ViewModifier {
    var cornerRadius: CGFloat = 8
    var isHighlighted = false

    func body(content: Content) -> some View {
        content
            .background(CinemaDesign.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isHighlighted ? CinemaDesign.warmBorder : CinemaDesign.fineBorder, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.055), radius: 10, x: 0, y: 5)
    }
}

extension View {
    func cinemaPanel(cornerRadius: CGFloat = 8, isHighlighted: Bool = false) -> some View {
        modifier(CinemaPanelModifier(cornerRadius: cornerRadius, isHighlighted: isHighlighted))
    }
}
