import SwiftUI

/// Primary action, the app's `ActionStyle.obliqueBottomLeft`: a `cornerRadius = 8` rounded rectangle,
/// orange fill, white heavy text, 48pt tall, with a HARD solid-orange offset to the lower-left
/// (blur 0) — the "oblique" look. On press it slides into that offset, the offset disappears, and
/// the fill goes to the pressed colour. Design identity — fixed in the view, never per-call (spec D8).
public struct ObliquePrimaryStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration)
    }

    struct StyledLabel: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let pressed = configuration.isPressed
            let fill: Color = !isEnabled ? ModalTokens.Palette.disabled
                : pressed ? ModalTokens.Palette.accentPressed
                : ModalTokens.Palette.accent
            let showOblique = isEnabled && !pressed
            configuration.label
                .font(ModalTokens.buttonFont)
                .foregroundColor(ModalTokens.Palette.onAccent)
                .frame(maxWidth: .infinity, minHeight: ModalTokens.buttonHeight)
                .background(
                    // Shadow lives on the BACKGROUND SHAPE only — the text casts none.
                    RoundedRectangle(cornerRadius: ModalTokens.buttonCornerRadius, style: .continuous)
                        .fill(fill)
                        .shadow(color: showOblique ? ModalTokens.Palette.shadow : .clear,
                                radius: 0, x: ModalTokens.obliqueOffset.width, y: ModalTokens.obliqueOffset.height)
                )
                // On press, slide into the oblique offset.
                .offset(x: pressed ? ModalTokens.obliqueOffset.width : 0,
                        y: pressed ? ModalTokens.obliqueOffset.height : 0)
        }
    }
}

/// Secondary action: text-only, accent-coloured heavy label, dims on press (spec D8).
public struct PlainSecondaryStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration)
    }

    struct StyledLabel: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(ModalTokens.buttonFont)
                .foregroundColor(isEnabled ? ModalTokens.Palette.accent : ModalTokens.Palette.disabled)
                .frame(maxWidth: .infinity, minHeight: ModalTokens.buttonHeight)
                .opacity(configuration.isPressed ? 0.5 : 1)
        }
    }
}
