import GBV3AlertModalCore

import SwiftUI

/// Primary action, the app's `ActionStyle.obliqueBottomLeft`: a `cornerRadius = 8` rounded rectangle,
/// orange fill, white heavy text, 48pt tall, with a HARD solid-orange offset to the lower-left
/// (blur 0) — the "oblique" look. On press it slides into that offset, the offset disappears, and
/// the fill goes to the pressed colour. Design identity — fixed in the view, never per-call (spec D8).
public struct ObliquePrimaryStyle: ButtonStyle {
    let tokens: ModalTokens
    /// Whether the button spans its slot or hugs its label — `ResolvedModal.buttonsMatchParent`,
    /// threaded through `AlertModalScaffold.buttonsMatchParent`.
    ///
    /// In UIKit both behaviours come out of the same two constraint sets: the button is pinned to
    /// all four edges of `vwPrimaryAction`, and `svMainActionContainer.alignment` (`.fill` vs
    /// `.center`) decides whether that slot spans the content width or hugs the button's intrinsic
    /// width, which is `label + 2 × contentEdgeInsets.left`. Defaults to `true` — every real Genie
    /// preset sets `buttonActionShouldMatchParent: true`, and this style filled unconditionally
    /// before the flag was threaded.
    let fillsWidth: Bool

    public init(tokens: ModalTokens = .standard, fillsWidth: Bool = true) {
        self.tokens = tokens
        self.fillsWidth = fillsWidth
    }

    /// The label colour decision, as a pure function so a test can assert it without hosting a
    /// view. UIKit sets `titleColor` / `titleDisableColor` on the two states separately
    /// (`GBAlertModal+ButtonStyling.swift`, `.obliqueBottomLeft` branch), so SwiftUI must read two
    /// tokens here — using `onAccent` for both would ignore `titleDisableColor` entirely.
    static func labelColor(tokens: ModalTokens, isEnabled: Bool) -> Color {
        isEnabled ? tokens.palette.onAccent : tokens.palette.onAccentDisabled
    }

    public func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, tokens: tokens, fillsWidth: fillsWidth)
    }

    struct StyledLabel: View {
        let configuration: ButtonStyleConfiguration
        let tokens: ModalTokens
        let fillsWidth: Bool
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
                // Hugging path: `buttonLabelPaddingH` IS UIKit's `contentEdgeInsets.left/right`, so
                // a hugging button is `label + 32` wide on both backends. The insets are applied on
                // both paths (they are inert once the button fills) so the two differ in exactly one
                // thing — whether the width is taken from the slot or from the label.
                .padding(.horizontal, tokens.buttonLabelPaddingH)
                .frame(maxWidth: fillsWidth ? CGFloat.infinity : nil, minHeight: tokens.buttonHeight)
                .background(
                    // Shadow lives on the BACKGROUND SHAPE only — the text casts none.
                    RoundedRectangle(cornerRadius: visual.cornerRadius, style: .continuous)
                        .fill(fill)
                        .shadow(color: showOblique ? tokens.palette.shadow : .clear,
                                radius: visual.shadowRadius,
                                x: visual.shadowOffset.width, y: visual.shadowOffset.height)
                )
                // On press, slide into the oblique offset — UIKit's
                // `transform = .identity.translatedBy(x: -3, y: 3)`.
                //
                // This COMPOSES with the up-and-right displacement `AlertModalScaffold.primaryButton`
                // gives the button inside its slot (see that property's doc): at rest the visible rect
                // sits 3pt above and right of the slot with the shadow falling INSIDE it, and pressed,
                // this offset cancels the displacement so the button lands flush in its slot with no
                // shadow — exactly the two UIKit states.
                .offset(x: pressed ? visual.shadowOffset.width : 0,
                        y: pressed ? visual.shadowOffset.height : 0)
        }
    }
}

