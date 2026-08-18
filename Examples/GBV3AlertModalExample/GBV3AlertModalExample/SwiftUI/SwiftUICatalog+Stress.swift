//
//  SwiftUICatalog+Stress.swift
//  GBV3AlertModalExample
//
//  The SwiftUI TWIN of `StressCatalog`: the same 28 stress shapes, same `name`s,
//  same `category`s, same strings, in the same order — so the owner can step the
//  UIKit gallery and this one side by side and compare each entry against the
//  entry of the same name.
//
//  Nothing here re-types a string or a `Properties`. The content constants come
//  from `StressCatalog` itself (which is why that file's shared block is
//  internal), and the styling comes from `StressCatalog.properties(banner:orientation:)`
//  through the `ModalStyle` tokens registered in `SwiftUICatalogPresets.stressPresets`.
//  A stress matrix whose two halves disagree because someone retyped a string is
//  a matrix that measures the typing, not the layout.
//
//  ALL 28 render. Six used to be `notRenderable` for one shared reason —
//  `StandardAlertContent.primary` was a non-optional `String`, so no descriptor could
//  say "no primary button" on EITHER backend. It is `String?` as of Pass 2 and the six
//  spell `primary: nil`. The note that stood here is kept, in full, above
//  `stressEntries` below: the limit was real, and what it cost is worth remembering.
//

import Foundation
import Foundation
import GBV3AlertModalCore
import GBV3AlertModalSwiftUI

// MARK: - Style tokens

/// The stress matrix asks for exactly five presets beyond `.standard`: the
/// orientation flip, and the two ultra-aspect banners crossed with it. Each is
/// `StressCatalog.properties(banner:orientation:)` for that combination — the
/// SAME call the UIKit entry makes at its call site.
extension ModalStyle {
    static let stressHorizontal = ModalStyle("stress.horizontal")
    static let stressWideBanner = ModalStyle("stress.wideBanner")
    static let stressWideBannerHorizontal = ModalStyle("stress.wideBanner.horizontal")
    static let stressTallBanner = ModalStyle("stress.tallBanner")
    static let stressTallBannerHorizontal = ModalStyle("stress.tallBanner.horizontal")
}

// MARK: - Divergences carried by these entries

extension SwiftUIDivergence {
    /// The ultra-aspect artwork note. Narrower than `bannerArtworkNote`: these two assets are
    /// deliberately outside every regime the geometry rule was pinned against.
    static let ultraAspectBanner = SwiftUIDivergence(
        caption: "Ultra-aspect artwork (2000x200 / 200x2000pt) under a matching bannerRatio and NO "
            + "bannerMaxHeight. ModalTokens.bannerGeometry is a PORTRAIT rule, gated in portrait "
            + "only; at 200x2000 with no cap it computes the artwork's full 2000pt where UIKit "
            + "yields the slot to whatever the card has left (measured 525.0pt at 390x844). "
            + "BannerSlot's maxHeight makes SwiftUI yield too — see divergence-tall-uncapped-artwork."
    )

    /// The unbreakable-token note.
    static let unbreakableToken = SwiftUIDivergence(
        caption: "No break opportunity in this string, so neither engine can wrap it and each picks "
            + "its own fallback: UIKit's UILabel has rung-2 glyph shrinking "
            + "(ModalLayout.titleMinimumScaleFactor) plus character wrapping; SwiftUI's Text has "
            + "minimumScaleFactor and its own truncation. NOTHING gates this axis — it is here to "
            + "be looked at against the UIKit twin, not because the two are known to agree."
    )
}

// MARK: - The stress entries

