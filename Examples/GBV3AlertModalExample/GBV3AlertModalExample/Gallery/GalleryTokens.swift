//
//  GalleryTokens.swift
//  GBV3AlertModalExample
//
//  Design tokens (colors + fonts) replicated verbatim from the Dialog Gallery
//  catalog (docs/superpowers/specs/2026-07-21-dialog-catalog.md — "Design
//  tokens used"). This mirrors `UIColor.Genie` / `FontHelper.SHSans` from the
//  distribution app without pulling in any distribution-only code.
//

import UIKit

// MARK: - UIColor(hex:)

extension UIColor {
    /// Convenience initializer accepting either a bare `RRGGBB` Int (e.g. `0xF7A440`)
    /// or a `"#RRGGBB"` / `"RRGGBB"` string.
    convenience init(hex: Int, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    convenience init(hex string: String, alpha: CGFloat = 1) {
        var hexString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }
        let value = Int(hexString, radix: 16) ?? 0
        self.init(hex: value, alpha: alpha)
    }
}

// MARK: - GalleryColor

/// The 12 exact catalog colors (`UIColor.Genie.*` / `Colors.*` equivalents).
@MainActor
enum GalleryColor {
    /// `UIColor.Genie.accentSecondary` — `properties.baseTint`
    static let accentSecondary = UIColor(hex: 0xF7A440)

    /// `UIColor.Genie.primary` (= `GBPNavy`) — `properties.titleColor` (default)
    static let primary = UIColor(hex: 0x262262)

    /// `UIColor.Genie.GBPNavy` — same value as `primary`, kept as its own accessor
    /// to mirror the catalog's separate token name.
    static let gbpNavy = UIColor(hex: 0x262262)

    /// `UIColor.Genie.textPrimaryDark` — `properties.subtitleColor` (default)
    static let textPrimaryDark = UIColor(hex: 0x333333)

    /// `UIColor.Genie.labelSubtitle` — popup/badge/streak subtitleColor; permission-alert override
    static let labelSubtitle = UIColor(hex: 0x515151)

    /// `UIColor.Genie.accentSecondaryDark` — `plainTheme.titleColor`, `obliqueBottomLeftTheme.unPressedColor`
    static let accentSecondaryDark = UIColor(hex: 0xF7941E)

    /// `UIColor(netHex: 0x038CD5)` — `obliqueBottomLeftTheme.pressedColor` (default)
    static let pressedBlue = UIColor(hex: 0x038CD5)

    /// `UIColor.Genie.borderLight` — `obliqueBottomLeftTheme.disabledColor`, disabled states
    static let borderLight = UIColor(hex: 0xB4B4B4)

    /// `UIColor.Genie.orangeMandarin` — `obliqueBottomLeftTheme.shadowColor` (default)
    static let orangeMandarin = UIColor(hex: 0xE57B41)

    /// `UIColor.Genie.pastelRed` — "leave class" red oblique button (unPressed/pressed)
    static let pastelRed = UIColor(hex: 0xF56468)

    /// `UIColor.Genie.englishVermillion` — "leave class" red oblique button (shadow)
    static let englishVermillion = UIColor(hex: 0xC54A47)

    /// `Colors.geniebook_blue_sky` — `switchDeviceRecommendation` titleAttributed color
    static let blueSky = UIColor(hex: 0x63C1E9)

    /// `.white` — `contentProperty.backgroundColor`, button title colors
    static let white = UIColor.white
}

// MARK: - GallerySHSans

/// Weight accessor mapping to the bundled OpenSans PostScript names
/// (registered via `Info.plist` `UIAppFonts`), mirroring `FontHelper.SHSans`.
@MainActor
enum GallerySHSans {
    case regular
    case medium
    case semiBold
    case bold
    case heavy

    /// The exact PostScript name of the bundled OpenSans font file for this weight.
    var postScriptName: String {
        switch self {
        case .regular:
            return "OpenSans-Regular"
        case .medium:
            return "OpenSans-Medium"
        case .semiBold:
            return "OpenSans-SemiBold"
        case .bold:
            return "OpenSans-Bold"
        case .heavy:
            return "OpenSans-ExtraBold"
        }
    }

    /// Resolves the bundled OpenSans font at `size`, falling back to the system
    /// font of matching weight if the bundled font could not be found/registered.
    func font(_ size: CGFloat) -> UIFont {
        if let font = UIFont(name: postScriptName, size: size) {
            return font
        }
        // Fallback: should not happen once Info.plist UIAppFonts registration succeeds.
        switch self {
        case .regular:
            return .systemFont(ofSize: size, weight: .regular)
        case .medium:
            return .systemFont(ofSize: size, weight: .medium)
        case .semiBold:
            return .systemFont(ofSize: size, weight: .semibold)
        case .bold:
            return .systemFont(ofSize: size, weight: .bold)
        case .heavy:
            return .systemFont(ofSize: size, weight: .heavy)
        }
    }
}
