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
//   * `SwiftUIAlertModal`'s own doc comment (the `showsPrimary` obedience gap)
//
//  FOUR of the five are GEOMETRY — the two engines arbitrate the same constraints
//  differently. The fifth (`divergence-shows-primary-not-obeyed`) is a different
//  kind of thing: a RENDERER-OBEDIENCE gap, where the shared resolver's answer is
//  correct and one backend simply did not read it. **That fifth one is FIXED as of
//  Pass 2** — which is the point of the distinction: a geometry divergence is an
//  arbitration difference to be understood, an obedience gap is a bug to be closed.
//  The row and its shape stay so the two cards can still be stepped side by side,
//  now agreeing; the SwiftUI caption carries the before-and-after numbers.
//
//  A sixth, `divergence-d7-subtitle-viewport`, is DELETED along with the
//  `Properties.contentScrollable` flag that was its entire cause. With the flag
//  gone the two backends agree on that shape (645.33 vs 645.33 portrait, 161.33 vs
//  161.33 landscape), so there is no divergence left to display.
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
        showsPrimaryNotObeyed
    ]
}

// MARK: - Shared

extension DivergenceCatalog {
    /// The `banner-comparable` subtitle verbatim — one line at 16pt in the 256pt column,
    /// which is what makes its 38.33pt content / 19.0pt floor the interesting pair.
    static let comparableSubtitle = "A banner the gate can actually measure."

    // `longSubtitle` (40 repeats, 1222pt in the portrait card) lived here and is DELETED with its
    // only reader, `divergence-d7-subtitle-viewport`. The fixture itself survives where it is still
    // measured: `DifferentialGeometry`'s `long-subtitle-unscrolled` shape.

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
            space: base.space
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

// The D-7 residual section lived here — `scrollableProperties` (the gallery preset with
// `contentScrollable: true`) and the `divergence-d7-subtitle-viewport` entry it fed. Both are
// DELETED with the flag. D-7 is closed outright now rather than closed-with-a-residual: the
// SwiftUI `SubtitleSlot` mirrors `svSubtitleContainer` unconditionally, and the 1222pt subtitle
// measures 645.33 against 645.33 in portrait and 161.33 against 161.33 in landscape.

// MARK: - `showsPrimary` was resolved but not obeyed (CLOSED, Pass 2)

extension DivergenceCatalog {
    /// **`primaryActionStyle` NIL, with the primary action STRING still present.**
    ///
    /// That pair is the whole shape. `GBAlertModal.resolve` computes
    /// `showsPrimary = holder.primaryAction != nil && properties?.primaryActionStyle != nil`,
    /// so it answers FALSE here — correctly, and identically for both backends, since both
    /// run the same resolver over the same holder. `GBAlertModal+ViewGraph`'s
    /// `buildActionComponents` obeys it and builds no primary button, no button slot and no
    /// main-action stack at all; `AlertModalScaffold` COULD NOT obey it, because its
    /// `primaryTitle` was a non-optional `String` and `card` drew `primaryButton`
    /// unconditionally. So the divergence was not two engines arbitrating differently — it was
    /// one renderer not reading a flag.
    ///
    /// **Closed in Pass 2:** `primaryTitle` is `String?` and `SwiftUIAlertModal` passes
    /// `resolved.showsPrimary ? config.primary : nil`. This shape is kept because it is still the
    /// cleanest reachable input for the condition — and because a row that once diverged and now
    /// agrees is the evidence, not the absence of a row.
    ///
    /// Keeping the primary STRING is what makes the shape reachable: drop it and
    /// `showsPrimary` is false for the ordinary reason (no action) and the SwiftUI scaffold
    /// still has nothing sensible to draw. This is the one input where the resolver says "no
    /// button" while a button title is sitting right there.
    ///
    /// No SECONDARY action, deliberately: with one absent it is the button RUN that vanishes
    /// on the UIKit side, which is the clearest thing to look at. A secondary would leave a
    /// button on both sides and turn a presence difference into a counting exercise.
    ///
    /// Rebuilt through the full initializer rather than `.copy(...)` for exactly the reason
    /// `tallUncappedProperties` above is: `Properties.copy` reads an explicit `nil` as "not
    /// provided" (`primaryActionStyle ?? self.primaryActionStyle`), so it can never clear
    /// `GalleryPresets.properties`'s `.obliqueBottomLeft(...)` back to nil. Every other field
    /// is read off the base, so this cannot drift from the preset.
    ///
    /// One thing this shape does NOT show, and it is worth knowing before looking for it:
    /// `ModalTokens.init(from:)` only reads button colours out of an `.obliqueBottomLeft`
    /// style, so with no style at all the SwiftUI button keeps `ModalTokens.standard`'s
    /// literal accent — `0xF7941E`, which is exactly
    /// `GalleryColor.accentSecondaryDark`, the colour this preset's theme supplies anyway. The
    /// phantom button is therefore fully styled and indistinguishable from a legitimate one.
    /// Its PRESENCE is the entire tell.
    static var nilPrimaryStyleProperties: GBAlertModal.Properties {
        let base = GalleryPresets.properties
        return GBAlertModal.Properties(
            baseTint: base.baseTint,
            overlayColor: base.overlayColor,
            contentProperty: base.contentProperty,
            margin: base.margin,
            padding: base.padding,
            bannerRatio: base.bannerRatio,
            bannerMaxHeight: base.bannerMaxHeight,
            bannerFixedHeight: base.bannerFixedHeight,
            titleFont: base.titleFont,
            titleColor: base.titleColor,
            subtitleFont: base.subtitleFont,
            subtitleColor: base.subtitleColor,
            buttonActionShouldMatchParent: base.buttonActionShouldMatchParent,
            buttonActionOrientation: base.buttonActionOrientation,
            primaryActionStyle: nil,
            secondaryActionStyle: base.secondaryActionStyle,
            closeButtonTint: base.closeButtonTint,
            space: base.space
        )
    }

    /// No banner: the divergence is in the button run, and artwork would only add a second
    /// variable to a card whose whole point is what is missing from the bottom of it.
    static var showsPrimaryNotObeyed: DialogEntry {
        entry(
            "divergence-shows-primary-not-obeyed",
            properties: nilPrimaryStyleProperties,
            title: "No primary style",
            subtitle: comparableSubtitle
        )
    }
}
