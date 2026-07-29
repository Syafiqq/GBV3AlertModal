import SwiftUI

/// Fixed design vocabulary for the SwiftUI alert modal (spec D8: `Properties` dissolves into
/// tokens + `ButtonStyle`s, not per-call fields). Structural values AND colours are transcribed
/// from the distribution app's real `Presentation.UiKit.V3AlertModal` preset + `UIColor.Genie.*` /
/// `Colors.*` (hex values inlined here since the example app doesn't link the design system). Fonts
/// use SwiftUI system fonts at the preset's real sizes/weights (`FontHelper.SHSans` not linked).
public enum ModalTokens {
    // Card geometry — cornerRadius 16. Width MAXIMIZES to fill (screen − 2·horizontal margin), capped
    // at cardMaxWidth. Phone: no cap → fills to the margin (real app maximizes). Pad: capped at 300.
    public static let cornerRadius: CGFloat = 16
    public static var cardMaxWidth: CGFloat { UIDevice.current.userInterfaceIdiom == .pad ? 300 : .infinity }

    // Oblique primary button — real preset: cornerRadius 8, fixed height 48, and a HARD solid-orange
    // offset to the lower-left (x:-3, y:3, blur 0) that the button slides into on press. That offset
    // IS the "oblique" look (not a soft drop shadow).
    public static let buttonCornerRadius: CGFloat = 8
    public static let buttonHeight: CGFloat = 48
    public static let obliqueOffset = CGSize(width: -3, height: 3)

    // Scrim — real preset overlayColor = text_primary @ 0.6 (a near-black dim).
    public static let scrimOpacity: Double = 0.6

    // Card→screen margin — real preset: UIEdgeInsets(vertical: 40, horizontal: 20).
    public static let cardMarginV: CGFloat = 40
    public static let cardMarginH: CGFloat = 20

    // Content padding inside the card — real preset UIMinMaxEdgeInsets top/bottom (16,24), left/right (16,32).
    // Horizontal inset is larger than vertical; using the max (design target) of each.
    public static let contentPaddingV: CGFloat = 24
    public static let contentPaddingH: CGFloat = 32

    // Banner — image keeps its natural aspect ratio (scaledToFit); cap the height so tall art can't dominate.
    public static let bannerMaxHeight: CGFloat = 160

    // Vertical gaps — owner override to a uniform 12 (real preset was 8/8/16); interButton stays 8.
    public static let gapBelowBanner: CGFloat = 12
    public static let gapBelowTitle: CGFloat = 12
    public static let gapBelowSubtitle: CGFloat = 12
    public static let interButton: CGFloat = 8

    // Typography — real preset: title SHSans.bold 24, subtitle SHSans.regular 16, buttons SHSans.heavy 16.
    public static let titleFont: Font = .system(size: 24, weight: .bold)
    public static let subtitleFont: Font = .system(size: 16, weight: .regular)
    public static let buttonFont: Font = .system(size: 16, weight: .heavy)

    public enum Palette {
        // Real Geniebook values, transcribed from UIColor.Genie.* / Colors.* in the distribution app.
        // NB: the primary button is ORANGE at rest and flips to BLUE when pressed — that hue-flip is
        // the real V3AlertModal oblique theme (unPressedColor accentSecondaryDark / pressedColor 0x038CD5),
        // not a prototype bug.
        public static let accent = Color(hex: 0xF7941E)            // accentSecondaryDark (oblique unpressed)
        public static let accentPressed = Color(hex: 0x038CD5)     // oblique pressedColor
        public static let disabled = Color(hex: 0xB4B4B4)          // borderLight
        public static let titleText = Color(hex: 0x262262)         // Genie.primary == GBPNavy
        public static let subtitleText = Color(hex: 0x333333)      // textPrimaryDark
        public static let onAccent = Color.white
        public static let shadow = Color(hex: 0xE57B41)            // orangeMandarin
        public static let cardBackground = Color.white
        public static let scrim = Color(hex: 0x626262)             // Colors.text_primary (dimmed @ scrimOpacity)
    }
}

extension Color {
    /// 0xRRGGBB literal → Color. Prototype convenience for transcribing the app's hex tokens.
    /// Public: exercised directly by the example test target (`SwiftUIAlertModalSmokeTests`),
    /// which lives in a different module and imports `GBV3AlertModal` without `@testable`.
    public init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
