import CoreText
import SwiftUI
import UIKit

/// Design vocabulary for the SwiftUI alert modal (spec D8: `Properties` dissolves into tokens +
/// `ButtonStyle`s, not per-call fields). Was a `static`-member `enum` transcribed by hand from the
/// app's `Presentation.UiKit.V3AlertModal` preset while the prototype couldn't reach `Properties`
/// — that transcription is exactly what shipped a wrong card width, wrong spacing and a wrong
/// button style, caught only by running on a physical device (spec C-0).
///
/// Now instance data: `init(from:)` DERIVES every field it can from the real `GBAlertModal.Properties`
/// the UIKit renderer already reads, so both renderers read ONE source of truth and cannot drift
/// apart the way the hand-transcription once did. `standard` freezes TODAY'S transcribed literal
/// values for call sites with no `Properties` to hand (SwiftUI-only demos, tests, and any field
/// with no `Properties` counterpart).
///
/// **The FIELD-BY-FIELD AUDIT of `GBAlertModal.Properties` lives on `init(from:)` below.** Every
/// `Properties` field is classified there as DERIVED (with the provenance test that proves it) or
/// DELIBERATELY NOT DERIVED (with the reason). There is no third category: a field that is neither
/// is a silent drift channel — a value UIKit honours and SwiftUI ignores, correct only for as long
/// as the preset happens to make the ignored value equal the hardcoded one.
public struct ModalTokens: Sendable {
    // Card geometry. Width MAXIMIZES to fill (screen − 2·horizontal margin), capped at
    // cardMaxWidth. `standard` has no `Properties` to derive a cap from, so it ships `.infinity`
    // (no cap — deliberately NOT a `UIDevice.current.userInterfaceIdiom` runtime check: (1) baking
    // a device query into a token is exactly the hardcoding spec C-0 exists to remove, and (2) it
    // is main-actor-isolated, which a nonisolated `static let`/`init` can't touch. `init(from:)`
    // applies `ContentProperty`'s width cap whenever `Properties` supplies one, unconditionally:
    // `.frame(maxWidth:)` is a CAP, not a fixed width, so on a phone-width screen (already
    // narrower than any realistic cap) it is naturally a no-op — no idiom branch needed.
    public var cornerRadius: CGFloat
    public var cardMaxWidth: CGFloat

    // Oblique primary button GEOMETRY — no `Properties` counterpart: no `ActionStyle` theme carries
    // corner radius, fixed height, or a drop-offset (only colours + a font — see `primaryButtonFont`
    // below). This button's SHAPE is fixed SwiftUI design identity (spec D8), so there is nothing in
    // `Properties` to derive these three from.
    public var buttonCornerRadius: CGFloat = 8
    public var buttonHeight: CGFloat = 48
    public var obliqueOffset = CGSize(width: -3, height: 3)

    // Card→screen margin — real preset: UIEdgeInsets(vertical: 40, horizontal: 20). `top`/`left`
    // read off `UIEdgeInsets` (same convention `ModalLayout.resolveContainerOffsets` uses).
    public var cardMarginV: CGFloat
    public var cardMarginH: CGFloat

    // Content padding inside the card — real preset `UIMinMaxEdgeInsets` top/bottom (16,24),
    // left/right (16,32). Horizontal inset is larger than vertical; using the MAX (design target)
    // of each, same as the original transcription.
    public var contentPaddingV: CGFloat
    public var contentPaddingH: CGFloat

    // Banner geometry — the THREE `Properties` banner fields, carried verbatim (including their
    // nil-ness, which means "UIKit installs no such constraint" and is NOT the same as "value
    // absent, fall back to `standard`"). `bannerLayout` below turns them into the SwiftUI slot
    // geometry, mirroring the UIKit constraint PRIORITIES rather than guessing a precedence.
    //
    // `standard` (no `Properties` in play at all) keeps the transcribed 160pt cap and no
    // ratio/fixed height: natural aspect, capped — exactly what the SwiftUI banner did before
    // these two fields existed.
    public var bannerRatio: CGFloat?
    public var bannerMaxHeight: CGFloat?
    public var bannerFixedHeight: CGFloat?

