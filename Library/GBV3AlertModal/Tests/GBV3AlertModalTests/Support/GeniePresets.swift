import SwiftUI
import UIKit
@testable import GBV3AlertModal

/// Test-only re-creation of the Genie consumer app's `Presentation.UiKit.V3AlertModal`
/// preset (see `Examples/GBV3AlertModalExample/.../ViewController.swift` for the shape this
/// was copied from). Structural values (widths, insets, spacing, flags) are copied verbatim.
/// Fonts/colors are approximated with system equivalents since the exact Genie design tokens
/// (FontHelper, UIColor.Custom, Colors) live in the consumer app, not this repo.
// @MainActor: several builders here construct real UIKit views (`UIView`, `UITextView`,
// `UIDatePicker`) and drive their layout directly (`renameWorksheet()`, `datePickerWorksheet()`),
// which are @MainActor-isolated APIs under the Swift 6 UIKit annotations — so the whole enum is
// pinned to the main actor rather than isolating just those two functions.
@MainActor
enum GeniePresets {
    // MARK: - Properties

    static func standardProperties() -> GBAlertModal.Properties {
        GBAlertModal.Properties(
            baseTint: .systemBlue,
            overlayColor: UIColor.black.withAlphaComponent(0.6),
            contentProperty: contentProperty,
            margin: margin,
            padding: padding,
            bannerRatio: 1,
            bannerMaxHeight: nil,
            bannerFixedHeight: nil,
            titleFont: .boldSystemFont(ofSize: 24),
            titleColor: .label,
            subtitleFont: .systemFont(ofSize: 16),
            subtitleColor: .secondaryLabel,
            buttonActionShouldMatchParent: true,
            buttonActionOrientation: .vertical,
            primaryActionStyle: .obliqueBottomLeft(obliqueBottomLeftTheme),
            secondaryActionStyle: .plain(plainTheme),
            closeButtonTint: .black,
            space: space
        )
    }

    /// Same shape as `standardProperties()` but with `bannerRatio: nil` — exercises the
    /// natural-image-aspect banner path (`GBAlertModal+ViewGraph.swift`'s `installConstraints`).
    /// Built directly (not via `.copy()`): `Properties.copy()` falls back to the original value
    /// when `nil` is passed, so it cannot be used to *unset* `bannerRatio` from `standardProperties()`'s `1`.
    ///
    /// `bannerMaxHeight` defaults to `nil` (pure natural aspect, unbounded) but callers under a
    /// tight landscape card height (this fixture's landscape budget is ~182pt of content height)
    /// should pass a cap — see `BannerAspectStressTests`, which found a tall (9:16) or even
    /// square banner left uncapped fights the title/subtitle for space under strict Auto Layout
    /// priority tiers and squeezes them to near-zero height; capping the banner keeps the rest
    /// of the content at its full natural size and lets `scaleAspectFit` letterbox the banner.
    static func standardPropertiesNilBannerRatio(bannerMaxHeight: CGFloat? = nil) -> GBAlertModal.Properties {
        GBAlertModal.Properties(
            baseTint: .systemBlue,
            overlayColor: UIColor.black.withAlphaComponent(0.6),
            contentProperty: contentProperty,
            margin: margin,
            padding: padding,
            bannerRatio: nil,
            bannerMaxHeight: bannerMaxHeight,
            bannerFixedHeight: nil,
            titleFont: .boldSystemFont(ofSize: 24),
            titleColor: .label,
            subtitleFont: .systemFont(ofSize: 16),
            subtitleColor: .secondaryLabel,
            buttonActionShouldMatchParent: true,
            buttonActionOrientation: .vertical,
            primaryActionStyle: .obliqueBottomLeft(obliqueBottomLeftTheme),
            secondaryActionStyle: .plain(plainTheme),
            closeButtonTint: .black,
            space: space
        )
    }

