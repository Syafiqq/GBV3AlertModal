//
//  StressCatalog.swift
//  GBV3AlertModalExample
//
//  A sampled (NOT full-cartesian) stress matrix over the axes that most
//  commonly break alert-modal layouts in the wild: banner aspect ratio,
//  title/subtitle length, button label length, and button orientation.
//  Every entry's `category` starts with `"Stress · "` so it forms its own
//  section(s) in `GalleryViewController`, appended after `DialogCatalog.entries`.
//
//  Layout: (A) a per-axis sweep off a shared baseline, (B) two
//  everything-maxed combos, (C) four degenerate (mostly-empty) shapes,
//  (D) three "nasty interaction" combos that pair two extreme axes at once,
//  (E) a close-button variant, and (F) a handful of additional combos that
//  looked like obvious gaps once the sweep was laid out (a fully buttonless
//  dialog, a vertical pair of wrapped buttons, and wide-banner/close-button
//  crosses).
//

import UIKit
import GBV3AlertModal

@MainActor
enum StressCatalog {
    static let entries: [DialogEntry] =
        axisSweepEntries
            + maxedEntries
            + degenerateEntries
            + nastyInteractionEntries
            + closeButtonEntries
            + extraEntries
}

// MARK: - Shared content

private extension StressCatalog {
    /// A single unbroken string (no `\n`) long enough to wrap to ~10 lines at
    /// the 24pt bold title font inside the gallery's 256pt-wide card.
    static let title10Line =
        "This is an intentionally long title string engineered to stress test the wrapping behavior of " +
        "the alert modal across many lines without any manual line breaks so the layout engine must " +
        "handle natural word wrapping consistently across roughly ten lines of bold twenty four point " +
        "text inside a narrow content card which forces frequent word wraps and exercises the vertical " +
        "growth of the title label region within the alert content stack and its surrounding padding " +
        "and spacing constraints under sustained load"

    /// Same idea, longer (smaller 16pt font fits more per line) so it also
    /// wraps to ~10 lines.
    static let subtitle10Line =
        "This subtitle exists purely to stress test long form body copy wrapping inside the alert modal " +
        "without any manual line breaks whatsoever so that the rendering engine is forced to reflow " +
        "every single word naturally across roughly ten lines of regular sixteen point text set inside " +
        "a narrow two hundred fifty six point wide content card which in turn forces frequent word " +
        "wraps and thoroughly exercises the vertical growth behavior of the subtitle label region " +
        "within the alert content stack along with its surrounding padding insets interbutton spacing " +
        "and overall scroll container sizing logic under sustained stress conditions"

    static let primaryFull = "Continue"
    static let secondaryFull = "Not Now"

    static let primaryWrapped =
        "This Extremely Long Primary Action Button Label Is Designed To Force Multi-Line Wrapping " +
        "Inside The Button Bounds"
    static let secondaryWrapped =
        "This Equally Long Secondary Action Button Label Also Forces The Button To Wrap Across " +
        "Several Lines"

    /// The two ultra-aspect banner assets added for this stress matrix.
    enum BannerKind {
        case none
        case wide
        case tall

        var image: UIImage? {
            switch self {
            case .none:
                return nil
            case .wide:
                return UIImage(named: "banner_ultrawide")
            case .tall:
                return UIImage(named: "banner_ultratall")
            }
        }

        /// `width / height`, matching the asset's real pixel dimensions
        /// (2000x200 / 200x2000) so the banner slot renders at its true —
        /// deliberately extreme — aspect ratio rather than being squashed
        /// into `GalleryPresets.properties`'s default square `bannerRatio`.
        var ratio: CGFloat? {
            switch self {
            case .none:
                return nil
            case .wide:
                return 2000.0 / 200.0
            case .tall:
                return 200.0 / 2000.0
            }
        }
    }
}

// MARK: - Entry builder

