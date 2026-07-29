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

    /// The label colour decision, as a pure function so a test can assert it without hosting a
    /// view. UIKit sets `titleColor` / `titleDisableColor` on the two states separately
    /// (`GBAlertModal+ButtonStyling.swift`, `.obliqueBottomLeft` branch), so SwiftUI must read two
    /// tokens here — using `onAccent` for both would ignore `titleDisableColor` entirely.
    static func labelColor(tokens: ModalTokens, isEnabled: Bool) -> Color {
        isEnabled ? tokens.palette.onAccent : tokens.palette.onAccentDisabled
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
            // Read ONCE from `ModalTokens.primaryButtonVisual` — the same value the differential
            // layer-visual test compares UIKit's measured `CALayer` against (spec C-3b). Spelling
            // the radius/offset inline here again would re-create the transcription channel that
            // let the oblique look drift from the UIKit button in the first place.
            let visual = tokens.primaryButtonVisual
            configuration.label
                .font(tokens.primaryButtonFont)
                .foregroundColor(ObliquePrimaryStyle.labelColor(tokens: tokens, isEnabled: isEnabled))
                .frame(maxWidth: .infinity, minHeight: tokens.buttonHeight)
                .background(
                    // Shadow lives on the BACKGROUND SHAPE only — the text casts none.
                    RoundedRectangle(cornerRadius: visual.cornerRadius, style: .continuous)
                        .fill(fill)
                        .shadow(color: showOblique ? tokens.palette.shadow : .clear,
                                radius: visual.shadowRadius,
                                x: visual.shadowOffset.width, y: visual.shadowOffset.height)
                )
                // On press, slide into the oblique offset.
                .offset(x: pressed ? visual.shadowOffset.width : 0,
                        y: pressed ? visual.shadowOffset.height : 0)
        }
    }
}

/// Secondary action: text-only, heavy label in the SECONDARY action style's own colour, dims on
/// press (spec D8).
public struct PlainSecondaryStyle: ButtonStyle {
    let tokens: ModalTokens

    public init(tokens: ModalTokens = .standard) {
        self.tokens = tokens
    }

    /// The label colour decision, as a pure function so a test can assert it without hosting a
    /// view — see `ModalButtonStyleColorTests.test_secondaryLabelColor_isTheSecondaryThemeColour_notTheAccent`.
    ///
    /// **Must read `secondaryLabel`/`secondaryDisabled`, never `accent`/`disabled`.** Those two are
    /// derived from the PRIMARY action style's `obliqueBottomLeft` theme; this button's real
    /// counterpart is `Properties.secondaryActionStyle`'s `PlainTheme`. Reading `accent` here is
    /// what made the `oblique-red-leave-confirm` shape (RED primary, standard secondary) draw a RED
    /// secondary label where UIKit draws the secondary theme's colour.
    static func labelColor(tokens: ModalTokens, isEnabled: Bool) -> Color {
        isEnabled ? tokens.palette.secondaryLabel : tokens.palette.secondaryDisabled
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
                .foregroundColor(PlainSecondaryStyle.labelColor(tokens: tokens, isEnabled: isEnabled))
                .frame(maxWidth: .infinity, minHeight: tokens.buttonHeight)
                .opacity(configuration.isPressed ? 0.5 : 1)
        }
    }
}
