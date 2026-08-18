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

    /// The 17 style→preset pairs `SwiftUICatalog.dialogEntries` asks for by name (`.standard`/
    /// `.standard` is already seeded by both renderers' `init`). The 4 `variant*` tokens
    /// (`SwiftUICatalog+Variants.swift`) are a separate table, `variantPresets` below.
    static var stylePresets: [(ModalStyle, ModalProperties)] {
        [
            (.geniePermissionAlert, permissionAlert),
            (.genieObliqueRed, obliqueRed),
            (.genieErrorBanner, errorBanner),
            (.genieForceUpdateBanner, forceUpdateBanner),
            (.genieCapBanner, capBanner),
            (.genieQuizBanner, quizBanner),
            (.genieTrialBanner, quizBanner),
            (.genieAiNotesBanner, aiNotesBanner),
            (.genieCreditDeduction, creditDeduction),
            (.genieStreak, streak),
            (.genieTimerBanner, timerBanner),
            (.genieExitWorksheetBanner, exitWorksheetBanner),
            (.genieRenameInput, renameInput),
            (.genieDatePickerInput, datePickerInput),
            (.genieBadgeUnlock, badgeUnlock),
            (.genieBadgeMulti, badgeMulti),
            (.genieBadgeDetail, badgeDetail)
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

    /// The 5 stress-matrix style→preset pairs `SwiftUICatalog.stressEntries` asks for by name
    /// (`.standard`'s no-banner vertical shapes need no token of their own, same as the UIKit/SwiftUI
    /// twins). These derive directly from the SwiftUI-owned base instead of reading the UIKit
    /// stress catalog.
    static var stressPresets: [(ModalStyle, ModalProperties)] {
        [
            (.stressHorizontal, stressProperties(hasBanner: false, orientation: .horizontal)),
            (.stressWideBanner, stressProperties(hasBanner: true, orientation: .vertical)),
            (.stressWideBannerHorizontal, stressProperties(hasBanner: true, orientation: .horizontal)),
            (.stressTallBanner, stressProperties(hasBanner: true, orientation: .vertical)),
            (.stressTallBannerHorizontal, stressProperties(hasBanner: true, orientation: .horizontal))
        ]
    }

    private static func stressProperties(hasBanner: Bool, orientation: Axis) -> ModalProperties {
        var properties = standard
        if orientation == .horizontal {
            properties.buttonActionOrientation = .horizontal
        }
        if hasBanner {
            properties.banner = ModalBannerConfiguration()
        }
        return properties
    }

    private static func popupBanner(maximumHeight: CGFloat) -> ModalProperties {
        var properties = standard
        properties.banner = ModalBannerConfiguration(maximumHeight: maximumHeight)
        return properties
    }

    static var permissionAlert: ModalProperties {
        var properties = standard
        properties.padding = MinMaxEdgeInsets(top: (20, 20), left: (30, 30), bottom: (12, 12), right: (30, 30))
        properties.space = ModalProperties.ComponentSpace(banner: 8, title: 12, subtitle: 20, interButton: 8)
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

    static var errorBanner: ModalProperties { popupBanner(maximumHeight: 320) }
    static var forceUpdateBanner: ModalProperties { popupBanner(maximumHeight: 320) }
    static var capBanner: ModalProperties { popupBanner(maximumHeight: 216) }
    static var quizBanner: ModalProperties { popupBanner(maximumHeight: 216) }
    static var aiNotesBanner: ModalProperties { popupBanner(maximumHeight: 320) }

    static var creditDeduction: ModalProperties {
        var properties = standard
        properties.titleFont = .system(size: 24, weight: .heavy)
        return properties
    }

    static var streak: ModalProperties {
        var properties = standard
        properties.padding = MinMaxEdgeInsets(top: (20, 40), left: (20, 48), bottom: (20, 32), right: (20, 48))
        properties.banner = ModalBannerConfiguration(maximumHeight: 168)
        properties.space = ModalProperties.ComponentSpace(banner: 16, title: 12, subtitle: 24, interButton: 8)
        return properties
    }

    static var timerBanner: ModalProperties {
        var properties = standard
        properties.padding = MinMaxEdgeInsets(top: (32, 32), left: (32, 32), bottom: (32, 32), right: (32, 32))
        properties.banner = ModalBannerConfiguration(maximumHeight: 170)
        return properties
    }

    static var exitWorksheetBanner: ModalProperties {
        var properties = standard
        properties.banner = ModalBannerConfiguration(maximumHeight: 144)
        return properties
    }

    static var renameInput: ModalProperties {
        var properties = standard
        properties.padding = MinMaxEdgeInsets(top: (20, 32), left: (16, 32), bottom: (16, 16), right: (16, 32))
        properties.titleFont = .system(size: 24, weight: .heavy)
        properties.space = ModalProperties.ComponentSpace(banner: 8, title: 16, subtitle: 32, interButton: 8)
        return properties
    }

    static var datePickerInput: ModalProperties {
        var properties = standard
        // `contentProperty` deliberately NOT overridden: widening it was tried (matched to the
        // picker's own frame cap) and had no observable effect either way — the picker does not
        // read this number in any direction (see `DatePickerModalView`'s doc). Left at `standard`'s
        // real 256pt production column rather than kept at an unmotivated 320 that never did
        // anything.
        properties.padding = MinMaxEdgeInsets(top: (20, 32), left: (12, 40), bottom: (16, 16), right: (12, 40))
        properties.titleFont = .system(size: 24, weight: .heavy)
        properties.space = ModalProperties.ComponentSpace(banner: 8, title: 0, subtitle: 8, interButton: 8)
        return properties
    }

    static var badgeUnlock: ModalProperties {
        var properties = standard
        properties.padding = MinMaxEdgeInsets(top: (20, 40), left: (20, 48), bottom: (20, 32), right: (20, 48))
        properties.banner = ModalBannerConfiguration(maximumHeight: 144)
        properties.space = ModalProperties.ComponentSpace(banner: 16, title: 12, subtitle: 24, interButton: 8)
        return properties
    }

    static var badgeMulti: ModalProperties {
        var properties = badgeUnlock
        properties.banner = ModalBannerConfiguration(maximumHeight: 216)
        return properties
    }

    static var badgeDetail: ModalProperties {
        var properties = standard
        properties.padding = MinMaxEdgeInsets(top: (20, 36), left: (20, 48), bottom: (20, 36), right: (20, 48))
        properties.space = ModalProperties.ComponentSpace(banner: 0, title: 0, subtitle: 24, interButton: 0)
        return properties
    }

    static var divergencePresets: [(ModalStyle, ModalProperties)] {
        [
            (.divergenceTallUncapped, divergenceTallUncapped),
            (.divergenceBannerWide, popupBanner(maximumHeight: 256)),
            (.divergenceNilPrimaryStyle, divergenceNilPrimaryStyle)
        ]
    }

    private static var divergenceTallUncapped: ModalProperties {
        var properties = standard
        properties.banner = ModalBannerConfiguration(maximumHeight: nil)
        return properties
    }

    private static var divergenceNilPrimaryStyle: ModalProperties {
        var properties = standard
        properties.primaryActionStyle = nil
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