/// Secondary action: text-only, heavy label in the SECONDARY action style's own colour, dims on
/// press (spec D8).
///
/// **It HUGS its label, and that is not a choice this style gets to make.**
/// `configureButtonActionConstraint`'s `.plain` branch constrains `btSecondaryAction` with
/// `top == superview.top`, `leading >= superview.leading` and `center == superview.center` — so the
/// button is as wide as its own intrinsic width (`label + 2 × contentEdgeInsets.left`) and centred in
/// its slot, whatever `svMainActionContainer.alignment` does to that slot. This style used to size
/// itself `.frame(maxWidth: .infinity)`, which put the LABEL in the right place but made the tap
/// target and the pressed-state `opacity(0.5)` region span the whole card — ~140pt of width more than
/// the shipping button for a "No" label (task 17, finding D-4).
///
/// Note the asymmetry with `ObliquePrimaryStyle`, which is real and not an oversight: the oblique
/// button IS pinned to its slot's four edges, so IT follows the slot's alignment. Only the primary
/// takes a `fillsWidth`.
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
                // UIKit's `contentEdgeInsets` (6, 16, 6, 16): the horizontal half is the button's
                // width, the vertical half is dominated by the 48pt slot height it is centred in.
                .padding(.horizontal, tokens.buttonLabelPaddingH)
                .frame(minHeight: tokens.buttonHeight)
                .opacity(configuration.isPressed ? 0.5 : 1)
        }
    }
}

/// A real fourth/fifth look, not a counterfeit of the two above — `ActionStyle.capsule`, wherever
/// `Properties`/`ModalProperties` puts it (primary or secondary; UIKit's `configureButtonActionConstraint`
/// pins BOTH the same way — `edges.equalToSuperview()` on a 48pt-tall slot — so it follows the SAME
/// `fillsWidth` rule `ObliquePrimaryStyle` documents, whichever slot it is in).
///
/// `Capsule()` needs no manual corner radius: UIKit's `GBRoundedButton.updateCornerRadius` sets
/// `layer.cornerRadius = frame.height / 2`, which is exactly what SwiftUI's `Capsule` shape computes
/// on its own for any rect (`min(width, height) / 2`) — a 48pt-tall button matches by construction,
/// not by a copied number.
public struct CapsuleButtonStyle: ButtonStyle {
    let visual: ModalTokens.CapsuleVisual
    let tokens: ModalTokens
    let fillsWidth: Bool

    public init(visual: ModalTokens.CapsuleVisual, tokens: ModalTokens = .standard, fillsWidth: Bool = true) {
        self.visual = visual
        self.tokens = tokens
        self.fillsWidth = fillsWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, visual: visual, tokens: tokens, fillsWidth: fillsWidth)
    }

    struct StyledLabel: View {
        let configuration: ButtonStyleConfiguration
        let visual: ModalTokens.CapsuleVisual
        let tokens: ModalTokens
        let fillsWidth: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(visual.font)
                .foregroundColor(isEnabled ? visual.title : visual.titleDisabled)
                .padding(.horizontal, tokens.buttonLabelPaddingH)
                .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: tokens.buttonHeight)
                .background(Capsule().fill(isEnabled ? visual.background : visual.backgroundDisabled))
                // UIKit gives `.capsule`/`.capsuleOutlined` no pressed-state animation of their own
                // (only `.obliqueBottomLeft` has `updateObliqueBottomLeftStylePressed`) — they get
                // `UIControl`'s default highlighted dimming instead. SwiftUI has no equivalent
                // implicit dimming, so this borrows `PlainSecondaryStyle`'s own stand-in for the same
                // gap rather than inventing a second one.
                .opacity(configuration.isPressed ? 0.5 : 1)
        }
    }
}

/// `.capsuleOutlined` — same shape and fallback rules as `CapsuleButtonStyle`, plus a stroked border.
public struct CapsuleOutlinedButtonStyle: ButtonStyle {
    let visual: ModalTokens.CapsuleOutlinedVisual
    let tokens: ModalTokens
    let fillsWidth: Bool

    public init(
        visual: ModalTokens.CapsuleOutlinedVisual, tokens: ModalTokens = .standard, fillsWidth: Bool = true
    ) {
        self.visual = visual
        self.tokens = tokens
        self.fillsWidth = fillsWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, visual: visual, tokens: tokens, fillsWidth: fillsWidth)
    }

    struct StyledLabel: View {
        let configuration: ButtonStyleConfiguration
        let visual: ModalTokens.CapsuleOutlinedVisual
        let tokens: ModalTokens
        let fillsWidth: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(visual.font)
                .foregroundColor(isEnabled ? visual.title : visual.titleDisabled)
                .padding(.horizontal, tokens.buttonLabelPaddingH)
                .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: tokens.buttonHeight)
                .background(Capsule().fill(isEnabled ? visual.background : visual.backgroundDisabled))
                .overlay(
                    Capsule().stroke(
                        isEnabled ? visual.borderColor : visual.borderDisabledColor,
                        lineWidth: visual.borderWidth
                    )
                )
                .opacity(configuration.isPressed ? 0.5 : 1)
        }
    }
}
