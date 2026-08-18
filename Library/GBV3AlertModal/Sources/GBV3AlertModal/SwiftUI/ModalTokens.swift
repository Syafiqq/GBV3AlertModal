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
public struct ModalTokens: Sendable, Equatable {
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

    // The title's and subtitle's fonts live below, as `titleFont`/`subtitleFont`, and are `ModalFont`
    // rather than `Font` — ONE value carrying both what SwiftUI draws and what `ModalLayout`
    // measures.
    //
    // Two stored properties sat here — `titleUIFont`/`subtitleUIFont`, "the FALLBACK font the title
    // floor measures with" — because `SwiftUI.Font` is opaque: renderable, not measurable, with no
    // `Font -> UIFont` direction to recover one from. That reason is unchanged and is why `ModalFont`
    // stores the `UIFont` and derives the `Font`, rather than the other way round.
    //
    // What DID change is that they are no longer separately settable. `init(from: Properties)` set
    // both from the one `Properties.titleFont` and could not drift — but the memberwise `init` took
    // only the `Font`, so `standard` stated `.system(size: 24, weight: .bold)` and let the `UIFont`
    // keep its own default: the same face, typed twice, agreeing by hand.
    // `test_theStandardTitleFontAndItsMeasurementFallback_agree` guarded that coincidence. With one
    // stored value there is no coincidence left to guard, and the drift it protected against is now
    // unwritable rather than merely tested for. See `ModalFont`.

    /// The close button's tap target, 48×48. UIKit pins `btCloseAction` to `vwContainer`'s
    /// top-trailing with `size == 48` (`GBAlertModal+ViewGraph.swift`'s `installConstraints`); the
    /// SwiftUI scaffold used 44 (the HIG minimum) and therefore drew the glyph 2pt further from both
    /// card edges with a tap target 16% smaller in area — measured as task 17's finding D-5. No
    /// `Properties` counterpart: the 48 is hardcoded on the UIKit side too.
    public var closeButtonSize: CGFloat = 48

    // `contentScrollable` mirrored `Properties.contentScrollable` here and is DELETED with it. The
    // subtitle now scrolls unconditionally through `SwiftUIAlertModal.SubtitleSlot`, so there is no
    // longer anything for a token to gate.

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
    public var titleFont: ModalFont
    public var subtitleFont: ModalFont
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

    /// **The two `ActionStyle` cases `ObliquePrimaryStyle`/`PlainSecondaryStyle` cannot draw, now
    /// drawn for real.** `nil` (the case for every real Genie preset today, and for `standard`) means
    /// "this slot is the fixed oblique/plain look" — `AlertModalScaffold` falls back to
    /// `ObliquePrimaryStyle`/`PlainSecondaryStyle` exactly as before. Non-`nil` means the caller's
    /// `primaryActionStyle`/`secondaryActionStyle` was actually `.capsule`/`.capsuleOutlined`, and the
    /// scaffold draws `CapsuleButtonStyle`/`CapsuleOutlinedButtonStyle` from this instead.
    ///
    /// Was permanently `nil` (spec-D8: "no real preset uses capsule, so painting its colours onto the
    /// oblique/plain SHAPE would be a worse divergence than keeping the literal"). That reasoning
    /// argued against COUNTERFEITING a capsule with the wrong shape — it never argued against drawing
    /// the real one, and `ModalProperties`' own doc says as much: `.capsule` was "inert only because
    /// the SwiftUI RENDERER has not implemented it," carried in the vocabulary on purpose so a future
    /// implementation would not be a source break. This is that implementation.
    public var primaryCapsule: CapsuleVisual?
    public var primaryCapsuleOutlined: CapsuleOutlinedVisual?
    public var secondaryCapsule: CapsuleVisual?
    public var secondaryCapsuleOutlined: CapsuleOutlinedVisual?

    public var palette: Palette

    public struct Palette: Sendable, Equatable {
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

    /// The colours/font `CapsuleButtonStyle` draws from — a solid pill, filled, no border.
    /// `ActionStyle.CapsuleTheme`'s SwiftUI-side twin, one level post-conversion (`Color`/`Font`
    /// already resolved, both derivations' `UIColor?`/already-`Color?` fields land here the same way
    /// every other `palette` field does). Every field defaults to a real value rather than staying
    /// optional: `CapsuleTheme`'s OWN fields are all optional because UIKit is happy to leave a
    /// `UIButton`'s background/title colour unset (reads as clear / the button's tint), and SwiftUI
    /// has no such implicit default to fall back on — `init(theme:fallbackFont:)` is where that gap
    /// is closed, once, rather than by every read site.
    public struct CapsuleVisual: Sendable, Equatable {
        public var background: Color
        public var backgroundDisabled: Color
        public var title: Color
        public var titleDisabled: Color
        public var font: Font

