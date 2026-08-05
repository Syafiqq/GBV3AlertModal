//
//  DivergenceCatalog.swift
//  GBV3AlertModalExample
//
//  **The UIKit half of the divergence section.**
//
//  Five shapes, one per KNOWN difference between the UIKit and the SwiftUI
//  backend. Each has a twin of the same `name` in `SwiftUICatalog+Divergences.swift`,
//  built from the same `Properties` and the same content — because a divergence
//  entry with nothing to compare against is a screenshot, not a comparison.
//
//  Nothing here is a new finding. Every shape and every number is taken from
//  what was already measured and recorded:
//
//   * `docs/superpowers/specs/2026-08-02-swiftui-banner-height-design.md` §5, §5b–§5e
//   * `Library/GBV3AlertModal/Tests/GBV3AlertModalTests/SwiftUI/DifferentialGeometrySupport.swift`
//   * `.superpowers/sdd/2026-08-02-swiftui-banner-geometry/progress.md` (D-A, D-B)
//
//  The captions live on the SwiftUI side (that gallery renders them under each
//  row); this file carries the shapes and the provenance.
//

import UIKit
import GBV3AlertModal

@MainActor
enum DivergenceCatalog {
    static let category = "Divergence"

    static let entries: [DialogEntry] = [
        tallUncappedArtwork,
        ratioNotArtworkAspect,
        bannerWideLandscapeWidth,
        insetBand,
        subtitleViewportScrollable
    ]
}

// MARK: - Shared

extension DivergenceCatalog {
    /// The `banner-comparable` subtitle verbatim — one line at 16pt in the 256pt column,
    /// which is what makes its 38.33pt content / 19.0pt floor the interesting pair.
    static let comparableSubtitle = "A banner the gate can actually measure."

    /// `DifferentialGeometry`'s `long-subtitle-{scrolling,unscrolled}` subtitle, verbatim:
    /// 40 repeats, 1222pt tall in the portrait card.
    static let longSubtitle = String(
        repeating: "This subtitle keeps going so the slot has to engage. ", count: 40
    ).trimmingCharacters(in: .whitespaces)

    static func entry(
        _ name: String,
        properties: GBAlertModal.Properties,
        banner: UIImage? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        primary: String? = "Okay",
        secondary: String? = nil
    ) -> DialogEntry {
        DialogEntry(name: name, category: category) {
            SampleAlertModal(
                properties: properties,
                holder: GBAlertModal.DataHolder(
                    closeOnTapOverlay: true,
                    banner: banner,
                    title: title,
                    subtitle: subtitle,
                    primaryAction: primary,
                    secondaryAction: secondary,
                    showCloseButton: false,
                    dismissOnAction: true,
                    completion: DialogCatalog.noopCompletion
                )
            )
        }
    }
}

// MARK: - D-A — tall, uncapped artwork

extension DivergenceCatalog {
    /// `bannerMaxHeight == nil` with artwork far taller than the card can hold.
    ///
    /// **`bannerRatio` NIL and `bannerMaxHeight` nil** — the natural-aspect, uncapped path,
    /// which is the fixture the 525.0pt measurement was taken on
    /// (`GeniePresets.standardPropertiesNilBannerRatio()`, `BannerGeometryTruthTests`).
    /// Spelling the ratio as the asset's own 200:2000 instead is a DIFFERENT row of that
    /// table (UIKit measures 618.33 there), so it is not used here.
    ///
    /// Rebuilt through the full initializer rather than `.copy(...)`: `Properties.copy`
    /// treats an explicitly-passed `nil` as "not provided" (`bannerRatio ?? self.bannerRatio`),
    /// so it can never clear `GalleryPresets.properties`'s `bannerRatio: 1` back to nil —
    /// the same trap `StressCatalog.entry` documents for `DataHolder.copy`. Every other field
    /// is read off the base, so this cannot drift from the preset.
    ///
    /// Internal so the SwiftUI twin's `ModalStyle` token registers THIS value rather
    /// than a second spelling of it.
    static var tallUncappedProperties: GBAlertModal.Properties {
        let base = GalleryPresets.properties
        return GBAlertModal.Properties(
            baseTint: base.baseTint,
            overlayColor: base.overlayColor,
            contentProperty: base.contentProperty,
            margin: base.margin,
            padding: base.padding,
            bannerRatio: nil,
            bannerMaxHeight: nil,
            bannerFixedHeight: base.bannerFixedHeight,
            titleFont: base.titleFont,
            titleColor: base.titleColor,
            subtitleFont: base.subtitleFont,
            subtitleColor: base.subtitleColor,
            buttonActionShouldMatchParent: base.buttonActionShouldMatchParent,
            buttonActionOrientation: base.buttonActionOrientation,
            primaryActionStyle: base.primaryActionStyle,
            secondaryActionStyle: base.secondaryActionStyle,
            closeButtonTint: base.closeButtonTint,
            space: base.space,
            contentScrollable: base.contentScrollable
        )
    }