    static func popupProperties() -> GBAlertModal.Properties {
        standardProperties().copy(
            padding: UIMinMaxEdgeInsets(
                top: (20, 32),
                left: (20, 32),
                bottom: (20, 32),
                right: (20, 32)
            ),
            titleFont: .boldSystemFont(ofSize: 24),
            space: GBAlertModal.Properties.ComponentSpace(
                banner: 16,
                title: 16,
                subtitle: 24,
                interButton: 8
            )
        )
    }

    // MARK: - ModalProperties (SwiftUI vocabulary, field-for-field transcriptions of the above)
    //
    // Same relationship `ModalPropertiesEquivalenceTests` proves for one preset ad hoc — these are
    // the reusable fixtures, seeding `RendererHarness.init(.embedded)`. Values transcribed directly
    // (not derived from the `GBAlertModal.Properties` helpers above, which are UIKit-typed) so a
    // reader can compare the two field-for-field; `bannerFixedHeight` has no SwiftUI counterpart
    // (§3a — measured inert on UIKit's own path) and is simply absent here, same as everywhere else
    // `ModalProperties` is built.

    static func standardModalProperties() -> ModalProperties {
        ModalProperties(
            baseTint: Color(uiColor: .systemBlue),
            overlayColor: Color(uiColor: UIColor.black.withAlphaComponent(0.6)),
            contentProperty: ModalProperties.ContentProperty(
                backgroundColor: Color(uiColor: .white),
                cornerRadius: 16,
                fixedWidthPortrait: 256,
                maxWidthPortrait: 256,
                fixedWidthLandscape: 256,
                maxWidthLandscape: 256,
                childShouldMatchParent: true
            ),
            margin: EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20),
            padding: UIMinMaxEdgeInsets(top: (16, 24), left: (16, 32), bottom: (16, 24), right: (16, 32)),
            bannerRatio: 1,
            bannerMaxHeight: nil,
            titleFont: .system(size: 24, weight: .bold),
            titleColor: Color(uiColor: .label),
            subtitleFont: .system(size: 16),
            subtitleColor: Color(uiColor: .secondaryLabel),
            buttonActionShouldMatchParent: true,
            buttonActionOrientation: .vertical,
            primaryActionStyle: .obliqueBottomLeft(
                ModalProperties.ActionStyle.ObliqueBottomLeftTheme(
                    unPressedColor: Color(uiColor: .systemOrange),
                    pressedColor: Color(uiColor: .systemBlue),
                    disabledColor: Color(uiColor: .lightGray),
                    shadowColor: Color(cgColor: UIColor.systemOrange.cgColor),
                    titleColor: Color(uiColor: .white),
                    titleDisableColor: Color(uiColor: .white),
                    titleFont: .system(size: 16, weight: .medium)
                )
            ),
            secondaryActionStyle: .plain(
                ModalProperties.ActionStyle.PlainTheme(
                    titleColor: Color(uiColor: .systemBlue),
                    titleDisableColor: Color(uiColor: .lightGray),
                    titleFont: .system(size: 16, weight: .medium)
                )
            ),
            closeButtonTint: Color(uiColor: .black),
            space: ModalProperties.ComponentSpace(banner: 8, title: 8, subtitle: 16, interButton: 8)
        )
    }

    static func popupModalProperties() -> ModalProperties {
        var properties = standardModalProperties()
        properties.padding = UIMinMaxEdgeInsets(
            top: (20, 32), left: (20, 32), bottom: (20, 32), right: (20, 32)
        )
        properties.space = ModalProperties.ComponentSpace(banner: 16, title: 16, subtitle: 24, interButton: 8)
        return properties
    }

    // MARK: - Catalog presets (ModalProperties), for the 26 real shapes on the UIKit-free renderers
    //
    // Field-for-field transcriptions of the UIKit presets below (`permissionAlertProperties()` and
    // friends) — same relationship `standardModalProperties()`/`popupModalProperties()` already have
    // to `standardProperties()`/`popupProperties()`. `bannerFixedHeight` is dropped everywhere (no
    // `ModalProperties` field — §3a, measured inert on UIKit's own path).

    static func permissionAlertModalProperties() -> ModalProperties {
        var properties = standardModalProperties()
        properties.padding = UIMinMaxEdgeInsets(top: (20, 20), left: (30, 30), bottom: (12, 12), right: (30, 30))
        properties.space = ModalProperties.ComponentSpace(banner: 8, title: 12, subtitle: 20, interButton: 8)
        return properties
    }

    static func obliqueRedModalProperties() -> ModalProperties {
        var properties = standardModalProperties()
        properties.primaryActionStyle = .obliqueBottomLeft(
            ModalProperties.ActionStyle.ObliqueBottomLeftTheme(
                unPressedColor: Color(uiColor: .systemRed),
                pressedColor: Color(uiColor: .systemRed),
                disabledColor: Color(uiColor: .gray),
                shadowColor: Color(uiColor: .systemRed),
                titleColor: .white,
                titleDisableColor: .white
            )
        )
        return properties
    }

    /// Shared shape behind the 7 banner-popup catalog entries — same reason `GeniePresets
    /// .popupBannerProperties(ratio:maxHeight:fixedHeight:)` is spelled once.
    static func popupBannerModalProperties(ratio: CGFloat, maxHeight: CGFloat) -> ModalProperties {
        var properties = popupModalProperties()
        properties.bannerRatio = ratio
        properties.bannerMaxHeight = maxHeight
        return properties
    }

    static func errorBannerModalProperties() -> ModalProperties {
        popupBannerModalProperties(ratio: 295.0 / 256.0, maxHeight: 320)
    }

    static func forceUpdateBannerModalProperties() -> ModalProperties {
        popupBannerModalProperties(ratio: 320.0 / 320.0, maxHeight: 320)
    }

    static func capBannerModalProperties() -> ModalProperties {
        popupBannerModalProperties(ratio: 320.0 / 197.0, maxHeight: 216)
    }

    static func quizBannerModalProperties() -> ModalProperties {
        popupBannerModalProperties(ratio: 320.0 / 229.0, maxHeight: 216)
    }

    static func aiNotesBannerModalProperties() -> ModalProperties {
        popupBannerModalProperties(ratio: 960.0 / 681.0, maxHeight: 320)
    }

    static func creditDeductionModalProperties() -> ModalProperties {
        var properties = popupModalProperties()
        properties.titleFont = .system(size: 24, weight: .heavy)
        return properties
    }

    static func streakModalProperties() -> ModalProperties {
        var properties = standardModalProperties()
        properties.padding = UIMinMaxEdgeInsets(top: (20, 40), left: (20, 48), bottom: (20, 32), right: (20, 48))
        properties.bannerRatio = 200.0 / 168.0
        properties.bannerMaxHeight = 168
        properties.space = ModalProperties.ComponentSpace(banner: 16, title: 12, subtitle: 24, interButton: 8)
        return properties
    }

    static func timerBannerModalProperties() -> ModalProperties {
        var properties = standardModalProperties()
        properties.padding = UIMinMaxEdgeInsets(top: (32, 32), left: (32, 32), bottom: (32, 32), right: (32, 32))
        properties.bannerRatio = 193.0 / 170.0
        properties.bannerMaxHeight = 170
        return properties
    }

    static func exitWorksheetBannerModalProperties() -> ModalProperties {
        var properties = standardModalProperties()
        properties.bannerRatio = 365.0 / 206.0
        properties.bannerMaxHeight = 144
        return properties
    }

    static func renameInputModalProperties() -> ModalProperties {
        var properties = standardModalProperties()
        properties.padding = UIMinMaxEdgeInsets(top: (20, 32), left: (16, 32), bottom: (16, 16), right: (16, 32))
        properties.titleFont = .system(size: 24, weight: .heavy)
        properties.space = ModalProperties.ComponentSpace(banner: 8, title: 16, subtitle: 32, interButton: 8)
        return properties
    }

    static func datePickerInputModalProperties() -> ModalProperties {
        var properties = standardModalProperties()
        // `contentProperty` deliberately NOT overridden: widening it was tried and had no
        // observable effect on-device either way — the picker does not read this number in any
        // direction (see `DatePickerModalView`'s doc). Left at `standard`'s real 256pt production
        // column rather than kept at an unmotivated number that never did anything.
        properties.padding = UIMinMaxEdgeInsets(top: (20, 32), left: (12, 40), bottom: (16, 16), right: (12, 40))
        properties.titleFont = .system(size: 24, weight: .heavy)
        properties.space = ModalProperties.ComponentSpace(banner: 8, title: 0, subtitle: 8, interButton: 8)
        return properties
    }

    /// `BadgesPopUpView.swift`'s real preset. Deliberately NOT named `badgeModalProperties()` — see
    /// the UIKit sibling's own note on why `badgeProperties()` is reserved for the synthetic third
    /// preset `RendererParityTests`/`ModalStyleTests` assert on field-by-field.
    static func badgeUnlockModalProperties() -> ModalProperties {
        var properties = standardModalProperties()
        properties.padding = UIMinMaxEdgeInsets(top: (20, 40), left: (20, 48), bottom: (20, 32), right: (20, 48))
        properties.bannerRatio = 1
        properties.bannerMaxHeight = 144
        properties.space = ModalProperties.ComponentSpace(banner: 16, title: 12, subtitle: 24, interButton: 8)
        return properties
    }

    static func badgeMultiModalProperties() -> ModalProperties {
        var properties = badgeUnlockModalProperties()
        properties.bannerMaxHeight = 216
        return properties
    }

    static func badgeDetailModalProperties() -> ModalProperties {
        var properties = standardModalProperties()
        properties.padding = UIMinMaxEdgeInsets(top: (20, 36), left: (20, 48), bottom: (20, 36), right: (20, 48))
        properties.space = ModalProperties.ComponentSpace(banner: 0, title: 0, subtitle: 24, interButton: 0)
        return properties
    }

    /// A THIRD preset, standing in for the app's real `badgeProperties`/`streakModalProperties`/
    /// `permissionAlertProperties` — the presets that have no descriptor type and are the whole
    /// reason `ModalStyle` exists.
    ///
    /// Deliberately differs from `standardProperties()` in fields that survive the WHOLE styling
    /// pipeline and are observable on both backends: `cornerRadius` 28 (vs 16) and the card widths
    /// 300 (vs 256) both reach `ModalTokens`/`ResolvedModal`, and `titleColor` `.magenta` (vs
    /// `.label`) reaches `ModalTokens.Palette.titleText`. Every one of them is set EXPLICITLY, so
    /// `GBAlertModal.updateProperties`' merge against `globalProperties` is a no-op for them and the
    /// UIKit and SwiftUI readings are comparable field-for-field.
    static func badgeProperties() -> GBAlertModal.Properties {
        standardProperties().copy(
            contentProperty: GBAlertModal.Properties.ContentProperty(
                backgroundColor: .white,
                cornerRadius: 28,
                fixedWidthPortrait: 300,
                maxWidthPortrait: 300,
                fixedWidthLandscape: 300,
                maxWidthLandscape: 300,
                childShouldMatchParent: true
            ),
            titleColor: .magenta
        )
    }

    private static var contentProperty: GBAlertModal.Properties.ContentProperty {
        GBAlertModal.Properties.ContentProperty(
            backgroundColor: .white,
            cornerRadius: 16,
            fixedWidthPortrait: 256,
            maxWidthPortrait: 256,
            fixedWidthLandscape: 256,
            maxWidthLandscape: 256,
            childShouldMatchParent: true
        )
    }

    private static var margin: UIEdgeInsets {
        // TOP/BOTTOM 0, horizontal unchanged. The card HUGS its content, so a zero vertical margin
        // only changes cards that are actually constrained — portrait fits either way and does not
        // move. Landscape gains the whole 80pt: the card ceiling goes 214 -> 294 and the popup
        // preset's content budget 174 -> 254, which is the difference between "one line of each does
        // not fit" and a comfortable fit.
        //
        // Zero to the SAFE AREA, not to the device bounds — `adjustVwContainerConstraint` pins
        // against `safeAreaLayoutGuide`, so the card still clears the home indicator and the notch.
        UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
    }

    private static var padding: UIMinMaxEdgeInsets {
        UIMinMaxEdgeInsets(
            top: (16, 24),
            left: (16, 32),
            bottom: (16, 24),
            right: (16, 32)
        )
    }

    private static var space: GBAlertModal.Properties.ComponentSpace {
        GBAlertModal.Properties.ComponentSpace(
            banner: 8,
            title: 8,
            subtitle: 16,
            interButton: 8
        )
    }

    private static var plainTheme: GBAlertModal.ActionStyle.PlainTheme {
        GBAlertModal.ActionStyle.PlainTheme(
            titleColor: .systemBlue,
            titleDisableColor: .lightGray,
            titleFont: .systemFont(ofSize: 16, weight: .medium)
        )
    }

    private static var obliqueBottomLeftTheme: GBAlertModal.ActionStyle.ObliqueBottomLeftTheme {
        GBAlertModal.ActionStyle.ObliqueBottomLeftTheme(
            unPressedColor: .systemOrange,
            pressedColor: .systemBlue,
            disabledColor: .lightGray,
            shadowColor: UIColor.systemOrange.cgColor,
            titleColor: .white,
            titleDisableColor: .white,
            titleFont: .systemFont(ofSize: 16, weight: .medium)
        )
    }

    // MARK: - Holders

    private static func base() -> GBAlertModal.DataHolder {
        GBAlertModal.DataHolder(
            closeOnTapOverlay: true,
            title: "Title",
            subtitle: "This is the subtitle text for the alert modal.",
            primaryAction: "Okay",
            dismissOnAction: true
        )
    }

    static func oneButton() -> GBAlertModal.DataHolder {
        base()
    }

    static func twoButton() -> GBAlertModal.DataHolder {
        base().copy(secondaryAction: "Cancel")
    }

    static func withBanner() -> GBAlertModal.DataHolder {
        // A real, non-zero-size image — after Task 8's fix, a zero-size `UIImage()` collapses
        // the banner slot entirely, so this fixture needs actual pixels to keep exercising a
        // *visible* banner (as opposed to duplicating the no-banner case). Square, matching
        // `standardProperties().bannerRatio == 1`: the banner view's width==height constraint
        // is required, so a non-square source image fights it under the tight landscape card
        // height and squeezes title/subtitle out — a pre-existing constraint quirk unrelated
        // to Task 8, sidestepped here by supplying an image that already satisfies the ratio.
        base().copy(banner: .gbv3TestSolid(width: 64, height: 64))
    }

    /// A banner holder with an arbitrary (possibly non-square) image, for exercising the
    /// natural-aspect banner path (`bannerRatio: nil`, see `standardPropertiesNilBannerRatio()`).
    static func withBanner(width: CGFloat, height: CGFloat) -> GBAlertModal.DataHolder {
        base().copy(banner: .gbv3TestSolid(width: width, height: height))
    }

    static func withCloseButton() -> GBAlertModal.DataHolder {
        base().copy(showCloseButton: true)
    }

    static func renameWorksheet() -> GBAlertModal.DataHolder {
        let container = UIView()
        let textView = UITextView()
        textView.text = "Existing worksheet name"
        textView.font = .systemFont(ofSize: 16)
        textView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: container.topAnchor),
            textView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            textView.heightAnchor.constraint(equalToConstant: 44)
        ])

        // Built directly (not via `.copy()`): `DataHolder.copy()` falls back to the
        // original value when `nil` is passed, so it cannot be used to *unset*
        // `subtitle` here — and a non-empty `subtitle` would take priority over
        // `subtitleCustomView` in `registerDialogView()`.
        return GBAlertModal.DataHolder(
            closeOnTapOverlay: true,
            title: "Rename",
            subtitleCustomView: container,
            primaryAction: "Done",
            secondaryAction: "Cancel",
            dismissOnAction: true
        )
    }

    static func datePickerWorksheet() -> GBAlertModal.DataHolder {
        let container = UIView()
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        if #available(iOS 13.4, *) {
            datePicker.preferredDatePickerStyle = .wheels
        }
        // Pin to a fixed date/locale/time zone: `UIDatePicker()` otherwise defaults to
        // `Date()` (today), which would render a different wheel position every day and
        // make the snapshot baseline drift/fail with no code change involved.
        datePicker.locale = Locale(identifier: "en_US_POSIX")
        datePicker.timeZone = TimeZone(identifier: "UTC")
        datePicker.date = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14T22:13:20Z
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(datePicker)
        NSLayoutConstraint.activate([
            datePicker.topAnchor.constraint(equalTo: container.topAnchor),
            datePicker.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            datePicker.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            datePicker.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return GBAlertModal.DataHolder(
            closeOnTapOverlay: true,
            title: "Select date",
            subtitleCustomView: container,
            primaryAction: "Done",
            secondaryAction: "Cancel",
            dismissOnAction: true
        )
    }

    static func longTitle() -> GBAlertModal.DataHolder {
        let title = String(repeating: "Long title wraps across many lines ", count: 4)
            .trimmingCharacters(in: .whitespaces)
        return base().copy(title: title)
    }

    static func longSubtitle() -> GBAlertModal.DataHolder {
        // Long enough that the rendered text height exceeds the modal's max card height
        // (bounded by `margin` against the window), forcing `svSubtitleContainer` to
        // actually scroll instead of just hugging its content.
        let subtitle = String(repeating: "This subtitle keeps going and going so the scroll view has to engage. ", count: 40)
            .trimmingCharacters(in: .whitespaces)
        return base().copy(subtitle: subtitle)
    }

    static func longButtonLabel() -> GBAlertModal.DataHolder {
        let primaryLabel = "This is a very long primary button label that should not fit on one line easily"
        let secondaryLabel = "This is a very long secondary button label that should not fit on one line either"
        return base().copy(
            primaryAction: primaryLabel,
            secondaryAction: secondaryLabel
        )
    }
}

