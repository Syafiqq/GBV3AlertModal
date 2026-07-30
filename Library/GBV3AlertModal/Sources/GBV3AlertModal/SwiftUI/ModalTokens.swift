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
    // `cardMaxWidth` — which is DERIVED from `contentMaxWidth`, never given directly. `standard`
    // has no `Properties` to derive a cap from, so it ships `.infinity` (no cap — deliberately NOT
    // a `UIDevice.current.userInterfaceIdiom` runtime check: (1) baking a device query into a token
    // is exactly the hardcoding spec C-0 exists to remove, and (2) it is main-actor-isolated, which
    // a nonisolated `static let`/`init` can't touch. `init(from:)` applies `ContentProperty`'s
    // width cap whenever `Properties` supplies one, unconditionally: `.frame(maxWidth:)` is a CAP,
    // not a fixed width, so on a phone-width screen (already narrower than any realistic cap) it is
    // naturally a no-op — no idiom branch needed.
    public var cornerRadius: CGFloat

    /// **The width `ContentProperty` states — of the CONTENT CONTAINER, not of the card.**
    ///
    /// This field used to be called `cardMaxWidth` and was applied to the CARD. That was wrong, and
    /// it was measured wrong by the differential-geometry gate (task 17, finding D-1): in UIKit
    /// `ContentProperty.maxWidthPortrait`/`fixedWidthPortrait` constrain `svContentContainer` — the
    /// stack INSIDE the card (`GBAlertModal+Layout.swift`, `adjustSvContentContainerConstraint`) —
    /// and `vwContainer` ends up wider by the horizontal content padding on each side. Applying the
    /// same number to the card made the SwiftUI card 64pt narrower than the shipping one on the real
    /// preset (256 vs 320) and its content 64pt narrower again (192 vs 256), which changed every
    /// text wrap and therefore every height in the card. It is the same defect class that already
    /// shipped once here ("feels small/narrow"), and the ONLY reason it was caught is that the gate
    /// compares against UIKit's measured numbers instead of a recorded snapshot.
    ///
    /// The card's cap is now `cardMaxWidth` below, computed from this plus the horizontal padding —
    /// i.e. the SwiftUI side applies the preset's width at the SAME LEVEL UIKit does.
    public var contentMaxWidth: CGFloat

    // Oblique primary button GEOMETRY — no `Properties` counterpart: no `ActionStyle` theme carries
    // corner radius, fixed height, or a drop-offset (only colours + a font — see `primaryButtonFont`
    // below). This button's SHAPE is fixed SwiftUI design identity (spec D8), so there is nothing in
    // `Properties` to derive these three from.
    public var buttonCornerRadius: CGFloat = 8
    public var buttonHeight: CGFloat = 48
    public var obliqueOffset = CGSize(width: -3, height: 3)

    /// Horizontal inset between a button's edge and its label — UIKit's
    /// `contentEdgeInsets = (6, 16, 6, 16)`, set identically on the plain and the oblique button
    /// (`GBAlertModal+ButtonStyling.swift`'s `generateButtonForPlainThemedDesign` /
    /// `generateButtonForObliqueThemedDesign`). It is load-bearing only on the HUGGING path, where
    /// the button's width IS `label + 2 × this`: UIKit's `.plain` branch constrains the secondary
    /// button `leading >= superview.leading` + `center == superview.center`, so that button hugs its
    /// label whatever its slot does. No `Properties` counterpart — UIKit hardcodes it too.
    public var buttonLabelPaddingH: CGFloat = 16

    /// **How far the title may shrink before it is allowed to give up anything else — RUNG 2 of the
    /// no-truncation ladder, and the same number on both renderers.**
    ///
    /// It no longer means what it used to. The old reading was "shrink the title onto ONE line, then
    /// truncate at two", which is the ladder the owner directive removed. The new reading is: wrap
    /// freely (`lineLimit(nil)` here, `numberOfLines = 0` in UIKit); let the SUBTITLE yield first;
    /// and only then scale the title's glyphs down, as far as this factor and no further — because
    /// shrinking keeps every glyph and truncating does not.
    ///
    /// **Initialised FROM `ModalLayout.titleMinimumScaleFactor`, never transcribed.** That constant is
    /// what UIKit's `adjustTitleFontScale` searches against, so the two renderers cannot drift to
    /// different floors — the failure mode this whole type exists to prevent, and one this very field
    /// used to have (it carried a hand-copied 0.75 while UIKit hardcoded its own). Pinned by
    /// `test_theShrinkFloor_isOneSharedNumber`.
    ///
    /// No `Properties` counterpart: UIKit hardcodes the floor too.
    public var titleMinimumScaleFactor: CGFloat = ModalLayout.titleMinimumScaleFactor

    /// **`titleFont`'s measurement twin.**
    ///
    /// `SwiftUI.Font` is opaque: it can be rendered but not measured, and there is no `Font -> UIFont`
    /// direction to recover one from (the bridge only runs `UIFont -> Font`, via `CTFont`). Rung 2's
    /// SwiftUI half needs a real measurement — how tall the title is once shrunk to
    /// `titleMinimumScaleFactor` — so the `UIFont` that `titleFont` was BUILT FROM is kept here rather
    /// than reconstructed by guesswork.
    ///
    /// `init(from:)` assigns both from the one `Properties.titleFont`, so on every real presentation
    /// they are the same font by construction. `standard` has no `Properties`, so it carries the
    /// literal twin of its own `.system(size: 24, weight: .bold)` — pinned by
    /// `test_theStandardTitleFontAndItsMeasurementTwin_agree`. A caller who reassigns `titleFont`
    /// alone would only weaken the floor measurement, never the rendering.
    public var titleUIFont: UIFont = .systemFont(ofSize: 24, weight: .bold)

    /// The close button's tap target, 48×48. UIKit pins `btCloseAction` to `vwContainer`'s
    /// top-trailing with `size == 48` (`GBAlertModal+ViewGraph.swift`'s `installConstraints`); the
    /// SwiftUI scaffold used 44 (the HIG minimum) and therefore drew the glyph 2pt further from both
    /// card edges with a tap target 16% smaller in area — measured as task 17's finding D-5. No
    /// `Properties` counterpart: the 48 is hardcoded on the UIKit side too.
    public var closeButtonSize: CGFloat = 48

    // Card→screen margin — real preset: UIEdgeInsets(vertical: 40, horizontal: 20). `top`/`left`
    // read off `UIEdgeInsets` (same convention `ModalLayout.resolveContainerOffsets` uses).
    public var cardMarginV: CGFloat
    public var cardMarginH: CGFloat

    /// **Content padding inside the card, carried VERBATIM — all eight edges, min and max.**
    ///
    /// Real preset: top/bottom (16,24), left/right (16,32). This used to be two numbers,
    /// `contentPaddingV`/`contentPaddingH`, both taken from the TOP/LEFT max — which silently threw
    /// away three facts UIKit honours, all three of them measured as disagreements by the
    /// differential gate (task 17, finding D-2):
    ///
    /// 1. **the bottom/right maxima**, which the real presets do NOT make symmetric:
    ///    `permissionAlertProperties` is top 20 / bottom **12**, `streakProperties` top 40 /
    ///    bottom **32**, `renameInputProperties` top 32 / bottom **16** — so a V-only token
    ///    over-padded those cards by 8, 8 and 16pt of height respectively;
    /// 2. **the minima**, which are what lets a card under pressure COMPRESS its padding. In UIKit
    ///    the min is a `>=` at `.required` and the max an `==` at `.low`, so when the card cannot fit
    ///    its content plus max padding inside the screen margins the padding gives way first. The
    ///    real `streakProperties` engages exactly this on a 390pt-wide phone: it asks for
    ///    256 + 48 + 48 = 352 but only 350 is available, so UIKit sheds ~1pt of padding per side and
    ///    keeps the content at its stated 256. A rigid `.padding()` cannot do that;
    /// 3. the LEFT/RIGHT distinction, for the same reason as (1).
    ///
    /// `UIMinMaxEdgeInsets` is carried as-is rather than remodelled, for the same reason
    /// `AlertModalScaffold.buttonAxis` speaks `NSLayoutConstraint.Axis`: it is the exact type
    /// `Properties.padding` speaks, and a parallel SwiftUI vocabulary would be a second thing to
    /// keep in sync. `contentPaddingV`/`contentPaddingH` survive below as computed accessors.
    ///
    /// The `AlertModalScaffold` counterpart of the priority tiers, and its ONE stated limit, are
    /// documented on `AlertModalScaffold.card`.
    public var contentPadding: UIMinMaxEdgeInsets

    /// Whether the title/subtitle/button rows span the content width or hug their own content —
    /// `ContentProperty.childShouldMatchParent`, which UIKit applies as
    /// `svContentContainer.alignment = .fill` vs `.center` (`GBAlertModal+Style.swift`).
    ///
    /// Derived, not ignored: the `ModalTokens` audit used to classify `childShouldMatchParent` as
    /// "carried by `ResolvedModal`, not a token", and the differential gate MEASURED that claim to be
    /// false for the title and the subtitle (task 17, finding D-6) — `ResolvedModal` carries the
    /// BUTTON alignment (`buttonsMatchParent`) and nothing else, so the content rows had no channel
    /// at all and hugged on SwiftUI while UIKit filled. See the audit table on `init(from:)`.
    public var contentChildrenFillWidth: Bool

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
        contentMaxWidth: .infinity,   // no `Properties` to derive a cap from — see the doc above
        cardMarginV: 40,
        cardMarginH: 20,
        // min == max: `standard` has no `Properties`, so there is no min/max split to transcribe —
        // and equal min and max reproduce EXACTLY what the single-number `contentPaddingV: 24` /
        // `contentPaddingH: 32` did (a rigid 24/32 inset that never compresses). Callers with no
        // `Properties` therefore see no change from this field's split.
        contentPadding: UIMinMaxEdgeInsets(
            top: (24, 24), left: (32, 32), bottom: (24, 24), right: (32, 32)
        ),
        // `false`, matching UIKit's own default: `svContentContainer.alignment` is `.fill` only when
        // `contentProperty?.childShouldMatchParent == true`, and a caller with no `Properties` has no
        // `contentProperty` at all. It is also what the SwiftUI card already did (each `Text` hugged),
        // so property-less previews and demos keep today's layout.
        contentChildrenFillWidth: false,
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

    // MARK: - Derived geometry
    //
    // These three are COMPUTED, not stored: they are the numbers the card is actually laid out with,
    // and every one of them is a function of the fields above. Storing them alongside their inputs is
    // what let `cardMaxWidth` mean "the content width" in one place and "the card width" in another.

    /// **The CARD's width cap: the content cap plus the horizontal padding UIKit puts outside it.**
    ///
    /// UIKit never states this number anywhere — it FALLS OUT of the constraint graph, because
    /// `svContentContainer`'s width is pinned to `contentMaxWidth` and its leading/trailing sit
    /// `leftMax`/`rightMax` inside `vwContainer`, which has no width constraint of its own. So the
    /// card is exactly `content + leftMax + rightMax` whenever that fits inside the screen margins:
    /// 256 + 32 + 32 = **320** on the real preset, where the SwiftUI card used to be 256.
    ///
    /// `.infinity + finite == .infinity`, so an uncapped `contentMaxWidth` still yields an uncapped
    /// card and `ModalTokens.standard.cardMaxWidth` is unchanged at `.infinity`.
    public var cardMaxWidth: CGFloat {
        contentMaxWidth + contentPadding.leftMax + contentPadding.rightMax
    }

    /// Compatibility accessor: the TOP max inset, which is what this used to hold for all four
    /// vertical/horizontal edges. Read-only on purpose — writing one number to four edges is the
    /// conflation this split removed. Use `contentPadding` for anything that lays out.
    public var contentPaddingV: CGFloat { contentPadding.topMax }

    /// Compatibility accessor: the LEFT max inset. Same caveat as `contentPaddingV`.
    public var contentPaddingH: CGFloat { contentPadding.leftMax }

    /// **The least height the title row may be given — rung 2's floor, in points.**
    ///
    /// `minimumScaleFactor` bounds how small SwiftUI draws the glyphs; this bounds how little room the
    /// row is allocated, which is the other half of the same guarantee (measured: a title allocated
    /// 64.7pt where its floor-scaled text needed 85.9pt simply lost the difference). Delegates to
    /// `ModalLayout.titleFloorHeight`, the same measurement UIKit's rung 2 searches with.
    ///
    /// Measured at `contentMaxWidth` — the width the content column gives the row. For a HUGGING row
    /// (`contentChildrenFillWidth == false`) the real width is narrower, so the floor comes out
    /// slightly small; that errs toward less protection and never toward a too-tall row, which is the
    /// only direction that could disturb a passing shape.
    func titleFloorHeight(for text: String) -> CGFloat {
        ModalLayout.titleFloorHeight(text, font: titleUIFont, width: contentMaxWidth)
    }

    init(
        cornerRadius: CGFloat,
        contentMaxWidth: CGFloat,
        cardMarginV: CGFloat,
        cardMarginH: CGFloat,
        contentPadding: UIMinMaxEdgeInsets,
        contentChildrenFillWidth: Bool,
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
        self.contentMaxWidth = contentMaxWidth
        self.cardMarginV = cardMarginV
        self.cardMarginH = cardMarginH
        self.contentPadding = contentPadding
        self.contentChildrenFillWidth = contentChildrenFillWidth
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
    /// | `padding` | (a) | `contentPadding`, all eight edges verbatim — `test_contentPadding_comesFromProperties_allEightEdges`, `test_contentPadding_carriesTheAsymmetricRealPresets` |
    /// | `bannerRatio` | (a) | `bannerRatio` — `test_bannerRatio_comesFromProperties` |
    /// | `bannerMaxHeight` | (a) | `bannerMaxHeight` — `test_bannerMaxHeight_comesFromProperties`, `test_bannerMaxHeight_isNilWhenPropertiesSetsNoCap` |
    /// | `bannerFixedHeight` | (a) | `bannerFixedHeight` — `test_bannerFixedHeight_comesFromProperties` |
    /// | `titleFont` | (a) | `titleFont` AND its measurement twin `titleUIFont`, both from this one field — `test_titleFont_comesFromProperties_viaFontBridge`, `test_theStandardTitleFontAndItsMeasurementTwin_agree`. The twin exists because `Font` can be rendered but not measured, and rung 2's SwiftUI floor needs a measurement. |
    /// | `titleColor` | (a) | `palette.titleText` — `test_titleColor_comesFromProperties` |
    /// | `subtitleFont` | (a) | `subtitleFont` — `test_subtitleFont_comesFromProperties_viaFontBridge` |
    /// | `subtitleColor` | (a) | `palette.subtitleText` — `test_subtitleColor_comesFromProperties` |
    /// | `buttonActionShouldMatchParent` | (b) | Still not a TOKEN — it is a per-presentation render decision, resolved by the SHARED resolver into `ResolvedModal.buttonsMatchParent`. But it is no longer IGNORED: `SwiftUIAlertModal` now threads `resolved.buttonsMatchParent` into `AlertModalScaffold`, which passes it to `ObliquePrimaryStyle.fillsWidth` (the primary fills its slot or hugs its label, exactly as `.fill` vs `.center` does to `vwPrimaryAction`). It was previously deferred because `Properties.init` defaults the flag FALSE and the SwiftUI sentinel would then make every property-less preview hug; the sentinel now sets it `true`, matching every real preset. Measured as task 17's finding D-4. |
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
    /// | `fixedWidthPortrait` | (a) | folded into `contentMaxWidth` as a CAP — `test_contentMaxWidth_fallsBackToFixedWidth_whenNoMaxIsSet` |
    /// | `maxWidthPortrait` | (a) | `contentMaxWidth`, the CONTENT container's cap — `test_contentMaxWidth_comesFromProperties_maxWidthPortrait`, and `test_cardMaxWidth_isTheContentWidthPlusHorizontalPadding` for the card it implies |
    /// | `fixedWidthLandscape` | (a) | portrait-first fallback into `contentMaxWidth` — `test_contentMaxWidth_fallsBackToLandscapeWidths` |
    /// | `maxWidthLandscape` | (a) | portrait-first fallback into `contentMaxWidth` — `test_contentMaxWidth_fallsBackToLandscapeWidths` |
    /// | `childShouldMatchParent` | (a) | `contentChildrenFillWidth` — `test_contentChildrenFillWidth_comesFromProperties`. **This entry used to read (b), "carried by `ResolvedModal`, not tokens; every real preset sets it `true`, which is what the SwiftUI card already does". The differential gate measured that claim to be FALSE** (task 17, finding D-6): `ResolvedModal` carries only the BUTTON alignment, so the title and subtitle had no channel and hugged on SwiftUI while UIKit filled them to the content width. The claim was true for the buttons and for nothing else. |
    ///
    /// **One stated limit on the width group, unchanged by this task.** `fixedWidth` and `maxWidth`
    /// fold into ONE cap, so a preset that states a max WITHOUT a fixed width hugs its content in
    /// UIKit (the max is only a `<=`) and fills the cap here. Every preset in the app sets
    /// `fixed == max`, so no shipped shape is affected; a max-only preset would be.
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
    /// `buttonCornerRadius`, `buttonHeight`, `obliqueOffset`, `buttonLabelPaddingH`,
    /// `closeButtonSize`, `titleMinimumScaleFactor` (rung 2's floor, shared with UIKit via
    /// `ModalLayout.titleMinimumScaleFactor`) — no `ActionStyle` theme carries button geometry, and neither the close
    /// button's 48pt box nor the buttons' 16pt label inset comes from `Properties` at all: UIKit
    /// hardcodes every one of them (`GBAlertModal+ButtonStyling.swift`'s 8pt radius, 48pt slot
    /// height, ±3 offset and `contentEdgeInsets`; `GBAlertModal+ViewGraph.swift`'s `size == 48` on
    /// `btCloseAction`). Pinned by `test_noCounterpartFields_stayAtStandardLiterals`, and each is
    /// pinned to UIKIT's literal — not to a SwiftUI-side opinion — by the differential gate.
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
                contentMaxWidth = min(fixed, max)
            case let (fixed?, nil):
                contentMaxWidth = fixed
            case let (nil, max?):
                contentMaxWidth = max
            case (nil, nil):
                break   // no width in `Properties` at all — keep `standard`'s uncapped `.infinity`
            }
            // Unconditional, and `== true` rather than a fallback to `standard`: UIKit reads exactly
            // `properties?.contentProperty?.childShouldMatchParent == true`, so ABSENCE means
            // `.center` (children hug) and not "no opinion, use the default".
            contentChildrenFillWidth = contentProperty.childShouldMatchParent
            if let backgroundColor = contentProperty.backgroundColor {
                palette.cardBackground = Color(uiColor: backgroundColor)
            }
        }

        if let margin = properties.margin {
            cardMarginV = margin.top
            cardMarginH = margin.left
        }

        // All EIGHT edges, verbatim. Taking `topMax`/`leftMax` for all four sides is what over-padded
        // the permission-alert and streak cards by 8pt of height and the rename input by 16 (D-2).
        if let padding = properties.padding {
            contentPadding = padding
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
            // The measurement twin, from the SAME `UIFont` — see `titleUIFont`. Assigned here and
            // nowhere else, so the rendered font and the measured font cannot be different fonts.
            titleUIFont = titleFont
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