    // Vertical gaps — owner override to a uniform 12 (real preset was 8/8/16); interButton stays 8.
    // `standard` keeps that override baked in; `init(from:)` reads the real `ComponentSpace`
    // values whenever the caller supplies one (Task 6's per-presentation `effective` properties).
    public var gapBelowBanner: CGFloat
    public var gapBelowTitle: CGFloat
    public var gapBelowSubtitle: CGFloat
    public var interButton: CGFloat

    // Typography — real preset: title SHSans.bold 24, subtitle SHSans.regular 16, buttons
    // SHSans.heavy 16. `titleFont`/`subtitleFont` derive losslessly from `Properties`' `UIFont`s.
    public var titleFont: Font
    public var subtitleFont: Font
    // Button label fonts DO have a `Properties` counterpart — `ActionStyle` themes all carry a
    // `titleFont: UIFont?` (`ObliqueBottomLeftTheme.titleFont` for the primary style,
    // `PlainTheme.titleFont` for the secondary style) and the UIKit renderer applies it
    // (`GBAlertModal+ButtonStyling.swift`). One SwiftUI `ModalTokens` can't hold a single
    // `buttonFont` for both: `ObliquePrimaryStyle` and `PlainSecondaryStyle` are fixed to two
    // DIFFERENT `Properties` fields (`primaryActionStyle` / `secondaryActionStyle`), which can
    // legitimately carry different fonts. So this is split per-role rather than shared — see
    // `init(from:)` for the derivation, gated the same way the colours are: primary only reads
    // `.obliqueBottomLeft`'s theme (`ObliquePrimaryStyle`'s real counterpart); secondary only reads
    // `.plain`'s theme (`PlainSecondaryStyle`'s real counterpart, and the exact case
    // `SwiftUIAlertModal`'s sentinel `Properties` already uses for `secondaryActionStyle`).
    public var primaryButtonFont: Font = .system(size: 16, weight: .heavy)
    public var secondaryButtonFont: Font = .system(size: 16, weight: .heavy)

    public var palette: Palette

    public struct Palette: Sendable {
        // Real Geniebook values, transcribed from `UIColor.Genie.*` / `Colors.*` in the distribution
        // app for `standard`; derived from the primary `ActionStyle`'s `obliqueBottomLeft` theme
        // (the only `ActionStyle` case this fixed SwiftUI style has colours for) when `Properties`
        // supplies one. The primary button is ORANGE at rest and flips to BLUE when pressed — that
        // hue-flip is the real V3AlertModal oblique theme (unPressedColor accentSecondaryDark /
        // pressedColor 0x038CD5), not a prototype bug.
        public var accent: Color
        public var accentPressed: Color
        public var disabled: Color
        public var titleText: Color
        public var subtitleText: Color
        // Primary button label, enabled and disabled — `ObliqueBottomLeftTheme.titleColor` /
        // `.titleDisableColor`. UIKit sets BOTH (`configureButtonActionStyle`'s
        // `.obliqueBottomLeft` branch), so a single `onAccent` used for both states would silently
        // ignore `titleDisableColor` whenever a theme sets the two to different colours.
        public var onAccent: Color
        public var onAccentDisabled: Color
        // SECONDARY button label, enabled and disabled — `PlainTheme.titleColor` /
        // `.titleDisableColor`, i.e. the SECONDARY action style's own theme.
        //
        // These exist because `PlainSecondaryStyle` used to colour its label from `accent`, which
        // is derived from the PRIMARY style's theme: the `oblique-red-leave-confirm` shape (a RED
        // primary next to the standard secondary) therefore drew a RED secondary label where UIKit
        // draws the secondary theme's own colour. Split per-role for exactly the same reason
        // `primaryButtonFont`/`secondaryButtonFont` are.
        public var secondaryLabel: Color
        public var secondaryDisabled: Color
        public var shadow: Color
        public var cardBackground: Color
        // Close ("X") glyph tint — `Properties.closeButtonTint`, which the UIKit renderer applies
        // as `btCloseAction?.tintColor` (`GBAlertModal+Style.swift`). Before this token existed the
        // SwiftUI scaffold reused `subtitleText`, which matched only because the real preset's two
        // colours are close.
        public var closeButton: Color
        // The FINAL, already-composited scrim colour (any dimming baked in) — not a base hue plus a
        // separate opacity multiply. `standard` bakes its 0.6 dim in at construction time;
        // `init(from:)` takes `overlayColor` as-is, since a real `Properties` value already
        // encodes whatever alpha the app's design intends.
        public var scrim: Color
    }