// MARK: - Catalog presets
//
// The remaining presets the 26 REAL dialog shapes need, transcribed from
// `Examples/.../Gallery/GalleryPresets.swift` — which is itself confirmed against the distribution
// app's `V3AlertModal+GBV3AlertModal.swift`, `BadgesPopUpView.swift`, `StreakPopUpView.swift` and
// `GACameraCell.swift`. STRUCTURAL values (padding, banner geometry, component spacing, button
// orientation) are copied verbatim, because those are what `ResolvedModal`/`ModalTokens` actually
// read.
//
// FIDELITY LIMIT, stated once here rather than per-preset: FONTS AND COLOURS ARE SYSTEM
// APPROXIMATIONS. The real presets use `SHSans`/`DMSans` and the `UIColor.Genie.*` palette, neither
// of which exists in this package (the app owns them). `ModalTokens.init(from:)` bridges whatever
// `UIFont`/`UIColor` a `Properties` carries, so the real app's typography would flow through
// unchanged — but nothing in this test target PROVES that, and no test here should be read as
// evidence about the app's actual type or colour.
extension GeniePresets {

    /// `GACameraCell.swift`'s inline permission-alert override: asymmetric 20/30 padding, tighter
    /// component spacing. Used by `permission-denied-settings`.
    static func permissionAlertProperties() -> GBAlertModal.Properties {
        standardProperties().copy(
            padding: UIMinMaxEdgeInsets(
                top: (20, 20),
                left: (30, 30),
                bottom: (12, 12),
                right: (30, 30)
            ),
            space: GBAlertModal.Properties.ComponentSpace(
                banner: 8, title: 12, subtitle: 20, interButton: 8
            )
        )
    }

