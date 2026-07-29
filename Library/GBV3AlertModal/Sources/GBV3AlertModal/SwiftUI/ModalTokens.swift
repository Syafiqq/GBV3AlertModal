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
/// with no `Properties` counterpart) — nothing about `standard`'s numbers changes in this commit.
public struct ModalTokens: Sendable {
    // Card geometry. Width MAXIMIZES to fill (screen − 2·horizontal margin), capped at
    // cardMaxWidth. `standard` has no `Properties` to derive a cap from, so it ships `.infinity`
    // (no cap — deliberately NOT a `UIDevice.current.userInterfaceIdiom` runtime check: (1) baking
    // a device query into a token is exactly the hardcoding spec C-0 exists to remove, and (2) it
    // is main-actor-isolated, which a nonisolated `static let`/`init` can't touch. `init(from:)`
    // applies `contentProperty.maxWidthPortrait` as the cap whenever `Properties` supplies one,
    // unconditionally: `.frame(maxWidth:)` is a CAP, not a fixed width, so on a phone-width screen
    // (already narrower than any realistic cap) it is naturally a no-op — no idiom branch needed.
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

    // Banner — image keeps its natural aspect ratio (scaledToFit); this caps the height so tall art
    // can't dominate. `Properties.bannerMaxHeight` is a real, direct counterpart.
    public var bannerMaxHeight: CGFloat

    // Vertical gaps — owner override to a uniform 12 (real preset was 8/8/16); interButton stays 8.
    // `standard` keeps that override baked in; `from(properties:)` reads the real `ComponentSpace`
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
        public var onAccent: Color
        public var shadow: Color
        public var cardBackground: Color
        // The FINAL, already-composited scrim colour (any dimming baked in) — not a base hue plus a
        // separate opacity multiply. `standard` bakes its 0.6 dim in at construction time;
        // `from(properties:)` takes `overlayColor` as-is, since a real `Properties` value already
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
            shadow: Color(hex: 0xE57B41),           // orangeMandarin
            cardBackground: .white,
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
        bannerMaxHeight: CGFloat,
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
        self.bannerMaxHeight = bannerMaxHeight
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
    /// Starts from `standard` and overrides only the fields `properties` actually supplies —
    /// every `Properties` field this type reads is `Optional`, and a caller with a partially-filled
    /// `Properties` (or none at all) should fall back to the same literals `standard` ships, never
    /// a fabricated or zeroed value. `UIColor -> Color`, `CGColor -> Color`, and `UIFont -> Font`
    /// are lossless bridging conversions.
    public init(from properties: GBAlertModal.Properties) {
        self = .standard

        if let contentProperty = properties.contentProperty {
            cornerRadius = contentProperty.cornerRadius
            // Unconditional — no `UIDevice` idiom check (see the type's doc comment above): a
            // `.frame(maxWidth:)` cap is naturally inert once the available width is already
            // narrower than it, so applying it regardless of idiom is both concurrency-safe and
            // behaviourally equivalent to gating it on `.pad`.
            //
            // KNOWN LIMITATION: only reads `maxWidthPortrait`. The library's own resolver
            // (`GBAlertModal+ResolvedModal.swift`, `contentWidth`) does full fixed-vs-max +
            // portrait/landscape fallback (`fixedWidthPortrait`/`fixedWidthLandscape`/
            // `maxWidthLandscape`, and a FIXED width wins over a max at all). This derivation
            // bypasses that shared resolution entirely and only ever reads one of the four
            // fields. Harmless for today's real preset (portrait and landscape both resolve to
            // the same 256/300 numbers), but it is a real gap versus the UIKit path, not a
            // considered equivalence — flagged rather than silently narrowed.
            if let maxWidthPortrait = contentProperty.maxWidthPortrait {
                cardMaxWidth = maxWidthPortrait
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

        if let bannerMaxHeight = properties.bannerMaxHeight {
            self.bannerMaxHeight = bannerMaxHeight
        }

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
            if let titleFont = theme.titleFont {
                primaryButtonFont = Font(titleFont)
            }
        }

        // `PlainSecondaryStyle`'s real counterpart is `ActionStyle.plain` (a borderless text
        // button) — the same case `SwiftUIAlertModal`'s sentinel `Properties` already uses for
        // `secondaryActionStyle`. Any other case (or no style at all) keeps `standard`'s literal.
        if case let .plain(theme)? = properties.secondaryActionStyle,
           let titleFont = theme.titleFont {
            secondaryButtonFont = Font(titleFont)
        }
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