    public static let standard = ModalTokens(
        cornerRadius: 16,
        cardMaxWidth: .infinity,   // no `Properties` to derive a cap from — see the doc comment above
        cardMarginV: 40,
        cardMarginH: 20,
        contentPaddingV: 24,
        contentPaddingH: 32,
        bannerMaxHeight: 160,
        gapBelowBanner: 12,
        gapBelowTitle: 12,
        gapBelowSubtitle: 12,
        interButton: 8,
        titleFont: .system(size: 24, weight: .bold),
        subtitleFont: .system(size: 16, weight: .regular),
        palette: Palette(
            accent: Color(hex: 0xF7941E),           // accentSecondaryDark (oblique unpressed)
            accentPressed: Color(hex: 0x038CD5),    // oblique pressedColor
            disabled: Color(hex: 0xB4B4B4),         // borderLight
            titleText: Color(hex: 0x262262),        // Genie.primary == GBPNavy
            subtitleText: Color(hex: 0x333333),     // textPrimaryDark
            onAccent: .white,
            onAccentDisabled: .white,               // real oblique theme: same white when disabled
            secondaryLabel: Color(hex: 0xF7941E),   // the accent — what the plain style always drew
            secondaryDisabled: Color(hex: 0xB4B4B4),
            shadow: Color(hex: 0xE57B41),           // orangeMandarin
            cardBackground: .white,
            closeButton: Color(hex: 0x333333),      // real preset: closeButtonTint == .black-ish
            scrim: Color(hex: 0x626262).opacity(0.6) // Colors.text_primary, dimmed
        )
    )

    init(
        cornerRadius: CGFloat,
        cardMaxWidth: CGFloat,
        cardMarginV: CGFloat,
        cardMarginH: CGFloat,
        contentPaddingV: CGFloat,
        contentPaddingH: CGFloat,
        bannerRatio: CGFloat? = nil,
        bannerMaxHeight: CGFloat?,
        bannerFixedHeight: CGFloat? = nil,
        gapBelowBanner: CGFloat,
        gapBelowTitle: CGFloat,
        gapBelowSubtitle: CGFloat,
        interButton: CGFloat,
        titleFont: Font,
        subtitleFont: Font,
        palette: Palette
    ) {
        self.cornerRadius = cornerRadius
        self.cardMaxWidth = cardMaxWidth
        self.cardMarginV = cardMarginV
        self.cardMarginH = cardMarginH
        self.contentPaddingV = contentPaddingV
        self.contentPaddingH = contentPaddingH
        self.bannerRatio = bannerRatio
        self.bannerMaxHeight = bannerMaxHeight
        self.bannerFixedHeight = bannerFixedHeight
        self.gapBelowBanner = gapBelowBanner
        self.gapBelowTitle = gapBelowTitle
        self.gapBelowSubtitle = gapBelowSubtitle
        self.interButton = interButton
        self.titleFont = titleFont
        self.subtitleFont = subtitleFont
        self.palette = palette
    }