extension SwiftUICatalog {
    /// **The six buttonless stress shapes render now, and `noPrimaryReason` is gone with them.**
    ///
    /// It used to read: "`StandardAlertContent.primary` is a non-optional `String`, so no descriptor
    /// can express 'no primary button'. Not a SwiftUI gap — the UIKit descriptor path can't either;
    /// the UIKit twin builds a `DataHolder` with `primaryAction: nil` directly."
    ///
    /// Every word of that was true and it is the whole reason `primary` is `String?` now (Pass 2).
    /// The six entries below spell `primary: nil` and go through the ordinary descriptor path on
    /// both backends; the UIKit twins still hand-build their `DataHolder`s, because `StressCatalog`
    /// is the frozen gallery and nothing required changing it.
    ///
    /// One thing the old note got right and is worth keeping: spelling it `primary: ""` would have
    /// been worse than useless. `showsPrimary` tests `holder.primaryAction != nil`, so an empty
    /// string draws an EMPTY BUTTON — a shape neither backend has, dressed up as a passing
    /// comparison.
    ///
    /// All 28, in `StressCatalog.entries` order.
    static var stressEntries: [SwiftUICatalogEntry] {
        stressSweepEntries
            + stressMaxedEntries
            + stressDegenerateEntries
            + stressNastyEntries
            + stressCloseButtonEntries
            + stressExtraEntries
    }

    // MARK: A. Per-axis sweep

