//
//  GalleryPresets.swift
//  GBV3AlertModalExample
//
//  Mirrors `Presentation.UiKit.V3AlertModal+GBV3AlertModal` (and the
//  `badgeProperties`/`streakModalProperties`/permission-alert overrides
//  discovered at their call sites) from the distribution app, using only the
//  public `GBV3AlertModal` library API + `GalleryTokens`. Values confirmed
//  against `geniebook-student-ios-distribution/Common/Common/Custom/Components/AlertModal/V3AlertModal+GBV3AlertModal.swift`
//  and the `BadgesPopUpView.swift` / `StreakPopUpView.swift` / `GACameraCell.swift`
//  call sites (see docs/superpowers/specs/2026-07-21-dialog-catalog.md).
//

import SwiftUI
import UIKit
import GBV3AlertModal

@MainActor
enum GalleryPresets {
    // MARK: - Content Property

    /// Mirrors `Presentation.UiKit.V3AlertModal.contentProperty`.
    static let contentProperty = GBAlertModal.Properties.ContentProperty(
        backgroundColor: GalleryColor.white,
        cornerRadius: 16,
        fixedWidthPortrait: UIDevice.current.userInterfaceIdiom == .pad ? 300 : 256,
        maxWidthPortrait: UIDevice.current.userInterfaceIdiom == .pad ? 300 : 256,
        fixedWidthLandscape: UIDevice.current.userInterfaceIdiom == .pad ? 300 : 256,
        maxWidthLandscape: UIDevice.current.userInterfaceIdiom == .pad ? 300 : 256,
        childShouldMatchParent: true
    )

    /// Mirrors `Presentation.UiKit.V3AlertModal.margin` (`UIEdgeInsets(vertical: 40, horizontal: 20)`).
    static let margin = UIEdgeInsets(top: 40, left: 20, bottom: 40, right: 20)

    /// Mirrors `Presentation.UiKit.V3AlertModal.padding`.
    static let padding = UIMinMaxEdgeInsets(
        top: (16, 24),
        left: (16, 32),
        bottom: (16, 24),
        right: (16, 32)
    )

    /// Mirrors `Presentation.UiKit.V3AlertModal.space`.
    static let space = GBAlertModal.Properties.ComponentSpace(
        banner: 8,
        title: 8,
        subtitle: 16,
        interButton: 8
    )

    /// Mirrors `Colors.text_primary.withAlphaComponent(0.6)` used as `properties.overlayColor`.
    /// `text_primary` is not one of the 12 catalog `GalleryColor` tokens (it isn't a
    /// `UIColor.Genie.*` token); confirmed as `#626262` from
    /// `geniebook-student-ios-distribution/Common/Common/Constants/Colors.swift:17`.
    private static let overlayColor = UIColor(hex: 0x626262).withAlphaComponent(0.6)

    // MARK: - Action Themes

    /// Mirrors `Presentation.UiKit.V3AlertModal.capsuleTheme`.
    static let capsuleTheme = GBAlertModal.ActionStyle.CapsuleTheme(
        backgroundColor: GalleryColor.accentSecondary,
        backgroundDisableColor: GalleryColor.borderLight,
        titleColor: GalleryColor.white,
        titleDisableColor: GalleryColor.white,
        titleFont: GallerySHSans.heavy.font(16)
    )

    /// Mirrors `Presentation.UiKit.V3AlertModal.capsuleOutlineTheme`. Confirmed against
    /// `geniebook-student-ios-distribution/Common/Common/Custom/Components/AlertModal/V3AlertModal+GBV3AlertModal.swift`:
    /// clear background (both states), `labelSubtitle` border/title, `borderLight` disabled
    /// border/title, `borderWidth` 2, heavy 16pt title font.
    static let capsuleOutlinedTheme = GBAlertModal.ActionStyle.CapsuleOutlineTheme(
        backgroundColor: .clear,
        backgroundDisableColor: .clear,
        titleColor: GalleryColor.labelSubtitle,
        titleDisableColor: GalleryColor.borderLight,
        borderWidth: 2,
        borderColor: GalleryColor.labelSubtitle.cgColor,
        borderDisableColor: GalleryColor.borderLight.cgColor,
        titleFont: GallerySHSans.heavy.font(16)
    )

    /// Mirrors `Presentation.UiKit.V3AlertModal.plainTheme`.
    static let plainTheme = GBAlertModal.ActionStyle.PlainTheme(
        titleColor: GalleryColor.accentSecondaryDark,
        titleDisableColor: GalleryColor.borderLight,
        titleFont: GallerySHSans.heavy.font(16)
    )