    /// Derive tokens from the UIKit `Properties` that the UIKit renderer uses, so both renderers
    /// read ONE source of styling. Hand-transcribing these values is what previously shipped a
    /// wrong card width, wrong spacing and a wrong button style (spec C-0).
    ///
    /// Starts from `standard` and overrides the fields `properties` supplies — every `Properties`
    /// field this type reads is `Optional`, and a caller with a partially-filled `Properties` (or
    /// none at all) should fall back to the same literals `standard` ships, never a fabricated or
    /// zeroed value. `UIColor -> Color`, `CGColor -> Color`, and `UIFont -> Font` are lossless
    /// bridging conversions.
    ///
    /// ONE documented exception to that fallback policy: the three BANNER GEOMETRY fields are
    /// assigned unconditionally, because there `nil` is a MEANING ("install no such constraint"),
    /// not a missing value — see the banner block below.
    ///
    /// # THE AUDIT
    ///
    /// Every field of `Properties` (and of its nested `ContentProperty`, `ComponentSpace` and the
    /// `ActionStyle` themes the two fixed SwiftUI button styles correspond to) is classified here as
    /// **(a) DERIVED** — with the provenance test that proves it comes from `Properties` — or
    /// **(b) NOT DERIVED**, with the reason. There is deliberately no third category; anything
    /// unclassified is a field UIKit honours and SwiftUI ignores, which is the exact defect this
    /// derivation exists to prevent.
    ///
    /// Provenance tests all live in `ModalTokensProvenanceTests`
    /// (`Tests/GBV3AlertModalTests/SwiftUI/ModalTokensTests.swift`); names below are that file's.
    ///
    /// ## `GBAlertModal.Properties`
    ///
    /// | field | class | token / reason |
    /// | --- | --- | --- |
    /// | `baseTint` | (b) | UIKit `UIView.tintColor` INHERITANCE. It tints whatever descendant control does not set its own tint; every SwiftUI view in the scaffold sets its foreground explicitly, and the one tint-consuming control (the close glyph) has its own `closeButtonTint`, derived below. There is no view left for an inherited tint to reach. |
    /// | `overlayColor` | (a) | `palette.scrim` — `test_scrim_comesFromProperties_overlayColor` |
    /// | `contentProperty` | (a) | see the `ContentProperty` table |
    /// | `margin` | (a) | `cardMarginV`/`cardMarginH` — `test_cardMargin_comesFromProperties` |
    /// | `padding` | (a) | `contentPaddingV`/`contentPaddingH` — `test_contentPadding_comesFromProperties_usingMax` |
    /// | `bannerRatio` | (a) | `bannerRatio` — `test_bannerRatio_comesFromProperties` |
    /// | `bannerMaxHeight` | (a) | `bannerMaxHeight` — `test_bannerMaxHeight_comesFromProperties`, `test_bannerMaxHeight_isNilWhenPropertiesSetsNoCap` |
    /// | `bannerFixedHeight` | (a) | `bannerFixedHeight` — `test_bannerFixedHeight_comesFromProperties` |
    /// | `titleFont` | (a) | `titleFont` — `test_titleFont_comesFromProperties_viaFontBridge` |
    /// | `titleColor` | (a) | `palette.titleText` — `test_titleColor_comesFromProperties` |
    /// | `subtitleFont` | (a) | `subtitleFont` — `test_subtitleFont_comesFromProperties_viaFontBridge` |
    /// | `subtitleColor` | (a) | `palette.subtitleText` — `test_subtitleColor_comesFromProperties` |
    /// | `buttonActionShouldMatchParent` | (b) | A `UIStackView.alignment` decision (`.fill` vs `.center`), resolved by the SHARED resolver into `ResolvedModal.buttonsMatchParent` — a per-presentation render decision, not a design token. SwiftUI expresses it on the children instead: both `ModalButtonStyles` size their label `.frame(maxWidth: .infinity)`, which is the `true` (`.fill`) behaviour every real preset asks for. |
    /// | `buttonActionOrientation` | (b) | Same reason: resolved into `ResolvedModal.buttonAxis` and OBEYED by `AlertModalScaffold.card` (HStack vs VStack). A token copy would be a second vocabulary to keep in sync. |
    /// | `primaryActionStyle` | (a) | `palette.accent`/`accentPressed`/`disabled`/`shadow`/`onAccent`/`onAccentDisabled` + `primaryButtonFont`, from its `.obliqueBottomLeft` theme — see the theme table. Its PRESENCE additionally feeds `ResolvedModal.showsPrimary`. |
    /// | `secondaryActionStyle` | (a) | `palette.secondaryLabel`/`secondaryDisabled` + `secondaryButtonFont`, from its `.plain` theme — see the theme table. Its PRESENCE additionally feeds `ResolvedModal.showsSecondary`, which `SwiftUIAlertModal` obeys. |
    /// | `closeButtonTint` | (a) | `palette.closeButton` — `test_closeButtonTint_comesFromProperties` |
    /// | `space` | (a) | `gapBelowBanner`/`gapBelowTitle`/`gapBelowSubtitle`/`interButton` — see the `ComponentSpace` table |
    ///
    /// ## `Properties.ContentProperty`
    ///
    /// | field | class | token / reason |
    /// | --- | --- | --- |
    /// | `backgroundColor` | (a) | `palette.cardBackground` — `test_cardBackground_comesFromProperties_contentProperty` |
    /// | `cornerRadius` | (a) | `cornerRadius` — `test_cornerRadius_comesFromProperties` |
    /// | `fixedWidthPortrait` | (a) | folded into `cardMaxWidth` as a CAP — `test_cardMaxWidth_fallsBackToFixedWidth_whenNoMaxIsSet` |
    /// | `maxWidthPortrait` | (a) | `cardMaxWidth` — `test_cardMaxWidth_comesFromProperties_maxWidthPortrait` |
    /// | `fixedWidthLandscape` | (a) | portrait-first fallback into `cardMaxWidth` — `test_cardMaxWidth_fallsBackToLandscapeWidths` |
    /// | `maxWidthLandscape` | (a) | portrait-first fallback into `cardMaxWidth` — `test_cardMaxWidth_fallsBackToLandscapeWidths` |
    /// | `childShouldMatchParent` | (b) | Another `UIStackView.alignment` mechanism (the CONTENT stack this time). SwiftUI has no stack-wide "children fill" switch; each child in `SwiftUIAlertModal`/`AlertModalScaffold` states its own width behaviour. Every real preset sets it `true`, which is what the SwiftUI card already does. |
    ///
    /// ## `Properties.ComponentSpace` — all (a)
    ///
    /// `banner`/`title`/`subtitle` → `gapBelowBanner`/`gapBelowTitle`/`gapBelowSubtitle`
    /// (`test_gapBelowBannerTitleSubtitle_comeFromProperties`); `interButton` → `interButton`
    /// (`test_interButtonSpacing_comesFromProperties`).
    ///
    /// ## `ActionStyle` themes
    ///
    /// The two SwiftUI button styles are FIXED design identity (spec D8): the primary IS the
    /// oblique button and the secondary IS the plain text button. So exactly two of the four
    /// `ActionStyle` cases have a SwiftUI counterpart to derive into.
    ///
    /// | theme.field | class | token / reason |
    /// | --- | --- | --- |
    /// | `ObliqueBottomLeftTheme.unPressedColor` | (a) | `palette.accent` — `test_accentColors_comeFromProperties_obliqueBottomLeftTheme` |
    /// | `ObliqueBottomLeftTheme.pressedColor` | (a) | `palette.accentPressed` — same test |
    /// | `ObliqueBottomLeftTheme.disabledColor` | (a) | `palette.disabled` — same test |
    /// | `ObliqueBottomLeftTheme.shadowColor` | (a) | `palette.shadow` — same test |
    /// | `ObliqueBottomLeftTheme.titleColor` | (a) | `palette.onAccent` — same test |
    /// | `ObliqueBottomLeftTheme.titleDisableColor` | (a) | `palette.onAccentDisabled` — `test_primaryDisabledLabel_comesFromObliqueTheme_titleDisableColor` |
    /// | `ObliqueBottomLeftTheme.titleFont` | (a) | `primaryButtonFont` — `test_primaryButtonFont_comesFromProperties_obliqueBottomLeftTheme` |
    /// | `PlainTheme.titleColor` | (a) | `palette.secondaryLabel` — `test_secondaryLabel_comesFromSecondaryTheme_notThePrimaryAccent` |
    /// | `PlainTheme.titleDisableColor` | (a) | `palette.secondaryDisabled` — `test_secondaryDisabledLabel_comesFromPlainTheme_titleDisableColor` |
    /// | `PlainTheme.titleFont` | (a) | `secondaryButtonFont` — `test_secondaryButtonFont_comesFromProperties_plainTheme` |
    /// | `CapsuleTheme.*` (5 fields) | (b) | No SwiftUI counterpart: nothing here draws a capsule. Painting a capsule theme's colours onto the oblique/plain SHAPES would be a worse divergence than keeping `standard`'s literals, which is what happens — pinned by `test_accentColors_keepStandardLiterals_whenActionStyleIsNotOblique`. A consumer who ships `.capsule` on this backend gets the oblique look; that is the spec-D8 design decision, recorded here rather than silently absorbed. |
    /// | `CapsuleOutlineTheme.*` (8 fields) | (b) | Same reason as `CapsuleTheme`, plus the three border fields have no analogue on either fixed style. |
    ///
    /// ## Fields of `ModalTokens` with NO `Properties` counterpart
    ///
    /// `buttonCornerRadius`, `buttonHeight`, `obliqueOffset` — no `ActionStyle` theme carries button
    /// geometry (`GBAlertModal+ButtonStyling.swift` hardcodes the 8pt radius, the 48pt height and
    /// the ±3 offset in UIKit too). Pinned by `test_noCounterpartFields_stayAtStandardLiterals`.
    // swiftlint:disable:next function_body_length
    public init(from properties: GBAlertModal.Properties) {
        self = .standard

        if let contentProperty = properties.contentProperty {
            cornerRadius = contentProperty.cornerRadius
            // Unconditional — no `UIDevice` idiom check (see the type's doc comment above): a
            // `.frame(maxWidth:)` cap is naturally inert once the available width is already
            // narrower than it, so applying it regardless of idiom is both concurrency-safe and
            // behaviourally equivalent to gating it on `.pad`.
            //
            // All FOUR width fields feed this one cap:
            //  • portrait-first with a landscape fallback, mirroring `GBAlertModal.resolve`'s
            //    `contentWidth` (`maxWidthPortrait ?? maxWidthLandscape`). `ModalTokens` has no
            //    orientation input by design — it is a `Sendable` value derived from `Properties`
            //    alone, and SwiftUI expresses orientation through the layout proposal, not through
            //    a token — so it takes the portrait reading, exactly as `SwiftUIAlertModal` pins
            //    `isLandscape: false` for the resolver.
            //  • a FIXED width is folded in as a cap rather than as `.frame(width:)`. In UIKit the
            //    fixed width is an `==` at `.medium` while the max is a `<=` at `.high`, so the
            //    max always wins and the effective width can never exceed `min(fixed, max)`; a cap
            //    also degrades gracefully on a screen narrower than the card, which a hard
            //    `.frame(width:)` would not. Every real preset sets fixed == max, so this is the
            //    same number either way — it only stops a fixed-width-only preset from rendering
            //    UNCAPPED on SwiftUI while UIKit pins it.
            let fixedWidth = contentProperty.fixedWidthPortrait ?? contentProperty.fixedWidthLandscape
            let maxWidth = contentProperty.maxWidthPortrait ?? contentProperty.maxWidthLandscape
            switch (fixedWidth, maxWidth) {
            case let (fixed?, max?):
                cardMaxWidth = min(fixed, max)
            case let (fixed?, nil):
                cardMaxWidth = fixed
            case let (nil, max?):
                cardMaxWidth = max
            case (nil, nil):
                break   // no width in `Properties` at all — keep `standard`'s uncapped `.infinity`
            }
            if let backgroundColor = contentProperty.backgroundColor {
                palette.cardBackground = Color(uiColor: backgroundColor)
            }
        }

        if let margin = properties.margin {
            cardMarginV = margin.top
            cardMarginH = margin.left
        }

        if let padding = properties.padding {
            contentPaddingV = padding.topMax
            contentPaddingH = padding.leftMax
        }

        // BANNER GEOMETRY — assigned unconditionally, unlike every other field here. For the other
        // fields `nil` means "this `Properties` doesn't say", and `standard`'s literal is the right
        // answer. For these three `nil` is a POSITIVE statement: the UIKit view graph installs a
        // ratio / cap / fixed-height constraint ONLY when the field is non-nil, so keeping
        // `standard`'s 160pt cap for a `Properties` that deliberately sets `bannerMaxHeight: nil`
        // would apply a cap UIKit does not (the real `V3AlertModal` preset is exactly that case),
        // and it would also silently clip a `bannerFixedHeight` taller than 160.
        bannerRatio = properties.bannerRatio
        bannerMaxHeight = properties.bannerMaxHeight
        bannerFixedHeight = properties.bannerFixedHeight

        if let space = properties.space {
            gapBelowBanner = space.banner
            gapBelowTitle = space.title
            gapBelowSubtitle = space.subtitle
            interButton = space.interButton
        }

        if let titleFont = properties.titleFont {
            self.titleFont = Font(titleFont)
        }
        if let subtitleFont = properties.subtitleFont {
            self.subtitleFont = Font(subtitleFont)
        }
        if let titleColor = properties.titleColor {
            palette.titleText = Color(uiColor: titleColor)
        }
        if let subtitleColor = properties.subtitleColor {
            palette.subtitleText = Color(uiColor: subtitleColor)
        }
        if let overlayColor = properties.overlayColor {
            palette.scrim = Color(uiColor: overlayColor)
        }
        if let closeButtonTint = properties.closeButtonTint {
            palette.closeButton = Color(uiColor: closeButtonTint)
        }

        // The fixed SwiftUI primary button only has colours for the `obliqueBottomLeft` `ActionStyle`
        // (see `ModalButtonStyles`/`Palette` doc above) — any other case (or no style at all) has no
        // corresponding SwiftUI look, so `standard`'s literals are kept rather than guessing a mapping.
        if case let .obliqueBottomLeft(theme)? = properties.primaryActionStyle {
            if let unPressedColor = theme.unPressedColor {
                palette.accent = Color(uiColor: unPressedColor)
            }
            if let pressedColor = theme.pressedColor {
                palette.accentPressed = Color(uiColor: pressedColor)
            }
            if let disabledColor = theme.disabledColor {
                palette.disabled = Color(uiColor: disabledColor)
            }
            if let shadowColor = theme.shadowColor {
                palette.shadow = Color(cgColor: shadowColor)
            }
            if let titleColor = theme.titleColor {
                palette.onAccent = Color(uiColor: titleColor)
            }
            if let titleDisableColor = theme.titleDisableColor {
                palette.onAccentDisabled = Color(uiColor: titleDisableColor)
            }
            if let titleFont = theme.titleFont {
                primaryButtonFont = Font(titleFont)
            }
        }

        // `PlainSecondaryStyle`'s real counterpart is `ActionStyle.plain` (a borderless text
        // button) — the same case `SwiftUIAlertModal`'s sentinel `Properties` already uses for
        // `secondaryActionStyle`. Any other case (or no style at all) keeps `standard`'s literal.
        //
        // These colours come from the SECONDARY style's OWN theme. They must never be re-pointed at
        // `palette.accent`: that is the primary theme's colour, and doing so is what made the
        // `oblique-red-leave-confirm` shape draw a red secondary label under a red primary while
        // UIKit drew the secondary theme's colour.
        if case let .plain(theme)? = properties.secondaryActionStyle {
            if let titleColor = theme.titleColor {
                palette.secondaryLabel = Color(uiColor: titleColor)
            }
            if let titleDisableColor = theme.titleDisableColor {
                palette.secondaryDisabled = Color(uiColor: titleDisableColor)
            }
            if let titleFont = theme.titleFont {
                secondaryButtonFont = Font(titleFont)
            }
        }
    }
}

