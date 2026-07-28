import SwiftUI

/// Fixed design vocabulary for the SwiftUI alert modal (spec D8: `Properties` dissolves into
/// tokens + `ButtonStyle`s, not per-call fields). Structural values are transcribed from the
/// distribution app's real `Presentation.UiKit.V3AlertModal` preset; colours/fonts are best-effort
/// approximations of the Geniebook design system (`UIColor.Genie.*` / `FontHelper.SHSans.*`), which
/// the example app does not link — swap for the real tokens if these views graduate into the library.
enum ModalTokens {
    // Card geometry — real preset (ContentProperty): cornerRadius 16, fixedWidth 300 pad / 256 phone.
    static let cornerRadius: CGFloat = 16
    static var cardWidth: CGFloat { UIDevice.current.userInterfaceIdiom == .pad ? 300 : 256 }

    // Scrim — real preset overlayColor = text_primary @ 0.6 (a near-black dim).
    static let scrimOpacity: Double = 0.6

    // Inner padding — real standard preset padding ≈ 24; content inset from the card edge.
    static let contentPadding: CGFloat = 24

    // Banner — real preset bannerRatio 1 (square); cap the height so tall art can't dominate.
    static let bannerAspectRatio: CGFloat = 1
    static let bannerMaxHeight: CGFloat = 160

    // Vertical gaps — real preset ComponentSpace: banner 16, title 16, subtitle 24, interButton 8.
    static let gapBelowBanner: CGFloat = 16
    static let gapBelowTitle: CGFloat = 16
    static let gapBelowSubtitle: CGFloat = 24
    static let interButton: CGFloat = 8

    // Typography — real preset: title SHSans.bold 24, subtitle SHSans.regular 16, buttons SHSans.heavy 16.
    static let titleFont: Font = .system(size: 24, weight: .bold)
    static let subtitleFont: Font = .system(size: 16, weight: .regular)
    static let buttonFont: Font = .system(size: 16, weight: .heavy)

    enum Palette {
        // Genie blue family (real pressed = 0x038CD5; unpressed accentSecondaryDark approximated darker).
        static let accent = Color(hex: 0x038CD5)
        static let accentPressed = Color(hex: 0x0272AB)
        static let disabled = Color(hex: 0xC9D2DD)          // ≈ borderLight
        static let titleText = Color(hex: 0x14284B)         // ≈ Genie.primary navy
        static let subtitleText = Color(hex: 0x5B6474)      // ≈ textPrimaryDark
        static let onAccent = Color.white
        static let shadow = Color(hex: 0xF5A623)            // ≈ orangeMandarin
        static let cardBackground = Color.white
        static let scrim = Color.black
    }
}

extension Color {
    /// 0xRRGGBB literal → Color. Prototype convenience for transcribing the app's hex tokens.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