    /// Mirrors `Presentation.UiKit.V3AlertModal.obliqueBottomLeftTheme` (default orange).
    static let obliqueBottomLeftTheme = GBAlertModal.ActionStyle.ObliqueBottomLeftTheme(
        unPressedColor: GalleryColor.accentSecondaryDark,
        pressedColor: GalleryColor.pressedBlue,
        disabledColor: GalleryColor.borderLight,
        shadowColor: GalleryColor.orangeMandarin.cgColor,
        titleColor: GalleryColor.white,
        titleDisableColor: GalleryColor.white,
        titleFont: GallerySHSans.heavy.font(16)
    )

    /// The "leave class" red oblique theme, used by `oblique-red-leave-confirm`.
    /// Mirrors the inline theme built in
    /// `V1OnlineLessonViewController.swift:1813` (`showLeavePopUp()`), also
    /// repeated in `V2LiveKitSmallClassViewController.swift` /
    /// `V2LiveKitOnlineLessonViewController.swift`. `disabledColor: .gray` and the
    /// omitted `titleFont` (defaults to `nil`) are copied verbatim from that
    /// call site — not guessed.
    static let obliqueBottomLeftRedTheme = GBAlertModal.ActionStyle.ObliqueBottomLeftTheme(
        unPressedColor: GalleryColor.pastelRed,
        pressedColor: GalleryColor.pastelRed,
        disabledColor: .gray,
        shadowColor: GalleryColor.englishVermillion.cgColor,
        titleColor: .white,
        titleDisableColor: .white
    )

    // MARK: - Properties

    /// Mirrors `Presentation.UiKit.V3AlertModal.properties` (the standard preset).
    static let properties = GBAlertModal.Properties(
        baseTint: GalleryColor.accentSecondary,
        overlayColor: overlayColor,
        contentProperty: contentProperty,
        margin: margin,
        padding: padding,
        bannerRatio: 1,
        bannerMaxHeight: nil,
        bannerFixedHeight: nil,
        titleFont: GallerySHSans.bold.font(24),
        // One catalog base preset. Preserve the former popup typography while removing its
        // separate padding and spacing configuration.
        titleColor: GalleryColor.gbpNavy,
        subtitleFont: GallerySHSans.regular.font(16),
        subtitleColor: GalleryColor.labelSubtitle,
        buttonActionShouldMatchParent: true,
        buttonActionOrientation: .vertical,
        primaryActionStyle: .obliqueBottomLeft(obliqueBottomLeftTheme),
        secondaryActionStyle: .plain(plainTheme),
        closeButtonTint: .black,
        space: space
    )

    /// Mirrors the `private static var badgeProperties` in
    /// `BadgesPopUpView.swift` (badge-unlock shapes). Catalog source uses
    /// `FontHelper.DMSans.*`, which resolves to the same OpenSans family as
    /// `SHSans` on the `en` locale (see catalog "Fonts" section).
    static let badgeProperties = properties.copy(
        padding: UIMinMaxEdgeInsets(
            top: (20, 40),
            left: (20, 48),
            bottom: (20, 32),
            right: (20, 48)
        ),
        bannerRatio: 1,
        bannerMaxHeight: 144,
        bannerFixedHeight: 144,
        titleFont: GallerySHSans.bold.font(24),
        titleColor: GalleryColor.gbpNavy,
        subtitleFont: GallerySHSans.regular.font(16),
        subtitleColor: GalleryColor.labelSubtitle,
        space: GBAlertModal.Properties.ComponentSpace(
            banner: 16,
            title: 12,
            subtitle: 24,
            interButton: 8
        )
    )

    /// Mirrors the `private static var streakModalProperties` in
    /// `StreakPopUpView.swift` (streak popup shapes). `bannerRatio` here is the
    /// base `200.0 / 168.0`; individual streak variants further `.copy` it to
    /// their own image aspect ratio (e.g. `358.0 / 400.0`).
    static let streakModalProperties = properties.copy(
        padding: UIMinMaxEdgeInsets(
            top: (20, 40),
            left: (20, 48),
            bottom: (20, 32),
            right: (20, 48)
        ),
        bannerRatio: 200.0 / 168.0,
        bannerMaxHeight: 168,
        bannerFixedHeight: 168,
        titleFont: GallerySHSans.bold.font(24),
        titleColor: GalleryColor.gbpNavy,
        subtitleFont: GallerySHSans.regular.font(16),
        subtitleColor: GalleryColor.labelSubtitle,
        space: GBAlertModal.Properties.ComponentSpace(
            banner: 16,
            title: 12,
            subtitle: 24,
            interButton: 8
        )
    )

