import SwiftUI

/// The card's signature primary shape: a rounded rectangle whose bottom-left corner is cut at an
/// oblique angle instead of rounded (mirrors the app's `ActionStyle.obliqueBottomLeft`).
struct ObliqueBottomLeftShape: Shape {
    var oblique: CGFloat = 14
    var cornerRadius: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        let o = min(oblique, min(rect.width, rect.height) / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r,
                 startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r,
                 startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + o, y: rect.maxY))   // bottom edge, stop short of the corner
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - o))   // oblique diagonal up-left
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// Primary action: filled oblique button, white heavy text, orange drop shadow. Design identity —
/// fixed in the view, never a per-call field (spec D8).
struct ObliquePrimaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration)
    }

    struct StyledLabel: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let shape = ObliqueBottomLeftShape()
            let fill: Color = !isEnabled ? ModalTokens.Palette.disabled
                : configuration.isPressed ? ModalTokens.Palette.accentPressed
                : ModalTokens.Palette.accent
            configuration.label
                .font(ModalTokens.buttonFont)
                .foregroundColor(ModalTokens.Palette.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(shape.fill(fill))
                .clipShape(shape)
                .shadow(color: isEnabled ? ModalTokens.Palette.shadow.opacity(0.35) : .clear,
                        radius: 0, x: 0, y: 3)
        }
    }
}

/// Secondary action: text-only, accent-coloured heavy label, dims on press (spec D8).
struct PlainSecondaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration)
    }

    struct StyledLabel: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(ModalTokens.buttonFont)
                .foregroundColor(isEnabled ? ModalTokens.Palette.accent : ModalTokens.Palette.disabled)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .opacity(configuration.isPressed ? 0.5 : 1)
        }
    }
}