    static var tallUncappedArtwork: DialogEntry {
        entry(
            "divergence-tall-uncapped-artwork",
            properties: tallUncappedProperties,
            banner: UIImage(named: "banner_ultratall"),
            title: "Tall uncapped artwork",
            subtitle: comparableSubtitle
        )
    }
}

// MARK: - D-B — bannerRatio is not the artwork's aspect

extension DivergenceCatalog {
    /// A 320x190pt asset forced to `bannerRatio: 1`.
    ///
    /// `GalleryPresets.properties` IS that configuration already (`bannerRatio: 1`,
    /// `bannerMaxHeight: nil`) — the divergence needs no override at all, only artwork
    /// whose own aspect is not 1.
    static var ratioNotArtworkAspect: DialogEntry {
        entry(
            "divergence-ratio-not-artwork-aspect",
            properties: GalleryPresets.properties,
            banner: UIImage(named: "banner_wide_320x190"),
            title: "Ratio vs aspect",
            subtitle: comparableSubtitle
        )
    }
}

// MARK: - `banner-wide`'s landscape column

extension DivergenceCatalog {
    /// `DifferentialGeometry`'s `banner-wide` shape, transcribed onto the gallery's presets:
    /// the popup preset with the artwork's own 320:190 ratio and a 256pt cap.
    static var bannerWideProperties: GBAlertModal.Properties {
        GalleryPresets.popupProperties.copy(bannerRatio: 320.0 / 190.0, bannerMaxHeight: 256)
    }

    static var bannerWideLandscapeWidth: DialogEntry {
        entry(
            "divergence-banner-wide-landscape-width",
            properties: bannerWideProperties,
            banner: UIImage(named: "banner_wide_320x190"),
            title: "Heads up",
            subtitle: comparableSubtitle
        )
    }
}

// MARK: - The vertical-compression band

extension DivergenceCatalog {
    /// `banner-comparable`'s shape: artwork NARROWER than the content column, so the column
    /// stays at `contentMaxWidth` and the only thing under pressure is the vertical stack.
    /// `img_badge_multi_achievement` is 160x160pt, matching the preset's square `bannerRatio`.
    static var insetBand: DialogEntry {
        entry(
            "divergence-inset-band",
            properties: GalleryPresets.properties,
            banner: UIImage(named: "img_badge_multi_achievement"),
            title: "Heads up",
            subtitle: comparableSubtitle
        )
    }
}

// MARK: - The D-7 residual: `contentScrollable`

extension DivergenceCatalog {
    /// `long-subtitle-scrolling`: the 1222pt subtitle with `contentScrollable` ON.
    ///
    /// D-7 itself is closed — with the flag OFF the two backends land on the same viewport to
    /// the point. The flag is the residual, and it is SwiftUI-only: UIKit's renderer ignores it
    /// (see `Properties.contentScrollable`), so this UIKit twin is the NON-scrolling render the
    /// SwiftUI one is compared against.
    static var scrollableProperties: GBAlertModal.Properties {
        GalleryPresets.properties.copy(contentScrollable: true)
    }

    static var subtitleViewportScrollable: DialogEntry {
        entry(
            "divergence-d7-subtitle-viewport",
            properties: scrollableProperties,
            title: "Heads up",
            subtitle: longSubtitle
        )
    }
}
