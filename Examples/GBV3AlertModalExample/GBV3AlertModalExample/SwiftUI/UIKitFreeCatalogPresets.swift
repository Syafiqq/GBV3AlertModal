//
//  UIKitFreeCatalogPresets.swift
//  GBV3AlertModalExample
//
//  `ModalStyle` → `ModalProperties` for `EmbeddedCatalogScreen`/`WindowCatalogScreen` — the
//  `EmbeddedModalRenderer`/`WindowModalRenderer` twins of `SwiftUICatalog+Presets.swift`, registering
//  the SAME 17 style tokens (`.genieErrorBanner` and friends, declared once in `SwiftUICatalog.swift`)
//  so `SwiftUICatalog.dialogEntries` — built against those tokens — can be presented UNCHANGED on
//  either UIKit-free renderer. `stressPresets` below does the same for the 5 stress-matrix tokens
//  (`SwiftUICatalog+Stress.swift`), so `SwiftUICatalog.stressEntries` is presentable too.
//
//  STRUCTURAL geometry (padding, banner ratio/height, component spacing) is transcribed verbatim
//  from `SwiftUICatalog+Presets.swift`, because that is what `ModalTokens`/`ResolvedModal` actually
//  read. Fonts/colours follow `GalleryPresets.standardModalProperties`'s own precedent — a minimal,
//  functional preset, not a GallerySHSans/GalleryColor fidelity port: these two catalog screens exist
//  to answer "does the shape actually render", the same bar `EmbeddedShapeCoverageTests`/
//  `WindowShapeCoverageTests` already gate structurally; looking at them is the added, non-automatable
//  half of that same claim.
//

import SwiftUI
import GBV3AlertModal

@MainActor
enum UIKitFreeCatalogPresets {

    /// The 17 style→preset pairs `SwiftUICatalog.dialogEntries` asks for by name (`.standard`/
    /// `.popup` are already seeded by both renderers' `init`). Deliberately excludes the 4 `variant*`
    /// tokens (`SwiftUICatalog+Variants.swift`) — those back the stress/variants section, out of
    /// scope for a screen whose job is the 26 real shapes.
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

    /// The 5 stress-matrix style→preset pairs `SwiftUICatalog.stressEntries` asks for by name
    /// (`.standard`'s no-banner vertical shapes need no token of their own, same as the UIKit/SwiftUI
    /// twins). Transcribed from `StressCatalog.properties(banner:orientation:)`, the ONE function both
    /// other galleries already read from — see that function's own doc for why it stays UIKit-typed.
    static var stressPresets: [(ModalStyle, ModalProperties)] {
        [
            (.stressHorizontal, stressProperties(banner: .none, orientation: .horizontal)),
            (.stressWideBanner, stressProperties(banner: .wide, orientation: .vertical)),
            (.stressWideBannerHorizontal, stressProperties(banner: .wide, orientation: .horizontal)),
            (.stressTallBanner, stressProperties(banner: .tall, orientation: .vertical)),
            (.stressTallBannerHorizontal, stressProperties(banner: .tall, orientation: .horizontal))
        ]
    }

    private static func stressProperties(banner: StressCatalog.BannerKind, orientation: Axis) -> ModalProperties {
        var properties = GalleryPresets.standardModalProperties
        if orientation == .horizontal {
            properties.buttonActionOrientation = .horizontal
        }
        if let ratio = banner.ratio {
            properties.bannerRatio = ratio
        }
        return properties
    }

    private static func popupBanner(ratio: CGFloat, maxHeight: CGFloat) -> ModalProperties {
        var properties = GalleryPresets.popupModalProperties
        properties.bannerRatio = ratio
        properties.bannerMaxHeight = maxHeight
        return properties
    }

    static var permissionAlert: ModalProperties {
        var properties = GalleryPresets.standardModalProperties
        properties.padding = UIMinMaxEdgeInsets(top: (20, 20), left: (30, 30), bottom: (12, 12), right: (30, 30))
        properties.space = ModalProperties.ComponentSpace(banner: 8, title: 12, subtitle: 20, interButton: 8)
        return properties
    }