    /// `V1OnlineLessonViewController.showLeavePopUp()`'s red oblique theme. Note `titleFont` is
    /// deliberately absent at the real call site, so `ModalTokens` keeps its `standard` button font
    /// — copied verbatim rather than filled in.
    static func obliqueRedProperties() -> GBAlertModal.Properties {
        standardProperties().copy(
            primaryActionStyle: .obliqueBottomLeft(
                GBAlertModal.ActionStyle.ObliqueBottomLeftTheme(
                    unPressedColor: .systemRed,
                    pressedColor: .systemRed,
                    disabledColor: .gray,
                    shadowColor: UIColor.systemRed.cgColor,
                    titleColor: .white,
                    titleDisableColor: .white
                )
            )
        )
    }

    /// The popup preset plus banner geometry — the shape of every banner popup in the catalog.
    /// Spelled once because seven catalog entries differ ONLY in these three numbers.
    static func popupBannerProperties(
        ratio: CGFloat,
        maxHeight: CGFloat,
        fixedHeight: CGFloat
    ) -> GBAlertModal.Properties {
        popupProperties().copy(
            bannerRatio: ratio,
            bannerMaxHeight: maxHeight,
            bannerFixedHeight: fixedHeight
        )
    }

    /// `database-error-banner` (`UiKitErrorHandlerHelper+Common.swift`).
    static func errorBannerProperties() -> GBAlertModal.Properties {
        popupBannerProperties(ratio: 295.0 / 256.0, maxHeight: 320, fixedHeight: 256)
    }