extension ModalTokens {
    /// The three LAYER-LEVEL visual properties of a rendered surface — the ones a FRAME comparison
    /// structurally cannot express (spec C-3b).
    ///
    /// This exists because of the exact defect that shipped: the "oblique" primary button was
    /// implemented as a diagonal corner CUT instead of the hard offset SHADOW the UIKit button
    /// draws. Both readings produce byte-identical frames — the shadow is outside the button's
    /// bounds and a corner cut is inside them — so a frame-only gate is green through the whole
    /// defect. `CALayer.cornerRadius` / `.shadowOffset` / `.shadowRadius` are where the difference
    /// actually lives, and the UIKit renderer sets all three on real layers
    /// (`GBAlertModal+ButtonStyling.swift` → `CALayer.applySketchShadow`).
    ///
    /// The SwiftUI side has no CALayer to read: `clipShape(RoundedRectangle)` is a mask and
    /// `.shadow(color:radius:x:y:)` is a filter, neither of which lowers to a settable layer
    /// property. So this type is the SwiftUI side's DECLARED value — and the point of putting it
    /// here, rather than transcribing the same numbers into a test, is that `ObliquePrimaryStyle`
    /// and `AlertModalScaffold.card` RENDER FROM THESE FIELDS. A test comparing UIKit's measured
    /// layer against `primaryButtonVisual` is therefore comparing against the value that actually
    /// drew, not against a copy of it that can rot.
    ///
    /// UNIT CAVEAT, stated rather than glossed: `shadowRadius` here is fed straight to
    /// `SwiftUI.View.shadow(radius:)`, while UIKit's `applySketchShadow(blur:)` stores
    /// `blur / 2` in `CALayer.shadowRadius`. The two scales coincide exactly at 0 — which is the
    /// shipped value on both sides (a HARD offset, no blur) — and any drift on either side breaks
    /// the comparison rather than silently rescaling it. If a blurred variant is ever introduced,
    /// the comparison must convert instead of equate.
    struct LayerVisual: Equatable {
        var cornerRadius: CGFloat
        /// Signed, in points, same convention as `CALayer.shadowOffset` (negative x = to the left).
        var shadowOffset: CGSize
        /// BLUR radius. Zero = a hard-edged offset copy of the shape, which is what "oblique" is.
        var shadowRadius: CGFloat
    }

