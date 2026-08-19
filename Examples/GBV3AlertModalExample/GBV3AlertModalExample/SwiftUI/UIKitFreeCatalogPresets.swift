//
//  UIKitFreeCatalogPresets.swift
//  GBV3AlertModalExample
//
//  SwiftUI-native `ModalStyle` → `ModalProperties` presets for the 70-entry comparison catalog.
//  The renderer registers these tables once and every example selects the appropriate style token.
//
//  Structural geometry, fonts, and colours are expressed entirely with the package's SwiftUI-native
//  configuration types.
//

import SwiftUI
import GBV3AlertModalCore
import GBV3AlertModalSwiftUI

@MainActor
enum SwiftUICatalogPresets {

    /// Canonical SwiftUI configuration. UIKit has an equivalent preset with the same field names,
    /// but this value owns its colours, fonts, geometry, and button themes independently.
    static let standard = ModalProperties(
        baseTint: color(0xF7A440),
        overlayColor: color(0x626262).opacity(0.6),
        contentProperty: ModalProperties.ContentProperty(
            backgroundColor: .white,
            cornerRadius: 16,
            fixedWidthPortrait: 256,
            maxWidthPortrait: 256,
            fixedWidthLandscape: 256,
            maxWidthLandscape: 256,
            childShouldMatchParent: true
        ),
        margin: EdgeInsets(top: 40, leading: 20, bottom: 40, trailing: 20),
        padding: MinMaxEdgeInsets(
            top: (16, 24),
            left: (16, 32),
            bottom: (16, 24),
            right: (16, 32)
        ),
        banner: ModalBannerConfiguration(),
        titleFont: .system(size: 24, weight: .bold),
        titleColor: color(0x262262),
        subtitleFont: .system(size: 16),
        subtitleColor: color(0x515151),
        buttonActionShouldMatchParent: true,
        buttonActionOrientation: .vertical,
        primaryActionStyle: .obliqueBottomLeft(
            ModalProperties.ActionStyle.ObliqueBottomLeftTheme(
                unPressedColor: color(0xF7941E),
                pressedColor: color(0x038CD5),
                disabledColor: color(0xB4B4B4),
                shadowColor: color(0xE57B41),
                titleColor: .white,
                titleDisableColor: .white,
                titleFont: .system(size: 16, weight: .heavy)
            )
        ),
        secondaryActionStyle: .plain(
            ModalProperties.ActionStyle.PlainTheme(
                titleColor: color(0xF7941E),
                titleDisableColor: color(0xB4B4B4),
                titleFont: .system(size: 16, weight: .heavy)
            )
        ),
        closeButtonTint: .black,
        space: ModalProperties.ComponentSpace(banner: 8, title: 8, subtitle: 16, interButton: 8)
    )

    /// The remaining dialog-specific style→preset pairs. `.standard` is already seeded by the
    /// renderer's initializer; button variants live in `variantPresets` below.
    static var stylePresets: [(ModalStyle, ModalProperties)] {
        [
            (.genieObliqueRed, obliqueRed)
        ]
    }

    /// The 4 button-style variant style→preset pairs `SwiftUICatalog.variantButtonStyleEntries` asks
    /// for by name. Each derives from the SwiftUI-owned `standard` value and changes only the
    /// action style under test.
    static var variantPresets: [(ModalStyle, ModalProperties)] {
        [
            (.variantCapsule, variantCapsule),
            (.variantCapsuleOutlined, variantCapsuleOutlined),
            (.variantPlain, variantPlain),
            (.variantOblique, variantOblique)
        ]
    }

    static var variantCapsule: ModalProperties {
        var properties = standard
        properties.primaryActionStyle = .capsule(
            ModalProperties.ActionStyle.CapsuleTheme(
                backgroundColor: color(0xF7A440),
                backgroundDisableColor: color(0xB4B4B4),
                titleColor: .white,
                titleDisableColor: .white,
                titleFont: .system(size: 16, weight: .heavy)
            )
        )
        return properties
    }

    static var variantCapsuleOutlined: ModalProperties {
        var properties = standard
        properties.primaryActionStyle = .capsuleOutlined(
            ModalProperties.ActionStyle.CapsuleOutlineTheme(
                backgroundColor: .clear,
                backgroundDisableColor: .clear,
                titleColor: color(0x515151),
                titleDisableColor: color(0xB4B4B4),
                borderWidth: 2,
                borderColor: color(0x515151),
                borderDisableColor: color(0xB4B4B4),
                titleFont: .system(size: 16, weight: .heavy)
            )
        )
        return properties
    }

    static var variantPlain: ModalProperties {
        var properties = standard
        properties.primaryActionStyle = .plain(
            ModalProperties.ActionStyle.PlainTheme(
                titleColor: color(0xF7941E),
                titleDisableColor: color(0xB4B4B4),
                titleFont: .system(size: 16, weight: .heavy)
            )
        )
        return properties
    }

    /// Same oblique theme `.standard` already carries — the UIKit twin (`SwiftUICatalogPresets
    /// .variantOblique`) re-declares its own style token for this exact theme too, so this stays
    /// a plain passthrough rather than transcribing the theme a second time.
    static var variantOblique: ModalProperties { standard }

    /// Only horizontal stress entries need a non-standard preset.
    static var stressPresets: [(ModalStyle, ModalProperties)] {
        [
            (.stressHorizontal, horizontalStressProperties),
            (.stressWideBannerHorizontal, horizontalStressProperties),
            (.stressTallBannerHorizontal, horizontalStressProperties)
        ]
    }

    private static var horizontalStressProperties: ModalProperties {
        var properties = standard
        properties.buttonActionOrientation = .horizontal
        return properties
    }

    static var obliqueRed: ModalProperties {
        var properties = standard
        properties.primaryActionStyle = .obliqueBottomLeft(
            ModalProperties.ActionStyle.ObliqueBottomLeftTheme(
                unPressedColor: .red, pressedColor: .red, disabledColor: .gray,
                // The darker shadow keeps the oblique offset visually distinct from the red fill.
                shadowColor: color(0xC54A47),
                titleColor: .white, titleDisableColor: .white
            )
        )
        return properties
    }

    private static func color(_ hex: Int) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