    /// `force-update-banner` (`APIClient.swift`). Same height budget as the error banner, square ratio.
    static func forceUpdateBannerProperties() -> GBAlertModal.Properties {
        popupBannerProperties(ratio: 320.0 / 320.0, maxHeight: 320, fixedHeight: 256)
    }

    /// `worksheet-abused-cap-banner` (`V2CustomisedWorksheetGeneratorViewController.swift`).
    static func capBannerProperties() -> GBAlertModal.Properties {
        popupBannerProperties(ratio: 320.0 / 197.0, maxHeight: 216, fixedHeight: 184)
    }

    /// `quiz-info-banner` / `quiz-begin-banner` (`V2RecordedPreviewViewController.swift`), and
    /// `onboarding-trial-banner` (`V1MainTabViewController+PopupCampaign.swift`) — the catalog gives
    /// all three the SAME 320:229 / 216 / 184 geometry. One builder, three style tokens, so a future
    /// divergence in any one of them is a one-line change rather than a shared-preset hazard.
    static func quizBannerProperties() -> GBAlertModal.Properties {
        popupBannerProperties(ratio: 320.0 / 229.0, maxHeight: 216, fixedHeight: 184)
    }

    /// `ai-notes-ready-banner` (`V3GenieClassDashboardViewController+AiNotes.swift`).
    static func aiNotesBannerProperties() -> GBAlertModal.Properties {
        popupBannerProperties(ratio: 960.0 / 681.0, maxHeight: 320, fixedHeight: 256)
    }