        public init(
            background: Color, backgroundDisabled: Color, title: Color, titleDisabled: Color, font: Font
        ) {
            self.background = background
            self.backgroundDisabled = backgroundDisabled
            self.title = title
            self.titleDisabled = titleDisabled
            self.font = font
        }
    }

    /// `CapsuleOutlinedButtonStyle`'s counterpart — same fields as `CapsuleVisual` plus the border,
    /// `ActionStyle.CapsuleOutlineTheme`'s SwiftUI-side twin.
    public struct CapsuleOutlinedVisual: Sendable, Equatable {
        public var background: Color
        public var backgroundDisabled: Color
        public var title: Color
        public var titleDisabled: Color
        public var borderColor: Color
        public var borderDisabledColor: Color
        public var borderWidth: CGFloat
        public var font: Font

        public init(
            background: Color, backgroundDisabled: Color, title: Color, titleDisabled: Color,
            borderColor: Color, borderDisabledColor: Color, borderWidth: CGFloat, font: Font
        ) {
            self.background = background
            self.backgroundDisabled = backgroundDisabled
            self.title = title
            self.titleDisabled = titleDisabled
            self.borderColor = borderColor
            self.borderDisabledColor = borderDisabledColor
            self.borderWidth = borderWidth
            self.font = font
        }
    }