    /// The oblique primary button's layer identity. `ObliquePrimaryStyle` renders from this.
    var primaryButtonVisual: LayerVisual {
        LayerVisual(cornerRadius: buttonCornerRadius, shadowOffset: obliqueOffset, shadowRadius: 0)
    }

    /// The card's layer identity. `AlertModalScaffold.card` renders from this. The card carries NO
    /// shadow on either backend (`vwContainer`'s layer is never given one), so a non-zero offset
    /// appearing on either side is a real divergence and not an unmodelled field.
    var cardVisual: LayerVisual {
        LayerVisual(cornerRadius: cornerRadius, shadowOffset: .zero, shadowRadius: 0)
    }

    /// The banner SLOT geometry the SwiftUI banner applies, resolved from the three `Properties`
    /// banner fields.
    ///
    /// `aspectRatio` is width/height (SwiftUI's convention AND `bannerRatio`'s: the UIKit
    /// constraint is `ivBanner.width == ivBanner.height * bannerRatio`). `height` pins the slot;
    /// `maxHeight` caps it. Any of them `nil` means "no such constraint", exactly as in UIKit.
    struct BannerLayout: Equatable {
        var aspectRatio: CGFloat?
        var height: CGFloat?
        var maxHeight: CGFloat?
    }

    /// PRECEDENCE, read off `GBAlertModal+ViewGraph.swift`'s `installConstraints` (the UIKit
    /// constraint PRIORITIES), not guessed. On `vwBanner` UIKit installs, at most:
    ///
    /// * `height <= bannerMaxHeight` at **751** — whenever `bannerMaxHeight` is set;
    /// * `height == width * (imageH/imageW)` at **700** — the natural-aspect driver, installed ONLY
    ///   when `bannerRatio == nil` and the image has a usable size;
    /// * `height == bannerFixedHeight` at **251** — whenever `bannerFixedHeight` is set.
    ///
    /// So:
    /// 1. the cap (751) outranks everything and is always applied when present;
    /// 2. when `bannerRatio == nil`, the natural-aspect driver (700) beats the fixed height (251),
    ///    i.e. **`bannerFixedHeight` is INERT on the natural-aspect path** — SwiftUI's
    ///    `.scaledToFit()` is that same natural-aspect behaviour, so the fixed height is dropped
    ///    here too rather than being applied where UIKit would not;
    /// 3. when `bannerRatio != nil` there is no 700 driver, so the fixed height (251, just above
    ///    the content stack's `.defaultLow` hugging at 250) is what sizes the slot.
    ///
    /// The ratio itself is a constraint on the IMAGE VIEW's frame (`width == height * ratio`) with
    /// `contentMode = .scaleAspectFit` inside it — i.e. a ratio-shaped SLOT with the picture
    /// letterboxed in it, which is what `ModalBannerGeometry` reproduces.
    var bannerLayout: BannerLayout {
        BannerLayout(
            aspectRatio: bannerRatio,
            height: bannerRatio == nil ? nil : bannerFixedHeight,
            maxHeight: bannerMaxHeight
        )
    }
}

extension Font {
    /// UIFont -> Font. SwiftUI has no direct `Font(UIFont)` bridge (only `Font(CTFont)` and the
    /// reverse `Font.Weight`/named APIs) — `UIFont` is toll-free bridged to `CTFont`, so casting
    /// through it is the standard, lossless way to carry a `UIFont` into SwiftUI. Internal for the
    /// same reason as `Color(hex:)` below: an extension on a type this library doesn't own.
    init(_ uiFont: UIFont) {
        self.init(uiFont as CTFont)
    }
}

extension Color {
    /// 0xRRGGBB literal → Color. Prototype convenience for transcribing the app's hex tokens.
    /// Internal on purpose: this is an extension on a type this library does NOT own
    /// (`SwiftUI.Color`). Making it public would inject `Color(hex:)` into the namespace of
    /// every app that links this library — a private `Color(hex:)` helper is an extremely common
    /// pattern, so that would cause "ambiguous use of 'init(hex:)'" at unrelated call sites in
    /// consuming apps, caused purely by linking this library. Never widen this for test
    /// convenience; see `ModalTokensTests.test_hex_color_decodes_rgb_channels` (library test
    /// target, `@testable import`) for the coverage this needs.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