    /// `credit-deduction-popup` — the popup preset with a heavier title, no banner.
    static func creditDeductionProperties() -> GBAlertModal.Properties {
        popupProperties().copy(titleFont: .systemFont(ofSize: 24, weight: .heavy))
    }

    /// `StreakPopUpView.swift`'s `streakModalProperties`, used by `streak-popup-banner`.
    static func streakProperties() -> GBAlertModal.Properties {
        standardProperties().copy(
            padding: UIMinMaxEdgeInsets(
                top: (20, 40),
                left: (20, 48),
                bottom: (20, 32),
                right: (20, 48)
            ),
            bannerRatio: 200.0 / 168.0,
            bannerMaxHeight: 168,
            bannerFixedHeight: 168,
            space: GBAlertModal.Properties.ComponentSpace(
                banner: 16, title: 12, subtitle: 24, interButton: 8
            )
        )
    }

    /// The shared preset behind `worksheet-ready-timer-banner` / `worksheet-timeup-timer-banner`
    /// (`V1WorkingSpaceViewController.swift`): uniform 32pt padding, 193:170 banner.
    static func timerBannerProperties() -> GBAlertModal.Properties {
        standardProperties().copy(
            padding: UIMinMaxEdgeInsets(
                top: (32, 32),
                left: (32, 32),
                bottom: (32, 32),
                right: (32, 32)
            ),
            bannerRatio: 193.0 / 170.0,
            bannerMaxHeight: 170,
            bannerFixedHeight: 170
        )
    }