    public static let standard = ModalTokens(
        // ↓ everything below is unchanged from before `CapsuleVisual`/`CapsuleOutlinedVisual`
        // existed — `standard` carries no `Properties`, so both fixed styles stay `nil` (the
        // oblique/plain fallback), the same as every field this type has no input for.
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
    ///
    /// **This is a FLOOR ON the card's cap, not the cap itself.** Since the banner column became a
    /// live input, `AlertModalScaffold.body` applies
    /// `max(cardMaxWidth, bannerGeometry.column + leftMax + rightMax)` — so artwork wider than the
    /// content column pushes the card PAST this number, exactly as UIKit's unconstrained
    /// `vwContainer` does. Read this as "the card is never narrower than this", and read
    /// `AlertModalScaffold`'s `max(...)` for how wide it may actually get.
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
    ///
    /// **Takes the STYLED title.** It used to take a `String`, and the call site flattened the
    /// `AttributedString` with `String(title.characters)` — discarding any per-run font, which `Text`
    /// nonetheless draws. `titleFont.uiFont` is the fallback for runs stating no font of their own, not a
    /// replacement for the ones that do.
    func titleFloorHeight(for text: NSAttributedString) -> CGFloat {
        ModalLayout.titleFloorHeight(text, fallback: titleFont.uiFont, width: contentMaxWidth)
    }

    /// Convenience for an unstyled title: every glyph in `titleFont.uiFont`. Same answer the `String`
    /// overload used to give, kept because most callers (and every test fixture) have a plain string.
    func titleFloorHeight(for text: String) -> CGFloat {
        titleFloorHeight(for: NSAttributedString(string: text, attributes: [.font: titleFont.uiFont]))
    }

    /// **The subtitle row's floor: one line, the SwiftUI half of `ModalLayout.subtitleFloorHeight`.**
    ///
    /// UIKit holds this back with a `>=` on the scroll slot at `Priority.subtitleSlotFloor`; SwiftUI
    /// carries it as the `minHeight` of `SwiftUIAlertModal.SubtitleSlot`, which is the same slot in
    /// the same place. Same function, same number, so neither renderer can protect more of the body
    /// text than the other.
    ///
    /// **It used to sit on the `Text` instead, where it was inert by construction** — a non-empty
    /// label already reports at least one line, so a floor on the text could never bind. It binds on
    /// the SLOT, whose whole job is to be given less than its content: measured in landscape, the
    /// slot lands exactly here (19.09) while the text inside it is 38.33.
    var subtitleFloorHeight: CGFloat {
        ModalLayout.subtitleFloorHeight(font: subtitleFont.uiFont)
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
        titleFont: ModalFont,
        subtitleFont: ModalFont,
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
    /// | `titleFont` | (a) | `titleFont`, a `ModalFont` — ONE value carrying both what SwiftUI draws (`.font`) and what `ModalLayout` measures (`.uiFont`) — `test_titleFont_comesFromProperties_viaFontBridge`. It stores the `UIFont` and derives the `Font` because `Font` can be rendered but not measured; `.uiFont` is the FALLBACK for title runs stating no font, not a second way to state one. |
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
    /// The primary/secondary slots default to FIXED design identity (spec D8): with no
    /// `primaryActionStyle`/`secondaryActionStyle`, or `.obliqueBottomLeft`/`.plain` respectively,
    /// the primary IS the oblique button and the secondary IS the plain text button. `.capsule`/
    /// `.capsuleOutlined` are a real fourth/fifth look, not a counterfeit of the fixed ones — see
    /// `primaryCapsule`/`primaryCapsuleOutlined`/`secondaryCapsule`/`secondaryCapsuleOutlined` below,
    /// which `AlertModalScaffold` checks BEFORE falling back to oblique/plain.
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
    /// | `CapsuleTheme.*` (5 fields) | (a) | `primaryCapsule`/`secondaryCapsule` (whichever slot carries `.capsule`) — `CapsuleButtonStyle` draws a real filled pill from these, no longer the oblique/plain counterfeit — `test_primaryCapsule_derivesFromProperties`/`test_secondaryCapsule_derivesFromProperties`. |
    /// | `CapsuleOutlineTheme.*` (8 fields) | (a) | `primaryCapsuleOutlined`/`secondaryCapsuleOutlined`, `CapsuleOutlinedButtonStyle` — same as `CapsuleTheme` plus the three border fields, which now have a real analogue (`Capsule().stroke(...)`) — `test_primaryCapsuleOutlined_derivesFromProperties`/`test_secondaryCapsuleOutlined_derivesFromProperties`. |
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
        // would apply a cap UIKit does not (the real `V3AlertModal` preset is exactly that case).
        //
        // That reason used to carry a second clause — "and it would also silently clip a
        // `bannerFixedHeight` taller than 160" — which is now moot and is removed rather than left
        // to rot: NOTHING lays out with `bannerFixedHeight` any more. `BannerLayout` has no field
        // for it (it is inert in UIKit on BOTH paths, measured by
        // `BannerGeometryTruthTests.test_bannerFixedHeight_isInert_*`), so there is no height for a
        // cap to clip. The field is still carried below, and only carried.
        bannerRatio = properties.bannerRatio
        bannerMaxHeight = properties.bannerMaxHeight
        bannerFixedHeight = properties.bannerFixedHeight

        if let space = properties.space {
            gapBelowBanner = space.banner
            gapBelowTitle = space.title
            gapBelowSubtitle = space.subtitle
            interButton = space.interButton
        }

        // ONE assignment each, where there used to be two. `ModalFont` carries the `UIFont` the
        // caller stated and derives the `Font` from it, so "the rendered font and the measured font
        // cannot be different fonts" is now structural rather than a property of this code.
        if let titleFont = properties.titleFont {
            self.titleFont = ModalFont(titleFont)
        }
        if let subtitleFont = properties.subtitleFont {
            self.subtitleFont = ModalFont(subtitleFont)
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
        if case let .capsule(theme)? = properties.primaryActionStyle {
            primaryCapsule = CapsuleVisual(theme: theme, fallbackFont: primaryButtonFont)
        }
        if case let .capsuleOutlined(theme)? = properties.primaryActionStyle {
            primaryCapsuleOutlined = CapsuleOutlinedVisual(theme: theme, fallbackFont: primaryButtonFont)
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
        if case let .capsule(theme)? = properties.secondaryActionStyle {
            secondaryCapsule = CapsuleVisual(theme: theme, fallbackFont: secondaryButtonFont)
        }
        if case let .capsuleOutlined(theme)? = properties.secondaryActionStyle {
            secondaryCapsuleOutlined = CapsuleOutlinedVisual(theme: theme, fallbackFont: secondaryButtonFont)
        }
    }
}

// MARK: - Capsule visual derivation (both `init(from:)` inputs)

extension ModalTokens.CapsuleVisual {
    /// From the UIKit-region theme (`GBAlertModal.Properties.primaryActionStyle`/
    /// `.secondaryActionStyle`). Every `CapsuleTheme` field is optional — UIKit is happy to leave a
    /// `UIButton`'s background/title unset — so a nil field falls back to a plain, visible default
    /// (clear background, `.primary` title) rather than propagating the optionality: nothing in
    /// `CapsuleButtonStyle` reads `Color?`, the same reason every OTHER token here is a concrete
    /// `Color`, not the `UIColor?` its `Properties` counterpart is.
    init(theme: GBAlertModal.ActionStyle.CapsuleTheme, fallbackFont: Font) {
        self.init(
            background: theme.backgroundColor.map(Color.init(uiColor:)) ?? .clear,
            backgroundDisabled: theme.backgroundDisableColor.map(Color.init(uiColor:)) ?? .clear,
            title: theme.titleColor.map(Color.init(uiColor:)) ?? .primary,
            titleDisabled: theme.titleDisableColor.map(Color.init(uiColor:)) ?? Color.primary.opacity(0.3),
            font: theme.titleFont.map(Font.init) ?? fallbackFont
        )
    }

    /// From the SwiftUI-native theme (`ModalProperties`) — same fallbacks, no colour conversion
    /// (the caller already stated a `Color`), mirroring the split every other field in this file has
    /// between its two `init(from:)` derivations.
    init(theme: ModalProperties.ActionStyle.CapsuleTheme, fallbackFont: Font) {
        self.init(
            background: theme.backgroundColor ?? .clear,
            backgroundDisabled: theme.backgroundDisableColor ?? .clear,
            title: theme.titleColor ?? .primary,
            titleDisabled: theme.titleDisableColor ?? Color.primary.opacity(0.3),
            font: theme.titleFont?.font ?? fallbackFont
        )
    }
}

extension ModalTokens.CapsuleOutlinedVisual {
    init(theme: GBAlertModal.ActionStyle.CapsuleOutlineTheme, fallbackFont: Font) {
        self.init(
            background: theme.backgroundColor.map(Color.init(uiColor:)) ?? .clear,
            backgroundDisabled: theme.backgroundDisableColor.map(Color.init(uiColor:)) ?? .clear,
            title: theme.titleColor.map(Color.init(uiColor:)) ?? .primary,
            titleDisabled: theme.titleDisableColor.map(Color.init(uiColor:)) ?? Color.primary.opacity(0.3),
            borderColor: theme.borderColor.map(Color.init(cgColor:)) ?? .primary,
            borderDisabledColor: theme.borderDisableColor.map(Color.init(cgColor:)) ?? Color.primary.opacity(0.3),
            borderWidth: theme.borderWidth ?? 1,
            font: theme.titleFont.map(Font.init) ?? fallbackFont
        )
    }

    init(theme: ModalProperties.ActionStyle.CapsuleOutlineTheme, fallbackFont: Font) {
        self.init(
            background: theme.backgroundColor ?? .clear,
            backgroundDisabled: theme.backgroundDisableColor ?? .clear,
            title: theme.titleColor ?? .primary,
            titleDisabled: theme.titleDisableColor ?? Color.primary.opacity(0.3),
            borderColor: theme.borderColor ?? .primary,
            borderDisabledColor: theme.borderDisableColor ?? Color.primary.opacity(0.3),
            borderWidth: theme.borderWidth ?? 1,
            font: theme.titleFont?.font ?? fallbackFont
        )
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
    /// constraint is `ivBanner.width == ivBanner.height * bannerRatio`); `maxHeight` caps the slot.
    /// Either `nil` means "no such constraint", exactly as in UIKit.
    ///
    /// There is deliberately no `height` field. It existed to carry `bannerFixedHeight`, which is
    /// measured INERT in UIKit on both paths (see `bannerLayout` below), so it was unconditionally
    /// `nil` and the modifier branch that read it was unconditionally a no-op. Both are gone.
    struct BannerLayout: Equatable {
        var aspectRatio: CGFloat?
        var maxHeight: CGFloat?
    }

    /// **The banner's content column and slot height, as UIKit resolves them.**
    ///
    /// UIKit gives `vwBanner` no height constraint at all on the `bannerRatio != nil` path: the
    /// slot's size falls out of `ivBanner`'s INTRINSIC content size meeting its default vertical
    /// compression resistance (750) through the `width == height * ratio` tie — and that same 750
    /// outranks the content column's `width == fixedWidth` at `.medium` (500), so wide artwork
    /// makes the COLUMN wider too. Both facts are invisible from `Properties` alone, which is why
    /// this takes the artwork's point size.
    ///
    /// Not a measurement cycle (the trap recorded in the brief's §7): `imageSize` is a property of
    /// the asset, prior to and independent of the frame this returns, and `availableCardWidth`
    /// comes from the CONTAINER, not from the content it constrains.
    ///
    /// **The HEIGHT this returns is a DESIRE, not a resolved height — and that distinction is what
    /// makes landscape work.** In a height-constrained card UIKit distributes the remainder across
    /// four sub-required priority tiers and the banner takes the residual (measured ~102.3 for every
    /// real preset in landscape, regardless of ratio or cap: four different ratio/cap/artwork
    /// combinations produce the identical number, which is what "it takes whatever is left" looks
    /// like from outside). Nothing computed here reaches that number, and nothing needs to:
    /// `BannerSlot` applies this height as a `.frame(maxHeight:)` over a greedy `Color.clear`, so
    /// the SLOT resolves to `min(thisDesire, whateverIsLeft)` — UIKit's yield semantics, produced by
    /// the layout engine rather than by arithmetic. Where the card is roomy the two are the same
    /// number and portrait is untouched; where it is not, the slot yields. See `BannerSlot`'s doc.
    ///
    /// **The COLUMN, however, is still a PORTRAIT rule, and that is the live limitation.** UIKit's
    /// landscape arbitration shrinks the banner's height, and the required
    /// `ivBanner.width == ivBanner.height * ratio` tie shrinks the image's WIDTH DEMAND with it —
    /// measured, `ivBanner` is 172pt wide inside a 256pt `vwBanner` — so the demand drops below
    /// `contentMaxWidth` and UIKit's column does not grow there. The consequence is a 64pt-wide
    /// column overshoot on wide artwork in landscape, which reaches the card and every row that
    /// matches the card's width.
    ///
    /// **The RULE behind that is known, and it is one operand away from the code below** — this used
    /// to read "circular; it needs a measurement pass, not a formula", which conflated a rule that
    /// does exist with an operand that is not available. Measured, at 264 configurations (two
    /// fixtures x four ratios x three caps x eleven host heights) with a worst-case error of 0.17pt:
    ///
    /// ```
    /// column = min(ceiling, max(contentMaxWidth, min(imageW, cap * ratio, RESOLVED_HEIGHT * ratio)))
    /// ```
    ///
    /// — i.e. exactly the code below plus `RESOLVED_HEIGHT * ratio` in the demand, which is the
    /// `width == height * ratio` tie read forwards. It is a genuinely three-valued rule and not a
    /// landscape special case: at 844x450 `banner-wide`'s column is **273.33**, strictly between
    /// `contentMaxWidth` (256) and the portrait answer (320). Pinned against measured Auto Layout in
    /// `DifferentialGeometryTests.test_uiKitColumn_isTheResolvedBannerHeightTimesTheRatio`, whose own
    /// non-vacuity guards require the sweep to reach both regimes.
    ///
    /// **What is unavailable is `RESOLVED_HEIGHT`, and the obstruction is ORDER, not arithmetic.**
    /// `RESOLVED_HEIGHT` is `min(desire, residual)`; `desire` is the value this function returns, and
    /// `residual` is what UIKit's vertical arbitration leaves over. SwiftUI's layout engine does
    /// compute that residual — `BannerSlot`'s `.frame(maxHeight:)` yield reproduces UIKit's landscape
    /// banner height to within 0.5pt — but it produces it BOTTOM-UP, during the layout pass, whereas
    /// the column is applied TOP-DOWN by `AlertModalScaffold` on `card`, an ANCESTOR of `BannerSlot`.
    /// A parent's width proposal is committed before the child's height is resolved, so no
    /// single-pass expression of this view tree can spend the height on the width.
    ///
    /// Two measurements close off the obvious escapes rather than leaving them to argument:
    ///
    /// * **Letting the stack size to the banner instead does not work.** The column is the width the
    ///   title, subtitle and buttons all fill, and they fill it because they are
    ///   `.frame(maxWidth: .infinity)` — which returns the PROPOSED width, so the stack's width is
    ///   whatever the ancestor proposed, banner or no banner. Capping those rows at
    ///   `contentMaxWidth` instead does let the stack follow an aspect-ratio-shaped banner, and was
    ///   measured doing exactly that: the banner reports 310 and the rows stay at 256, where UIKit
    ///   stretches every row to the full 310. That trades a landscape width divergence for a portrait
    ///   one.
    /// * **The residual is not a constant that could be tabulated per preset.** For
    ///   `banner-comparable` the non-banner content is 127.67pt tall in landscape and 147pt in
    ///   portrait — the difference is exactly the 19.33pt the subtitle viewport gives up under
    ///   pressure. And the coupling runs the other way too: `banner-wide`'s subtitle is 38.33pt tall
    ///   at a 256pt column and 19.33pt at a 320pt one. So the residual is an output of the
    ///   compression ladder, and the ladder's input includes the column this function is trying to
    ///   compute. That is the circularity — it is real, but it lives in `residual`, not in the rule.
    ///
    /// Reaching it therefore needs either a feedback pass (measure, re-propose) or an arithmetic
    /// re-implementation of UIKit's four-tier vertical arbitration in SwiftUI — a second model of the
    /// ladder that would have to agree with the one SwiftUI's own `VStack` is already running.
    /// Neither is worth 64pt on one orientation of one shape; see the report at
    /// `.superpowers/sdd/2026-08-02-swiftui-banner-geometry/landscape-width-report.md`.
    ///
    /// So the landscape gate is scoped to exactly that: `banner-wide` is compared on every ORIGIN
    /// and every HEIGHT at the usual 0.5pt
    /// (`test_geometry_landscape_bannerWide_agreesOnEveryOriginAndHeight`) and on no width, with the
    /// exclusion's mechanism pinned by `test_bannerWide_landscape_theWidthGapIsTheColumnRule` and its
    /// rule by `test_uiKitColumn_isTheResolvedBannerHeightTimesTheRatio`. `banner-comparable` IS
    /// gated in landscape, in full, through the ordinary `assertAgrees` — its widths already agree,
    /// and the D-7 subtitle viewport that used to hold it back is closed.
    ///
    /// Pinned against measured Auto Layout output in `BannerGeometryTruthTests`.
    struct BannerGeometry: Equatable {
        /// The content column's width — `contentMaxWidth`, or wider when the artwork demands it.
        var column: CGFloat
        /// The banner SLOT's height — the counterpart of `vwBanner`, not of the picture inside it.
        var height: CGFloat

        static let zero = BannerGeometry(column: 0, height: 0)
    }

    /// `imageSize` is the artwork's POINT size (`ModalImage.pointSize`), not its pixel size.
    /// `availableCardWidth` is the host width minus both card margins.
    ///
    /// One degenerate case worth naming: when `contentMaxWidth` is `.infinity` — the
    /// no-`Properties` sentinel path, `ModalTokens.standard` — the `max(demand, contentMaxWidth)`
    /// term is `.infinity` for ANY artwork, so the column collapses to the ceiling and the
    /// artwork's own demand stops mattering. The ceiling is what keeps that finite; pinned by
    /// `ModalBannerGeometryRuleTests.test_infiniteContentMaxWidth_doesNotProduceAnInfiniteColumn`.
    func bannerGeometry(imageSize: CGSize, availableCardWidth: CGFloat) -> BannerGeometry {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let ratio = bannerRatio ?? (imageSize.width / imageSize.height)
        guard ratio > 0, ratio.isFinite else { return .zero }

        let cap = bannerMaxHeight ?? .greatestFiniteMagnitude
        // The column can never exceed what is left of the card after its RIGID minimum padding —
        // UIKit's `.required` leading/trailing inequalities. The max padding is `.low` and gives
        // way, which is why the minima are what bound this.
        let ceiling = max(0, availableCardWidth - contentPadding.leftMin - contentPadding.rightMin)
        // What the artwork asks the column for: its own width, but never more than the cap allows
        // a ratio-shaped slot to be wide.
        let demand = min(imageSize.width, cap * ratio)
        let column = min(max(demand, contentMaxWidth), ceiling)
        // The smallest of: the cap, what the column allows at this ratio, and the smallest
        // ratio-shaped box containing the artwork.
        let height = min(cap, min(column / ratio, max(imageSize.height, imageSize.width / ratio)))
        return BannerGeometry(column: column, height: height)
    }

    /// PRECEDENCE, read off `GBAlertModal+ViewGraph.swift`'s `installConstraints` (the UIKit
    /// constraint PRIORITIES), not guessed. On `vwBanner` UIKit installs, at most:
    ///
    /// * `height <= bannerMaxHeight` at **950** — whenever `bannerMaxHeight` is set;
    /// * `height == width * (imageH/imageW)` at **245** — the natural-aspect driver, installed ONLY
    ///   when `bannerRatio == nil` and the image has a usable size;
    /// * `height == bannerFixedHeight` at **243** — whenever `bannerFixedHeight` is set.
    ///
    /// (These were 751/700/251 until the ladder was reordered to put every banner DRIVER below every
    /// text rung — "banner never wins". The cap moved the other way, UP, because it is a `<=` that
    /// keeps the banner SMALL and so protects the text.)
    ///
    /// So: the cap (950) outranks everything and is always applied when present. Below it,
    /// `bannerFixedHeight` (243) sits BELOW both remaining drivers on EITHER path:
    /// * when `bannerRatio == nil`, the natural-aspect driver (245) beats it outright;
    /// * when `bannerRatio != nil`, there is no natural-aspect driver, but the fixed height now sits
    ///   below the card's `.low` (250) hugging too — the card wins the tie before the fixed height
    ///   ever gets a say.
    ///
    /// **So `bannerFixedHeight` is INERT on BOTH paths** — measured zero effect at every size tried
    /// (`BannerGeometryTruthTests.test_bannerFixedHeight_isInert_onTheRatioPath` and
    /// `..._onTheNaturalAspectPath`), which is why `bannerLayout` below never applies it. This used to
    /// read as a two-path story ("inert on natural-aspect, pins the slot on ratio") — that was wrong;
    /// the truth-table tests are what caught it.
    ///
    /// The ratio itself is a constraint on the IMAGE VIEW's frame (`width == height * ratio`) with
    /// `contentMode = .scaleAspectFit` inside it — i.e. a ratio-shaped SLOT with the picture
    /// letterboxed in it, which `SwiftUIAlertModal`'s banner row reproduces directly (the slot/image
    /// split — see its doc comment). `bannerLayout` itself now only feeds the bespoke-content banner
    /// rows (`SwiftUIModalRenderer+BespokeViews.swift`), which apply `aspectRatio`/`maxHeight` inline;
    /// the standard banner path reads `bannerGeometry(imageSize:availableCardWidth:)` instead.
    var bannerLayout: BannerLayout {
        // `bannerFixedHeight` is NOT carried at all — `BannerLayout` has no field for it. At
        // priority 243 it loses to the card's hugging (250) going up and to the image's
        // compression resistance (750) coming down, so UIKit ignores it on BOTH paths — measured
        // zero effect at every size tried, including `fixed 200` on a 64pt image
        // (`BannerGeometryTruthTests.test_bannerFixedHeight_*`). Applying it here was a live
        // divergence on every preset that sets both, which is all of them.
        // `ModalTokens.bannerFixedHeight` still carries the value; nothing lays out with it.
        BannerLayout(aspectRatio: bannerRatio, maxHeight: bannerMaxHeight)
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

// MARK: - The SwiftUI-native derivation

extension ModalTokens {
    /// **The same derivation as `init(from: GBAlertModal.Properties)`, over the SwiftUI-native
    /// config — step for step, in the same order, with the same conditions.**
    ///
    /// It is a deliberate transcription rather than a shared implementation, because the two inputs
    /// share no type: that is what §3a's "parallel type, not a translation layer" costs, and the
    /// price of it is exactly the failure mode a transcription has — a field read into the wrong
    /// token, or dropped. `ModalPropertiesEquivalenceTests` is the gate for that, and it is not a
    /// field-by-field re-transcription of this function: it builds ONE preset both ways and asserts
    /// the two `ModalTokens` are equal, so a mistake here has to be made identically in the test to
    /// survive.
    ///
    /// **Every difference from the UIKit derivation is a difference in the INPUT, never in the
    /// rule.** There are only three, and each is `ModalProperties`' doc:
    ///
    /// 1. No colour conversion. The UIKit path wraps every colour in `Color(uiColor:)`; here the
    ///    caller already stated a `Color`.
    /// 2. No `bannerFixedHeight` — the field does not exist on this type. `standard`'s value (nil)
    ///    stands, which is what a `Properties` that omits it produces too, and nothing lays out
    ///    with it on either backend regardless.
    /// 3. `margin.leading` where the UIKit path reads `margin.left`. `EdgeInsets` is
    ///    direction-aware and `UIEdgeInsets` is not; both presets are horizontally symmetric, and
    ///    `cardMarginH` is applied to both sides anyway.
    // swiftlint:disable:next function_body_length
    public init(from properties: ModalProperties) {
        self = .standard

        if let contentProperty = properties.contentProperty {
            cornerRadius = contentProperty.cornerRadius
            // Portrait-first with a landscape fallback, and a FIXED width folded in as a cap rather
            // than a `.frame(width:)` — the reasoning is on the UIKit derivation above and is not
            // repeated, because it is the same rule reading the same four fields.
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
                break
            }
            contentChildrenFillWidth = contentProperty.childShouldMatchParent
            if let backgroundColor = contentProperty.backgroundColor {
                palette.cardBackground = backgroundColor
            }
        }

        if let margin = properties.margin {
            cardMarginV = margin.top
            cardMarginH = margin.leading
        }

        if let padding = properties.padding {
            contentPadding = padding
        }

        // SwiftUI gets the aspect ratio from Image itself. Only the optional safety cap is a token.
        bannerRatio = nil
        bannerMaxHeight = properties.banner?.maximumHeight

        if let space = properties.space {
            gapBelowBanner = space.banner
            gapBelowTitle = space.title
            gapBelowSubtitle = space.subtitle
            interButton = space.interButton
        }

        if let titleFont = properties.titleFont {
            self.titleFont = titleFont
        }
        if let subtitleFont = properties.subtitleFont {
            self.subtitleFont = subtitleFont
        }
        if let titleColor = properties.titleColor {
            palette.titleText = titleColor
        }
        if let subtitleColor = properties.subtitleColor {
            palette.subtitleText = subtitleColor
        }
        if let overlayColor = properties.overlayColor {
            palette.scrim = overlayColor
        }
        if let closeButtonTint = properties.closeButtonTint {
            palette.closeButton = closeButtonTint
        }

        // `.obliqueBottomLeft` for the primary and `.plain` for the secondary, same as the UIKit
        // derivation — any other case keeps `standard`'s literals rather than guessing a mapping
        // onto a shape this backend does not draw.
        if case let .obliqueBottomLeft(theme)? = properties.primaryActionStyle {
            if let unPressedColor = theme.unPressedColor {
                palette.accent = unPressedColor
            }
            if let pressedColor = theme.pressedColor {
                palette.accentPressed = pressedColor
            }
            if let disabledColor = theme.disabledColor {
                palette.disabled = disabledColor
            }
            if let shadowColor = theme.shadowColor {
                palette.shadow = shadowColor
            }
            if let titleColor = theme.titleColor {
                palette.onAccent = titleColor
            }
            if let titleDisableColor = theme.titleDisableColor {
                palette.onAccentDisabled = titleDisableColor
            }
            if let titleFont = theme.titleFont {
                primaryButtonFont = titleFont.font
            }
        }
        if case let .capsule(theme)? = properties.primaryActionStyle {
            primaryCapsule = CapsuleVisual(theme: theme, fallbackFont: primaryButtonFont)
        }
        if case let .capsuleOutlined(theme)? = properties.primaryActionStyle {
            primaryCapsuleOutlined = CapsuleOutlinedVisual(theme: theme, fallbackFont: primaryButtonFont)
        }

        // The secondary's colours come from the SECONDARY theme and must never be re-pointed at
        // `palette.accent` — see the UIKit derivation for the shape that caught it.
        if case let .plain(theme)? = properties.secondaryActionStyle {
            if let titleColor = theme.titleColor {
                palette.secondaryLabel = titleColor
            }
            if let titleDisableColor = theme.titleDisableColor {
                palette.secondaryDisabled = titleDisableColor
            }
            if let titleFont = theme.titleFont {
                secondaryButtonFont = titleFont.font
            }
        }
        if case let .capsule(theme)? = properties.secondaryActionStyle {
            secondaryCapsule = CapsuleVisual(theme: theme, fallbackFont: secondaryButtonFont)
        }
        if case let .capsuleOutlined(theme)? = properties.secondaryActionStyle {
            secondaryCapsuleOutlined = CapsuleOutlinedVisual(theme: theme, fallbackFont: secondaryButtonFont)
        }
    }
}
