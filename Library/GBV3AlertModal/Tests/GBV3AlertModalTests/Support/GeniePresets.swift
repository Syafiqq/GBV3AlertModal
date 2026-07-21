import UIKit
@testable import GBV3AlertModal

/// Test-only re-creation of the Genie consumer app's `Presentation.UiKit.V3AlertModal`
/// preset (see `Examples/GBV3AlertModalExample/.../ViewController.swift` for the shape this
/// was copied from). Structural values (widths, insets, spacing, flags) are copied verbatim.
/// Fonts/colors are approximated with system equivalents since the exact Genie design tokens
/// (FontHelper, UIColor.Custom, Colors) live in the consumer app, not this repo.
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
        UIEdgeInsets(top: 40, left: 20, bottom: 40, right: 20)
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

    /// Strong references to any custom subtitle views handed out via `subtitleCustomView`
    /// (a `weak var` on `DataHolder`), so they outlive the builder call for the duration of
    /// the test process.
    private static var retainedViews: [UIView] = []

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
        retainedViews.append(container)

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
        retainedViews.append(container)

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
