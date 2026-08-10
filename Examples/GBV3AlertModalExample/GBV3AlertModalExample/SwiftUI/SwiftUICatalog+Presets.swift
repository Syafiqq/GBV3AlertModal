//
//  SwiftUICatalog+Presets.swift
//  GBV3AlertModalExample
//
//  `ModalStyle` → `GBAlertModal.Properties`, i.e. the preset table the renderer
//  is seeded with (`register(style:properties:)`).
//
//  Every entry here is built from `GalleryPresets` — the citation-backed mirror
//  of `Presentation.UiKit.V3AlertModal` — using the SAME `.copy(...)` overrides
//  the matching `DialogCatalog` entry applies inline. Nothing is re-typed by
//  hand and nothing is tuned: if a preset produces a wrong-looking card in the
//  SwiftUI gallery, the finding is that the SwiftUI render disagrees with UIKit
//  over identical `Properties` — which is exactly what the screen is for.
//
//  Where the UIKit entry applies its override at the CALL SITE (e.g.
//  `GalleryPresets.popupProperties.copy(bannerRatio: 295/256, …)`), the
//  descriptor path has no call-site `Properties`, so the same override becomes a
//  named style token. That is the documented trade in `ModalStyle`: a preset per
//  design variant, registered once, asked for by name.
//

import UIKit
import GBV3AlertModal

@MainActor
enum SwiftUICatalogPresets {

    /// The style→preset pairs registered on every catalog renderer. `.standard`
    /// (`GalleryPresets.properties`) and `.popup` (`GalleryPresets.popupProperties`)
    /// are already seeded by `SwiftUIModalRenderer.init`, so they are not repeated.
    static var stylePresets: [(ModalStyle, GBAlertModal.Properties)] {
        [
            (.geniePermissionAlert, GalleryPresets.permissionAlertProperties),
            (.genieObliqueRed, obliqueRed),
            (.genieErrorBanner, errorBanner),
            (.genieForceUpdateBanner, forceUpdateBanner),
            (.genieCapBanner, capBanner),
            (.genieQuizBanner, quizBanner),
            (.genieTrialBanner, trialBanner),
            (.genieAiNotesBanner, aiNotesBanner),
            (.genieCreditDeduction, creditDeduction),
            (.genieStreak, GalleryPresets.streakModalProperties),
            (.genieTimerBanner, timerBanner),
            (.genieExitWorksheetBanner, exitWorksheetBanner),
            (.genieRenameInput, renameInput),
            (.genieDatePickerInput, datePickerInput),
            (.genieBadgeUnlock, GalleryPresets.badgeProperties),
            (.genieBadgeMulti, badgeMulti),
            (.genieBadgeDetail, badgeDetail),
            (.variantCapsule, variantCapsule),
            (.variantCapsuleOutlined, variantCapsuleOutlined),
            (.variantPlain, variantPlain),
            (.variantOblique, variantOblique)
        ]
    }

    // MARK: - Variants (button styles)

    /// The four `ActionStyle` cases the Variants section demonstrates. Each is
    /// `GalleryPresets.properties` with ONLY `primaryActionStyle` changed, exactly as the
    /// UIKit twin spells it at its call site — so a difference on screen is the action style
    /// and nothing else.
    static var variantCapsule: GBAlertModal.Properties {
        GalleryPresets.properties.copy(primaryActionStyle: .capsule(GalleryPresets.capsuleTheme))
    }

    static var variantCapsuleOutlined: GBAlertModal.Properties {
        GalleryPresets.properties.copy(
            primaryActionStyle: .capsuleOutlined(GalleryPresets.capsuleOutlinedTheme)
        )
    }

    static var variantPlain: GBAlertModal.Properties {
        GalleryPresets.properties.copy(primaryActionStyle: .plain(GalleryPresets.plainTheme))
    }

    static var variantOblique: GBAlertModal.Properties {
        GalleryPresets.properties.copy(
            primaryActionStyle: .obliqueBottomLeft(GalleryPresets.obliqueBottomLeftTheme)
        )
    }

    // MARK: - Cross-cutting

    /// `oblique-red-leave-confirm` — the per-call-site red primary theme
    /// (`DialogCatalog+CrossCutting.obliqueRedLeaveConfirm`).
    static var obliqueRed: GBAlertModal.Properties {
        GalleryPresets.properties.copy(
            primaryActionStyle: .obliqueBottomLeft(GalleryPresets.obliqueBottomLeftRedTheme)
        )
    }

    /// `database-error-banner`.
    static var errorBanner: GBAlertModal.Properties {
        GalleryPresets.popupProperties.copy(
            bannerRatio: 295.0 / 256.0,
            bannerMaxHeight: 320,
            bannerFixedHeight: 256
        )
    }

    /// `force-update-banner`.
    static var forceUpdateBanner: GBAlertModal.Properties {
        GalleryPresets.popupProperties.copy(
            bannerRatio: 320.0 / 320.0,
            bannerMaxHeight: 320,
            bannerFixedHeight: 256
        )
    }