    static var obliqueRed: ModalProperties {
        var properties = GalleryPresets.standardModalProperties
        properties.primaryActionStyle = .obliqueBottomLeft(
            ModalProperties.ActionStyle.ObliqueBottomLeftTheme(
                unPressedColor: .red, pressedColor: .red, disabledColor: .gray,
                // Matches UIKit's real "leave class" theme (`GalleryPresets.obliqueBottomLeftRedTheme.shadowColor`
                // = `GalleryColor.englishVermillion`) rather than `.red` again — same-as-fill flattens
                // the oblique offset layer into the surface.
                shadowColor: Color(uiColor: GalleryColor.englishVermillion),
                titleColor: .white, titleDisableColor: .white
            )
        )
        return properties
    }

    static var errorBanner: ModalProperties { popupBanner(ratio: 295.0 / 256.0, maxHeight: 320) }
    static var forceUpdateBanner: ModalProperties { popupBanner(ratio: 320.0 / 320.0, maxHeight: 320) }
    static var capBanner: ModalProperties { popupBanner(ratio: 320.0 / 197.0, maxHeight: 216) }
    static var quizBanner: ModalProperties { popupBanner(ratio: 320.0 / 229.0, maxHeight: 216) }
    static var aiNotesBanner: ModalProperties { popupBanner(ratio: 960.0 / 681.0, maxHeight: 320) }

    static var creditDeduction: ModalProperties {
        var properties = GalleryPresets.popupModalProperties
        properties.titleFont = .system(size: 24, weight: .heavy)
        return properties
    }

    static var streak: ModalProperties {
        var properties = GalleryPresets.standardModalProperties
        properties.padding = UIMinMaxEdgeInsets(top: (20, 40), left: (20, 48), bottom: (20, 32), right: (20, 48))
        properties.bannerRatio = 200.0 / 168.0
        properties.bannerMaxHeight = 168
        properties.space = ModalProperties.ComponentSpace(banner: 16, title: 12, subtitle: 24, interButton: 8)
        return properties
    }

    static var timerBanner: ModalProperties {
        var properties = GalleryPresets.standardModalProperties
        properties.padding = UIMinMaxEdgeInsets(top: (32, 32), left: (32, 32), bottom: (32, 32), right: (32, 32))
        properties.bannerRatio = 193.0 / 170.0
        properties.bannerMaxHeight = 170
        return properties
    }

    static var exitWorksheetBanner: ModalProperties {
        var properties = GalleryPresets.standardModalProperties
        properties.bannerRatio = 365.0 / 206.0
        properties.bannerMaxHeight = 144
        return properties
    }

    static var renameInput: ModalProperties {
        var properties = GalleryPresets.standardModalProperties
        properties.padding = UIMinMaxEdgeInsets(top: (20, 32), left: (16, 32), bottom: (16, 16), right: (16, 32))
        properties.titleFont = .system(size: 24, weight: .heavy)
        properties.space = ModalProperties.ComponentSpace(banner: 8, title: 16, subtitle: 32, interButton: 8)
        return properties
    }

    static var datePickerInput: ModalProperties {
        var properties = GalleryPresets.standardModalProperties
        properties.padding = UIMinMaxEdgeInsets(top: (20, 32), left: (12, 40), bottom: (16, 16), right: (12, 40))
        properties.titleFont = .system(size: 24, weight: .heavy)
        properties.space = ModalProperties.ComponentSpace(banner: 8, title: 0, subtitle: 8, interButton: 8)
        return properties
    }

    static var badgeUnlock: ModalProperties {
        var properties = GalleryPresets.standardModalProperties
        properties.padding = UIMinMaxEdgeInsets(top: (20, 40), left: (20, 48), bottom: (20, 32), right: (20, 48))
        properties.bannerRatio = 1
        properties.bannerMaxHeight = 144
        properties.space = ModalProperties.ComponentSpace(banner: 16, title: 12, subtitle: 24, interButton: 8)
        return properties
    }

    static var badgeMulti: ModalProperties {
        var properties = badgeUnlock
        properties.bannerMaxHeight = 216
        return properties
    }

    static var badgeDetail: ModalProperties {
        var properties = GalleryPresets.standardModalProperties
        properties.padding = UIMinMaxEdgeInsets(top: (20, 36), left: (20, 48), bottom: (20, 36), right: (20, 48))
        properties.space = ModalProperties.ComponentSpace(banner: 0, title: 0, subtitle: 24, interButton: 0)
        return properties
    }
}