    static var stressSweepEntries: [SwiftUICatalogEntry] {
        let category = CatalogFixtures.sweepCategory
        return [
            SwiftUICatalogEntry.renderable("stress-baseline", category: category) {
                AlertDialog(
                    title: CatalogFixtures.title10Line,
                    subtitle: CatalogFixtures.subtitle10Line,
                    primary: CatalogFixtures.primaryFull,
                    secondary: CatalogFixtures.secondaryFull,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.renderable(
                "stress-banner-ultrawide",
                category: category,
                divergences: [.bannerArtworkNote, .ultraAspectBanner]
            ) {
                AlertDialog(
                    image: ModalImage("banner_ultrawide"),
                    title: CatalogFixtures.title10Line,
                    subtitle: CatalogFixtures.subtitle10Line,
                    primary: CatalogFixtures.primaryFull,
                    secondary: CatalogFixtures.secondaryFull,
                    closeOnTapOverlay: true,
                    style: .stressWideBanner
                )
            },
            SwiftUICatalogEntry.renderable(
                "stress-banner-ultratall",
                category: category,
                divergences: [.bannerArtworkNote, .ultraAspectBanner]
            ) {
                AlertDialog(
                    image: ModalImage("banner_ultratall"),
                    title: CatalogFixtures.title10Line,
                    subtitle: CatalogFixtures.subtitle10Line,
                    primary: CatalogFixtures.primaryFull,
                    secondary: CatalogFixtures.secondaryFull,
                    closeOnTapOverlay: true,
                    style: .stressTallBanner
                )
            },
            SwiftUICatalogEntry.renderable("stress-title-none", category: category) {
                AlertDialog(
                    title: String?.none,
                    subtitle: CatalogFixtures.subtitle10Line,
                    primary: CatalogFixtures.primaryFull,
                    secondary: CatalogFixtures.secondaryFull,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.renderable("stress-subtitle-none", category: category) {
                AlertDialog(
                    title: CatalogFixtures.title10Line,
                    subtitle: String?.none,
                    primary: CatalogFixtures.primaryFull,
                    secondary: CatalogFixtures.secondaryFull,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.renderable("stress-primary-none", category: category) {
                AlertDialog(
                    title: CatalogFixtures.title10Line,
                    subtitle: CatalogFixtures.subtitle10Line,
                    primary: nil,
                    secondary: CatalogFixtures.secondaryFull,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.renderable("stress-primary-wrapped", category: category) {
                AlertDialog(
                    title: CatalogFixtures.title10Line,
                    subtitle: CatalogFixtures.subtitle10Line,
                    primary: CatalogFixtures.primaryWrapped,
                    secondary: CatalogFixtures.secondaryFull,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.renderable("stress-secondary-none", category: category) {
                AlertDialog(
                    title: CatalogFixtures.title10Line,
                    subtitle: CatalogFixtures.subtitle10Line,
                    primary: CatalogFixtures.primaryFull,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.renderable("stress-secondary-wrapped", category: category) {
                AlertDialog(
                    title: CatalogFixtures.title10Line,
                    subtitle: CatalogFixtures.subtitle10Line,
                    primary: CatalogFixtures.primaryFull,
                    secondary: CatalogFixtures.secondaryWrapped,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.renderable("stress-buttons-horizontal", category: category) {
                AlertDialog(
                    title: CatalogFixtures.title10Line,
                    subtitle: CatalogFixtures.subtitle10Line,
                    primary: CatalogFixtures.primaryFull,
                    secondary: CatalogFixtures.secondaryFull,
                    closeOnTapOverlay: true,
                    style: .stressHorizontal
                )
            },
            SwiftUICatalogEntry.renderable(
                "stress-title-unbreakable",
                category: category,
                divergences: [.unbreakableToken]
            ) {
                AlertDialog(
                    title: CatalogFixtures.titleUnbreakable,
                    subtitle: CatalogFixtures.subtitle10Line,
                    primary: CatalogFixtures.primaryFull,
                    secondary: CatalogFixtures.secondaryFull,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.renderable(
                "stress-subtitle-unbreakable",
                category: category,
                divergences: [.unbreakableToken]
            ) {
                AlertDialog(
                    title: CatalogFixtures.title10Line,
                    subtitle: CatalogFixtures.subtitleUnbreakable,
                    primary: CatalogFixtures.primaryFull,
                    secondary: CatalogFixtures.secondaryFull,
                    closeOnTapOverlay: true
                )
            }
        ]
    }

    // MARK: B. Everything maxed

    static var stressMaxedEntries: [SwiftUICatalogEntry] {
        let category = CatalogFixtures.maxedCategory
        return [
            SwiftUICatalogEntry.renderable(
                "stress-maxed-vertical",
                category: category,
                divergences: [.bannerArtworkNote, .ultraAspectBanner]
            ) {
                AlertDialog(
                    image: ModalImage("banner_ultratall"),
                    title: CatalogFixtures.title10Line,
                    subtitle: CatalogFixtures.subtitle10Line,
                    primary: CatalogFixtures.primaryWrapped,
                    secondary: CatalogFixtures.secondaryWrapped,
                    closeOnTapOverlay: true,
                    style: .stressTallBanner
                )
            },
            SwiftUICatalogEntry.renderable(
                "stress-maxed-horizontal",
                category: category,
                divergences: [.bannerArtworkNote, .ultraAspectBanner]
            ) {
                AlertDialog(
                    image: ModalImage("banner_ultratall"),
                    title: CatalogFixtures.title10Line,
                    subtitle: CatalogFixtures.subtitle10Line,
                    primary: CatalogFixtures.primaryWrapped,
                    secondary: CatalogFixtures.secondaryWrapped,
                    closeOnTapOverlay: true,
                    style: .stressTallBannerHorizontal
                )
            }
        ]
    }

    // MARK: C. Degenerate

    static var stressDegenerateEntries: [SwiftUICatalogEntry] {
        let category = CatalogFixtures.degenerateCategory
        return [
            SwiftUICatalogEntry.renderable("stress-all-none", category: category) {
                AlertDialog(
                    title: String?.none,
                    subtitle: String?.none,
                    primary: nil,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.renderable(
                "stress-banner-only",
                category: category,
                divergences: [.bannerArtworkNote, .ultraAspectBanner]
            ) {
                AlertDialog(
                    image: ModalImage("banner_ultrawide"),
                    title: String?.none,
                    subtitle: String?.none,
                    primary: nil,
                    closeOnTapOverlay: true,
                    style: .stressWideBanner
                )
            },
            SwiftUICatalogEntry.renderable("stress-buttons-only", category: category) {
                AlertDialog(
                    title: String?.none,
                    subtitle: String?.none,
                    primary: CatalogFixtures.primaryFull,
                    secondary: CatalogFixtures.secondaryFull,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.renderable("stress-title-only", category: category) {
                AlertDialog(
                    title: CatalogFixtures.title10Line,
                    subtitle: String?.none,
                    primary: nil,
                    closeOnTapOverlay: true
                )
            }
        ]
    }

    // MARK: D. Nasty interactions

    static var stressNastyEntries: [SwiftUICatalogEntry] {
        let category = CatalogFixtures.nastyCategory
        return [
            SwiftUICatalogEntry.renderable(
                "stress-nasty-widebanner-horizontal-wrapped",
                category: category,
                divergences: [.bannerArtworkNote, .ultraAspectBanner]
            ) {
                AlertDialog(
                    image: ModalImage("banner_ultrawide"),
                    title: String?.none,
                    subtitle: String?.none,
                    primary: CatalogFixtures.primaryWrapped,
                    secondary: CatalogFixtures.secondaryWrapped,
                    closeOnTapOverlay: true,
                    style: .stressWideBannerHorizontal
                )
            },
            SwiftUICatalogEntry.renderable(
                "stress-nasty-horizontal-wrapped-no-banner",
                category: category
            ) {
                AlertDialog(
                    title: String?.none,
                    subtitle: String?.none,
                    primary: CatalogFixtures.primaryWrapped,
                    secondary: CatalogFixtures.secondaryWrapped,
                    closeOnTapOverlay: true,
                    style: .stressHorizontal
                )
            },
            SwiftUICatalogEntry.renderable(
                "stress-nasty-tallbanner-subtitle",
                category: category,
                divergences: [.bannerArtworkNote, .ultraAspectBanner]
            ) {
                AlertDialog(
                    image: ModalImage("banner_ultratall"),
                    title: String?.none,
                    subtitle: CatalogFixtures.subtitle10Line,
                    primary: CatalogFixtures.primaryFull,
                    closeOnTapOverlay: true,
                    style: .stressTallBanner
                )
            }
        ]
    }

    // MARK: E. Close button

    static var stressCloseButtonEntries: [SwiftUICatalogEntry] {
        [
            SwiftUICatalogEntry.renderable(
                "stress-close-button-title",
                category: CatalogFixtures.closeButtonCategory
            ) {
                AlertDialog(
                    title: CatalogFixtures.title10Line,
                    subtitle: String?.none,
                    primary: CatalogFixtures.primaryFull,
                    closeOnTapOverlay: true,
                    showCloseButton: true
                )
            }
        ]
    }

    // MARK: F. Extra combos

    static var stressExtraEntries: [SwiftUICatalogEntry] {
        let category = CatalogFixtures.extraCategory
        return [
            // The landscape subtitle-slicing shape. Rotate to see it: this is the one title
            // short enough that UIKit's subtitle floor ALMOST holds, which is the condition
            // that draws half a line of body text under the button.
            SwiftUICatalogEntry.renderable("stress-title-4x-sliced-subtitle", category: category) {
                AlertDialog(
                    title: CatalogFixtures.title4Repeat,
                    subtitle: CatalogFixtures.subtitleOneLine,
                    primary: "Okay",
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.renderable("stress-no-buttons", category: category) {
                AlertDialog(
                    title: CatalogFixtures.title10Line,
                    subtitle: CatalogFixtures.subtitle10Line,
                    primary: nil,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.renderable("stress-two-wrapped-vertical", category: category) {
                AlertDialog(
                    title: String?.none,
                    subtitle: String?.none,
                    primary: CatalogFixtures.primaryWrapped,
                    secondary: CatalogFixtures.secondaryWrapped,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.renderable(
                "stress-widebanner-title-only",
                category: category,
                divergences: [.bannerArtworkNote, .ultraAspectBanner]
            ) {
                AlertDialog(
                    image: ModalImage("banner_ultrawide"),
                    title: CatalogFixtures.title10Line,
                    subtitle: String?.none,
                    primary: nil,
                    closeOnTapOverlay: true,
                    style: .stressWideBanner
                )
            },
            SwiftUICatalogEntry.renderable(
                "stress-close-button-horizontal-wrapped",
                category: category
            ) {
                AlertDialog(
                    title: String?.none,
                    subtitle: String?.none,
                    primary: CatalogFixtures.primaryWrapped,
                    secondary: CatalogFixtures.secondaryWrapped,
                    closeOnTapOverlay: true,
                    showCloseButton: true,
                    style: .stressHorizontal
                )
            },
            SwiftUICatalogEntry.renderable(
                "stress-maxed-widebanner-horizontal",
                category: category,
                divergences: [.bannerArtworkNote, .ultraAspectBanner]
            ) {
                AlertDialog(
                    image: ModalImage("banner_ultrawide"),
                    title: CatalogFixtures.title10Line,
                    subtitle: CatalogFixtures.subtitle10Line,
                    primary: CatalogFixtures.primaryWrapped,
                    secondary: CatalogFixtures.secondaryWrapped,
                    closeOnTapOverlay: true,
                    style: .stressWideBannerHorizontal
                )
            }
        ]
    }
}
