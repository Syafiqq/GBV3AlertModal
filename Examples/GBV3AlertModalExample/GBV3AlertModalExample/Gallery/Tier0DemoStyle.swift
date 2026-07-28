import UIKit
import GBV3AlertModal

/// Full styled `Properties` for the Tier-0 demo so the real UIKit modal renders as a proper CARD
/// (background, corner radius, width, margins, spacing) — not bare title/subtitle/buttons.
/// Approximates the app's `V3AlertModal` preset; exact design tokens live app-side.
enum Tier0DemoStyle {
    // Fixed colours (NOT adaptive) — the real modal is always a white card with dark text, so it
    // reads correctly in dark mode too. Adaptive .systemBackground/.label go black-on-black in dark.
    private static let navy = UIColor(red: 0x26 / 255, green: 0x22 / 255, blue: 0x62 / 255, alpha: 1)
    private static let bodyGray = UIColor(white: 0.2, alpha: 1)
    /// The oblique offset edge — a DISTINCT orange from the fill (real app: orangeMandarin), so the
    /// offset actually shows. Same colour as the fill would make the oblique invisible.
    private static let obliqueShadow = UIColor(red: 0xE5 / 255, green: 0x7B / 255, blue: 0x41 / 255, alpha: 1)

    /// Orange oblique primary (the standard alert look).
    static func alert() -> GBAlertModal.Properties {
        properties(titleColor: navy, accent: .systemOrange, oblique: true)
    }

    /// Indigo capsule primary + indigo title (visibly distinct — the popup style).
    static func popup() -> GBAlertModal.Properties {
        properties(titleColor: .systemIndigo, accent: .systemIndigo, oblique: false)
    }

    private static func properties(titleColor: UIColor, accent: UIColor, oblique: Bool) -> GBAlertModal.Properties {
        let content = GBAlertModal.Properties.ContentProperty(
            backgroundColor: .white,   // fixed white card (not adaptive) — visible on the dark scrim in any mode
            cornerRadius: 16,
            fixedWidthPortrait: 300, maxWidthPortrait: 300,
            fixedWidthLandscape: 300, maxWidthLandscape: 300,
            childShouldMatchParent: true
        )
        let primary: GBAlertModal.ActionStyle = oblique
            ? .obliqueBottomLeft(.init(
                unPressedColor: accent,
                pressedColor: accent.withAlphaComponent(0.8),
                disabledColor: .systemGray4,
                shadowColor: obliqueShadow.cgColor,
                titleColor: .white,
                titleDisableColor: .white,
                titleFont: .systemFont(ofSize: 16, weight: .heavy)))
            : .capsule(.init(backgroundColor: accent, titleColor: .white))
        return GBAlertModal.Properties(
            overlayColor: UIColor.black.withAlphaComponent(0.6),
            contentProperty: content,
            margin: UIEdgeInsets(top: 40, left: 20, bottom: 40, right: 20),
            padding: UIMinMaxEdgeInsets(top: (16, 24), left: (16, 32), bottom: (16, 24), right: (16, 32)),
            bannerRatio: 1,
            titleFont: .boldSystemFont(ofSize: 24),
            titleColor: titleColor,
            subtitleFont: .systemFont(ofSize: 16),
            subtitleColor: bodyGray,
            buttonActionShouldMatchParent: true,
            buttonActionOrientation: .vertical,
            primaryActionStyle: primary,
            secondaryActionStyle: .plain(.init(titleColor: accent,
                                               titleDisableColor: .systemGray3,
                                               titleFont: .systemFont(ofSize: 16, weight: .medium))),
            closeButtonTint: bodyGray,
            space: GBAlertModal.Properties.ComponentSpace(banner: 8, title: 8, subtitle: 16, interButton: 8)
        )
    }
}