private extension StressCatalog {
    static func properties(banner: BannerKind, orientation: NSLayoutConstraint.Axis) -> GBAlertModal.Properties {
        let base = orientation == .horizontal
            ? GalleryPresets.properties.copy(buttonActionOrientation: .horizontal)
            : GalleryPresets.properties
        guard let ratio = banner.ratio else {
            return base
        }
        return base.copy(bannerRatio: ratio)
    }

    static func entry(
        _ name: String,
        category: String,
        banner: BannerKind = .none,
        title: String? = nil,
        subtitle: String? = nil,
        primary: String? = nil,
        secondary: String? = nil,
        orientation: NSLayoutConstraint.Axis = .vertical,
        showCloseButton: Bool = false
    ) -> DialogEntry {
        DialogEntry(name: name, category: category) {
            SampleAlertModal(
                properties: properties(banner: banner, orientation: orientation),
                // Built via the `DataHolder` initializer, NOT `GalleryPresets.holder.copy(...)`:
                // `DataHolder.copy` treats an explicitly-passed `nil` argument as "not
                // provided" (`primaryAction ?? self.primaryAction`), so it can never clear a
                // field back to `nil` once the base holder already has a value — and
                // `GalleryPresets.holder.primaryAction` is `"Okay"`. Every "no primary/
                // secondary button" stress state needs a real `nil` here, which only the
                // plain initializer can express.
                holder: GBAlertModal.DataHolder(
                    closeOnTapOverlay: true,
                    banner: banner.image,
                    title: title,
                    subtitle: subtitle,
                    primaryAction: primary,
                    secondaryAction: secondary,
                    showCloseButton: showCloseButton,
                    dismissOnAction: true,
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }
}

// MARK: - A. Per-axis sweep

private extension StressCatalog {
    static let sweepCategory = "Stress · Axis Sweep"

    /// Baseline every sweep entry varies exactly one axis away from: no
    /// banner, 10-line title, 10-line subtitle, full primary, full
    /// secondary, vertical buttons.
    static var axisSweepEntries: [DialogEntry] {
        [
            entry(
                "stress-baseline", category: sweepCategory,
                title: title10Line, subtitle: subtitle10Line,
                primary: primaryFull, secondary: secondaryFull
            ),
            entry(
                "stress-banner-ultrawide", category: sweepCategory,
                banner: .wide, title: title10Line, subtitle: subtitle10Line,
                primary: primaryFull, secondary: secondaryFull
            ),
            entry(
                "stress-banner-ultratall", category: sweepCategory,
                banner: .tall, title: title10Line, subtitle: subtitle10Line,
                primary: primaryFull, secondary: secondaryFull
            ),
            entry(
                "stress-title-none", category: sweepCategory,
                title: nil, subtitle: subtitle10Line,
                primary: primaryFull, secondary: secondaryFull
            ),
            entry(
                "stress-subtitle-none", category: sweepCategory,
                title: title10Line, subtitle: nil,
                primary: primaryFull, secondary: secondaryFull
            ),
            entry(
                "stress-primary-none", category: sweepCategory,
                title: title10Line, subtitle: subtitle10Line,
                primary: nil, secondary: secondaryFull
            ),
            entry(
                "stress-primary-wrapped", category: sweepCategory,
                title: title10Line, subtitle: subtitle10Line,
                primary: primaryWrapped, secondary: secondaryFull
            ),
            entry(
                "stress-secondary-none", category: sweepCategory,
                title: title10Line, subtitle: subtitle10Line,
                primary: primaryFull, secondary: nil
            ),
            entry(
                "stress-secondary-wrapped", category: sweepCategory,
                title: title10Line, subtitle: subtitle10Line,
                primary: primaryFull, secondary: secondaryWrapped
            ),
            entry(
                "stress-buttons-horizontal", category: sweepCategory,
                title: title10Line, subtitle: subtitle10Line,
                primary: primaryFull, secondary: secondaryFull, orientation: .horizontal
            )
        ]
    }
}

// MARK: - B. Everything maxed

private extension StressCatalog {
    static let maxedCategory = "Stress · Everything Maxed"

    static var maxedEntries: [DialogEntry] {
        [
            entry(
                "stress-maxed-vertical", category: maxedCategory,
                banner: .tall, title: title10Line, subtitle: subtitle10Line,
                primary: primaryWrapped, secondary: secondaryWrapped
            ),
            entry(
                "stress-maxed-horizontal", category: maxedCategory,
                banner: .tall, title: title10Line, subtitle: subtitle10Line,
                primary: primaryWrapped, secondary: secondaryWrapped, orientation: .horizontal
            )
        ]
    }
}

// MARK: - C. Degenerate

private extension StressCatalog {
    static let degenerateCategory = "Stress · Degenerate"

    static var degenerateEntries: [DialogEntry] {
        [
            // No banner, no title, no subtitle, no buttons at all.
            entry("stress-all-none", category: degenerateCategory),
            // Ultra-wide banner and nothing else.
            entry("stress-banner-only", category: degenerateCategory, banner: .wide),
            // Two full-length buttons, no banner/title/subtitle.
            entry(
                "stress-buttons-only", category: degenerateCategory,
                primary: primaryFull, secondary: secondaryFull
            ),
            // 10-line title and nothing else.
            entry("stress-title-only", category: degenerateCategory, title: title10Line)
        ]
    }
}

// MARK: - D. Nasty interactions

private extension StressCatalog {
    static let nastyCategory = "Stress · Nasty Interactions"

    static var nastyInteractionEntries: [DialogEntry] {
        [
            entry(
                "stress-nasty-widebanner-horizontal-wrapped", category: nastyCategory,
                banner: .wide, primary: primaryWrapped, secondary: secondaryWrapped, orientation: .horizontal
            ),
            entry(
                "stress-nasty-horizontal-wrapped-no-banner", category: nastyCategory,
                primary: primaryWrapped, secondary: secondaryWrapped, orientation: .horizontal
            ),
            entry(
                "stress-nasty-tallbanner-subtitle", category: nastyCategory,
                banner: .tall, subtitle: subtitle10Line, primary: primaryFull
            )
        ]
    }
}

// MARK: - E. Close button

private extension StressCatalog {
    static let closeButtonCategory = "Stress · Close Button"

    static var closeButtonEntries: [DialogEntry] {
        [
            entry(
                "stress-close-button-title", category: closeButtonCategory,
                title: title10Line, primary: primaryFull, showCloseButton: true
            )
        ]
    }
}

// MARK: - F. Extra combos spotted while building the sweep

private extension StressCatalog {
    static let extraCategory = "Stress · Extra"

    static var extraEntries: [DialogEntry] {
        [
            // Title + subtitle present, but zero buttons — does the button
            // container collapse cleanly with no content in it?
            entry(
                "stress-no-buttons", category: extraCategory,
                title: title10Line, subtitle: subtitle10Line
            ),
            // Vertical counterpart to the horizontal wrapped-buttons nasty
            // interaction, isolated from banner/text.
            entry(
                "stress-two-wrapped-vertical", category: extraCategory,
                primary: primaryWrapped, secondary: secondaryWrapped
            ),
            // Wide banner + tall title — the horizontal counterpart to the
            // "tall banner + subtitle" nasty interaction.
            entry(
                "stress-widebanner-title-only", category: extraCategory,
                banner: .wide, title: title10Line
            ),
            // Close button crossed with horizontal wrapped buttons.
            entry(
                "stress-close-button-horizontal-wrapped", category: extraCategory,
                primary: primaryWrapped, secondary: secondaryWrapped,
                orientation: .horizontal, showCloseButton: true
            ),
            // Everything-maxed, but with the wide banner instead of tall —
            // exercises the button stack squeezed against a short banner.
            entry(
                "stress-maxed-widebanner-horizontal", category: extraCategory,
                banner: .wide, title: title10Line, subtitle: subtitle10Line,
                primary: primaryWrapped, secondary: secondaryWrapped, orientation: .horizontal
            )
        ]
    }
}