    /// `exit-worksheet-confirm-banner` (`V1WorkingSpaceViewController.swift`).
    static func exitWorksheetBannerProperties() -> GBAlertModal.Properties {
        standardProperties().copy(
            bannerRatio: 365.0 / 206.0,
            bannerMaxHeight: 144,
            bannerFixedHeight: 144
        )
    }

    /// `rename-worksheet`'s preset (`V1WorksheetViewController.swift`'s `renameWorksheet:` init):
    /// heavier title, tighter top/bottom padding, wider title/subtitle spacing.
    static func renameInputProperties() -> GBAlertModal.Properties {
        standardProperties().copy(
            padding: UIMinMaxEdgeInsets(
                top: (20, 32),
                left: (16, 32),
                bottom: (16, 16),
                right: (16, 32)
            ),
            titleFont: .systemFont(ofSize: 24, weight: .heavy),
            space: GBAlertModal.Properties.ComponentSpace(
                banner: 8, title: 16, subtitle: 32, interButton: 8
            )
        )
    }

    /// `date-picker-worksheet`'s preset: narrower horizontal padding (the wheel needs the width)
    /// and near-zero title/subtitle spacing.
    static func datePickerInputProperties() -> GBAlertModal.Properties {
        standardProperties().copy(
            padding: UIMinMaxEdgeInsets(
                top: (20, 32),
                left: (12, 40),
                bottom: (16, 16),
                right: (12, 40)
            ),
            titleFont: .systemFont(ofSize: 24, weight: .heavy),
            space: GBAlertModal.Properties.ComponentSpace(
                banner: 8, title: 0, subtitle: 8, interButton: 8
            )
        )
    }

