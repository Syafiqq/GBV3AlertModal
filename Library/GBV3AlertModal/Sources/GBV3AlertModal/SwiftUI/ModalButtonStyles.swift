import SwiftUI

/// Primary action, the app's `ActionStyle.obliqueBottomLeft`: a `cornerRadius = 8` rounded rectangle,
/// orange fill, white heavy text, 48pt tall, with a HARD solid-orange offset to the lower-left
/// (blur 0) — the "oblique" look. On press it slides into that offset, the offset disappears, and
/// the fill goes to the pressed colour. Design identity — fixed in the view, never per-call (spec D8).
public struct ObliquePrimaryStyle: ButtonStyle {
    let tokens: ModalTokens

    public init(tokens: ModalTokens = .standard) {
        self.tokens = tokens
    }

    public func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, tokens: tokens)
    }

    struct StyledLabel: View {
        let configuration: ButtonStyleConfiguration
        let tokens: ModalTokens
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let pressed = configuration.isPressed
            let fill: Color = !isEnabled ? tokens.palette.disabled
                : pressed ? tokens.palette.accentPressed
                : tokens.palette.accent
            let showOblique = isEnabled && !pressed
            configuration.label
                .font(tokens.primaryButtonFont)
                .foregroundColor(tokens.palette.onAccent)
                .frame(maxWidth: .infinity, minHeight: tokens.buttonHeight)
                .background(
                    // Shadow lives on the BACKGROUND SHAPE only — the text casts none.
                    RoundedRectangle(cornerRadius: tokens.buttonCornerRadius, style: .continuous)
                        .fill(fill)
                        .shadow(color: showOblique ? tokens.palette.shadow : .clear,
                                radius: 0, x: tokens.obliqueOffset.width, y: tokens.obliqueOffset.height)
                )
                // On press, slide into the oblique offset.
                .offset(x: pressed ? tokens.obliqueOffset.width : 0,
                        y: pressed ? tokens.obliqueOffset.height : 0)
        }
    }
}

/// Secondary action: text-only, accent-coloured heavy label, dims on press (spec D8).
public struct PlainSecondaryStyle: ButtonStyle {
    let tokens: ModalTokens

    public init(tokens: ModalTokens = .standard) {
        self.tokens = tokens
    }

    public func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, tokens: tokens)
    }

    struct StyledLabel: View {
        let configuration: ButtonStyleConfiguration
        let tokens: ModalTokens
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(tokens.secondaryButtonFont)
                .foregroundColor(isEnabled ? tokens.palette.accent : tokens.palette.disabled)
                .frame(maxWidth: .infinity, minHeight: tokens.buttonHeight)
                .opacity(configuration.isPressed ? 0.5 : 1)
        }
    }
}