    /// Mirrors the permission-alert override built inline at
    /// `GACameraCell.swift:178` (repeated in `AudioRecordManager.swift`,
    /// `GAChatPageViewController+ChatBox.swift`) — used by
    /// `permission-denied-settings`.
    static let permissionAlertProperties = properties.copy(
        padding: padding.copy(
            top: (20, 20),
            left: (30, 30),
            bottom: (12, 12),
            right: (30, 30)
        ),
        titleFont: GallerySHSans.bold.font(24),
        subtitleFont: GallerySHSans.regular.font(16),
        subtitleColor: GalleryColor.labelSubtitle,
        space: space.copy(
            title: 12,
            subtitle: 20,
            interButton: 8
        )
    )

    // MARK: - ModalProperties (SwiftUI vocabulary, for the UIKit-free renderer demos)
    //
    // A `GalleryColor`-mirrored port of `properties` above — same colours, same button-font weight
    // (heavy 16pt everywhere `properties` uses it), only the font FAMILY stays `.system` rather than
    // `GallerySHSans`/OpenSans (the declared, cross-cutting divergence every SwiftUI screen carries —
    // see `SwiftUIDivergence.global`'s "Fonts" note). Shared by EmbeddedCatalogScreen/
    // WindowCatalogScreen/EmbeddedAdoptionScreen, which compare shape-for-shape against the UIKit
    // Dialog Gallery, so a colour/weight that doesn't match `properties` reads as a rendering defect
    // rather than the "minimal, functional preset" it used to be documented as.

    static let standardModalProperties = ModalProperties(
        baseTint: Color(uiColor: GalleryColor.accentSecondary),
        overlayColor: Color(uiColor: overlayColor),
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
        padding: UIMinMaxEdgeInsets(top: (16, 24), left: (16, 32), bottom: (16, 24), right: (16, 32)),
        banner: ModalBannerConfiguration(),
        // Weight only — family stays `.system`, not `GallerySHSans`/OpenSans (declared, cross-cutting
        // divergence: `SwiftUIDivergence.global`'s "Fonts" note). Real preset is bold 24 / regular 16.
        titleFont: .system(size: 24, weight: .bold),
        // Match `properties`: standard geometry with the former popup title/subtitle typography.
        titleColor: Color(uiColor: GalleryColor.gbpNavy),
        subtitleFont: .system(size: 16),
        subtitleColor: Color(uiColor: GalleryColor.labelSubtitle),
        buttonActionShouldMatchParent: true,
        buttonActionOrientation: .vertical,
        primaryActionStyle: .obliqueBottomLeft(
            ModalProperties.ActionStyle.ObliqueBottomLeftTheme(
                unPressedColor: Color(uiColor: GalleryColor.accentSecondaryDark),
                pressedColor: Color(uiColor: GalleryColor.pressedBlue),
                disabledColor: Color(uiColor: GalleryColor.borderLight),
                shadowColor: Color(uiColor: GalleryColor.orangeMandarin),
                titleColor: .white,
                titleDisableColor: .white,
                // Was `.medium` — every real Genie button (primary AND secondary) is HEAVY 16pt
                // (`GallerySHSans.heavy.font(16)`); `.medium` is what made every standard-style shape
                // (all of `.standard`/`.popup`'s many callers, e.g. `standard-one-button`) look
                // conspicuously lighter than `variant-button-plain`, which already set `.heavy` itself.
                titleFont: .system(size: 16, weight: .heavy)
            )
        ),
        secondaryActionStyle: .plain(
            ModalProperties.ActionStyle.PlainTheme(
                // Was `.blue`/`.gray` — the real `plainTheme` secondary is ORANGE
                // (`GalleryColor.accentSecondaryDark`), never blue; `.blue` was a placeholder that
                // never got swapped for the real token already sitting in this file.
                titleColor: Color(uiColor: GalleryColor.accentSecondaryDark),
                titleDisableColor: Color(uiColor: GalleryColor.borderLight),
                titleFont: .system(size: 16, weight: .heavy)
            )
        ),
        closeButtonTint: .black,
        space: ModalProperties.ComponentSpace(banner: 8, title: 8, subtitle: 16, interButton: 8)
    )

    // MARK: - Data Holder

    /// Mirrors `Presentation.UiKit.V3AlertModal.holder` (the default holder).
    /// `primaryAction` uses the catalog's literal English string for the
    /// `action_okay` key ("Okay") — `Localizable.strings` copying is a
    /// separate task; this holder is a base `.copy()` target, not final content.
    static let holder = GBAlertModal.DataHolder(
        closeOnTapOverlay: true,
        banner: nil,
        title: nil,
        titleAttributed: nil,
        subtitle: nil,
        subtitleAttributed: nil,
        subtitleCustomView: nil,
        primaryAction: "Okay",
        secondaryAction: nil,
        showCloseButton: false,
        closeImage: nil,
        dismissOnAction: true,
        completion: nil
    )
}