    // MARK: - Worksheet

    /// `worksheet-abused-cap-banner`.
    static var capBanner: GBAlertModal.Properties {
        GalleryPresets.popupProperties.copy(
            bannerRatio: 320.0 / 197.0,
            bannerMaxHeight: 216,
            bannerFixedHeight: 184
        )
    }

    /// `rename-worksheet` — the `renameWorksheet:` convenience preset.
    static var renameInput: GBAlertModal.Properties {
        GalleryPresets.properties.copy(
            padding: GalleryPresets.padding.copy(
                top: (20, 32),
                bottom: (16, 16)
            ),
            titleFont: GallerySHSans.heavy.font(24),
            space: GalleryPresets.space.copy(
                title: 16,
                subtitle: 32,
                interButton: 8
            )
        )
    }

    /// `date-picker-worksheet`.
    ///
    /// `contentProperty` MUST match the picker's own `.frame(maxWidth:)` cap in
    /// `SwiftUIModalRenderer+InputViews.swift` exactly — a row ceiling narrower than what the
    /// picker itself is capped to still overflows, just by a different amount, so these two
    /// numbers are one fix applied in two places, not two independent ones. 320 is still an
    /// UNVERIFIED guess pending on-device confirmation (see `UIKitFreeCatalogPresets
    /// .datePickerInput`, which carries the identical override for the same reason).
    static var datePickerInput: GBAlertModal.Properties {
        GalleryPresets.properties.copy(
            contentProperty: GalleryPresets.contentProperty.copy(
                fixedWidthPortrait: 320, maxWidthPortrait: 320,
                fixedWidthLandscape: 320, maxWidthLandscape: 320
            ),
            padding: GalleryPresets.padding.copy(
                top: (20, 32),
                left: (12, 40),
                bottom: (16, 16),
                right: (12, 40)
            ),
            titleFont: GallerySHSans.heavy.font(24),
            space: GalleryPresets.space.copy(
                title: 0,
                subtitle: 8,
                interButton: 8
            )
        )
    }

    // MARK: - GenieClass / Campaign

    /// `quiz-info-banner` and `quiz-begin-banner`.
    static var quizBanner: GBAlertModal.Properties {
        GalleryPresets.popupProperties.copy(
            bannerRatio: 320.0 / 229.0,
            bannerMaxHeight: 216,
            bannerFixedHeight: 184
        )
    }

    /// `onboarding-trial-banner` — same geometry as the quiz banners; kept as its
    /// own token because it is its own call site in the catalog.
    static var trialBanner: GBAlertModal.Properties {
        quizBanner
    }

    /// `ai-notes-ready-banner`.
    static var aiNotesBanner: GBAlertModal.Properties {
        GalleryPresets.popupProperties.copy(
            bannerRatio: 960.0 / 681.0,
            bannerMaxHeight: 320,
            bannerFixedHeight: 256
        )
    }

    /// `credit-deduction-popup` — popup preset with the heavy title.
    static var creditDeduction: GBAlertModal.Properties {
        GalleryPresets.popupProperties.copy(
            titleFont: GallerySHSans.heavy.font(24)
        )
    }

    // MARK: - Working space

    /// `worksheet-ready-timer-banner` / `worksheet-timeup-timer-banner`
    /// (`DialogCatalog+WorkingSpace.timerBannerProperties`).
    static var timerBanner: GBAlertModal.Properties {
        GalleryPresets.properties.copy(
            padding: UIMinMaxEdgeInsets(
                top: (32, 32),
                left: (32, 32),
                bottom: (32, 32),
                right: (32, 32)
            ),
            bannerRatio: 193.0 / 170.0,
            bannerMaxHeight: 170,
            bannerFixedHeight: 170,
            titleFont: GallerySHSans.bold.font(24),
            titleColor: GalleryColor.gbpNavy,
            subtitleFont: GallerySHSans.regular.font(16),
            subtitleColor: GalleryColor.labelSubtitle
        )
    }

    /// `exit-worksheet-confirm-banner`.
    static var exitWorksheetBanner: GBAlertModal.Properties {
        GalleryPresets.properties.copy(
            bannerRatio: 365.0 / 206.0,
            bannerMaxHeight: 144,
            bannerFixedHeight: 144
        )
    }

    // MARK: - Badges

    /// `badge-unlock-multi` — the badge preset with the taller banner cap.
    static var badgeMulti: GBAlertModal.Properties {
        GalleryPresets.badgeProperties.copy(
            bannerMaxHeight: 216,
            bannerFixedHeight: 216
        )
    }

    /// `badge-detail-popup` — its own padding and `ComponentSpace`.
    static var badgeDetail: GBAlertModal.Properties {
        GalleryPresets.properties.copy(
            padding: UIMinMaxEdgeInsets(
                top: (20, 36),
                left: (20, 48),
                bottom: (20, 36),
                right: (20, 48)
            ),
            space: GBAlertModal.Properties.ComponentSpace(
                banner: 0,
                title: 0,
                subtitle: 24,
                interButton: 0
            )
        )
    }
}