    /// `BadgesPopUpView.swift`'s `badgeProperties` — the REAL app preset for `badge-unlock-single`.
    ///
    /// Deliberately NOT named `badgeProperties()`: that name is already taken by the synthetic
    /// third preset above, which `RendererParityTests` asserts on field-by-field. Renaming it would
    /// churn the parity gate for no reason.
    static func badgeUnlockProperties() -> GBAlertModal.Properties {
        standardProperties().copy(
            padding: UIMinMaxEdgeInsets(
                top: (20, 40),
                left: (20, 48),
                bottom: (20, 32),
                right: (20, 48)
            ),
            bannerRatio: 1,
            bannerMaxHeight: 144,
            bannerFixedHeight: 144,
            space: GBAlertModal.Properties.ComponentSpace(
                banner: 16, title: 12, subtitle: 24, interButton: 8
            )
        )
    }

    /// `badge-unlock-multi` — the unlock preset with the taller static banner.
    static func badgeMultiProperties() -> GBAlertModal.Properties {
        badgeUnlockProperties().copy(bannerMaxHeight: 216, bannerFixedHeight: 216)
    }

    /// `badge-detail-popup` (`VBadgeListViewController.swift`): wide padding and a `ComponentSpace`
    /// that zeroes everything except the gap below the custom content.
    static func badgeDetailProperties() -> GBAlertModal.Properties {
        standardProperties().copy(
            padding: UIMinMaxEdgeInsets(
                top: (20, 36),
                left: (20, 48),
                bottom: (20, 36),
                right: (20, 48)
            ),
            space: GBAlertModal.Properties.ComponentSpace(
                banner: 0, title: 0, subtitle: 24, interButton: 0
            )
        )
    }
}
