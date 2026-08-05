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
//  SIX entries are `notRenderable`, and the reason is the same one for all six —
//  see `SwiftUICatalog.noPrimaryReason`. It is a DESCRIPTOR-VOCABULARY limit, not
//  a SwiftUI one, and the gallery shows it rather than dropping the rows.
//

import Foundation
import UIKit
import GBV3AlertModal

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

extension SwiftUICatalogPresets {
    /// Registered alongside `stylePresets`. `.standard` is already seeded by
    /// `SwiftUIModalRenderer.init` with `GalleryPresets.properties`, which is exactly what
    /// `StressCatalog.properties(banner: .none, orientation: .vertical)` returns, so the
    /// no-banner vertical shapes need no token of their own.
    static var stressPresets: [(ModalStyle, GBAlertModal.Properties)] {
        [
            (.stressHorizontal, StressCatalog.properties(banner: .none, orientation: .horizontal)),
            (.stressWideBanner, StressCatalog.properties(banner: .wide, orientation: .vertical)),
            (.stressWideBannerHorizontal, StressCatalog.properties(banner: .wide, orientation: .horizontal)),
            (.stressTallBanner, StressCatalog.properties(banner: .tall, orientation: .vertical)),
            (.stressTallBannerHorizontal, StressCatalog.properties(banner: .tall, orientation: .horizontal))
        ]
    }
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
    /// The reason all six buttonless stress shapes are `notRenderable`.
    ///
    /// **Not a renderer gap.** `StandardAlertContent.primary` is a non-optional `String`, so
    /// `AlertDialog` — and every other descriptor in the standard family — structurally cannot
    /// say "no primary button". `UIKitModalRenderer.AlertHolder.make` passes `descriptor.primary`
    /// straight into `DataHolder.primaryAction`, so the UIKit DESCRIPTOR path cannot express it
    /// either; the UIKit gallery entry sidesteps the descriptors entirely and builds a
    /// `DataHolder` with `primaryAction: nil` by hand (see `StressCatalog.entry`).
    ///
    /// Spelling it `primary: ""` would be worse than useless: `showsPrimary` is
    /// `holder.primaryAction != nil`, so an empty string draws an EMPTY BUTTON — a shape neither
    /// backend has, dressed up as a passing comparison.
    static let noPrimaryReason =
        "StandardAlertContent.primary is a non-optional String, so no descriptor can express "
        + "'no primary button'. Not a SwiftUI gap — the UIKit descriptor path can't either; the "
        + "UIKit twin builds a DataHolder with primaryAction: nil directly."

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
        let category = StressCatalog.sweepCategory
        return [
            SwiftUICatalogEntry.renderable("stress-baseline", category: category) {
                AlertDialog(
                    title: StressCatalog.title10Line,
                    subtitle: StressCatalog.subtitle10Line,
                    primary: StressCatalog.primaryFull,
                    secondary: StressCatalog.secondaryFull,
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
                    title: StressCatalog.title10Line,
                    subtitle: StressCatalog.subtitle10Line,
                    primary: StressCatalog.primaryFull,
                    secondary: StressCatalog.secondaryFull,
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
                    title: StressCatalog.title10Line,
                    subtitle: StressCatalog.subtitle10Line,
                    primary: StressCatalog.primaryFull,
                    secondary: StressCatalog.secondaryFull,
                    closeOnTapOverlay: true,
                    style: .stressTallBanner
                )
            },
            SwiftUICatalogEntry.renderable("stress-title-none", category: category) {
                AlertDialog(
                    title: String?.none,
                    subtitle: StressCatalog.subtitle10Line,
                    primary: StressCatalog.primaryFull,
                    secondary: StressCatalog.secondaryFull,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.renderable("stress-subtitle-none", category: category) {
                AlertDialog(
                    title: StressCatalog.title10Line,
                    subtitle: String?.none,
                    primary: StressCatalog.primaryFull,
                    secondary: StressCatalog.secondaryFull,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.notRenderable(
                "stress-primary-none", category: category, reason: noPrimaryReason
            ),
            SwiftUICatalogEntry.renderable("stress-primary-wrapped", category: category) {
                AlertDialog(
                    title: StressCatalog.title10Line,
                    subtitle: StressCatalog.subtitle10Line,
                    primary: StressCatalog.primaryWrapped,
                    secondary: StressCatalog.secondaryFull,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.renderable("stress-secondary-none", category: category) {
                AlertDialog(
                    title: StressCatalog.title10Line,
                    subtitle: StressCatalog.subtitle10Line,
                    primary: StressCatalog.primaryFull,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.renderable("stress-secondary-wrapped", category: category) {
                AlertDialog(
                    title: StressCatalog.title10Line,
                    subtitle: StressCatalog.subtitle10Line,
                    primary: StressCatalog.primaryFull,
                    secondary: StressCatalog.secondaryWrapped,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.renderable("stress-buttons-horizontal", category: category) {
                AlertDialog(
                    title: StressCatalog.title10Line,
                    subtitle: StressCatalog.subtitle10Line,
                    primary: StressCatalog.primaryFull,
                    secondary: StressCatalog.secondaryFull,
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
                    title: StressCatalog.titleUnbreakable,
                    subtitle: StressCatalog.subtitle10Line,
                    primary: StressCatalog.primaryFull,
                    secondary: StressCatalog.secondaryFull,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.renderable(
                "stress-subtitle-unbreakable",
                category: category,
                divergences: [.unbreakableToken]
            ) {
                AlertDialog(
                    title: StressCatalog.title10Line,
                    subtitle: StressCatalog.subtitleUnbreakable,
                    primary: StressCatalog.primaryFull,
                    secondary: StressCatalog.secondaryFull,
                    closeOnTapOverlay: true
                )
            }
        ]
    }

    // MARK: B. Everything maxed

    static var stressMaxedEntries: [SwiftUICatalogEntry] {
        let category = StressCatalog.maxedCategory
        return [
            SwiftUICatalogEntry.renderable(
                "stress-maxed-vertical",
                category: category,
                divergences: [.bannerArtworkNote, .ultraAspectBanner]
            ) {
                AlertDialog(
                    image: ModalImage("banner_ultratall"),
                    title: StressCatalog.title10Line,
                    subtitle: StressCatalog.subtitle10Line,
                    primary: StressCatalog.primaryWrapped,
                    secondary: StressCatalog.secondaryWrapped,
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
                    title: StressCatalog.title10Line,
                    subtitle: StressCatalog.subtitle10Line,
                    primary: StressCatalog.primaryWrapped,
                    secondary: StressCatalog.secondaryWrapped,
                    closeOnTapOverlay: true,
                    style: .stressTallBannerHorizontal
                )
            }
        ]
    }

    // MARK: C. Degenerate

    static var stressDegenerateEntries: [SwiftUICatalogEntry] {
        let category = StressCatalog.degenerateCategory
        return [
            SwiftUICatalogEntry.notRenderable(
                "stress-all-none", category: category, reason: noPrimaryReason
            ),
            SwiftUICatalogEntry.notRenderable(
                "stress-banner-only", category: category, reason: noPrimaryReason
            ),
            SwiftUICatalogEntry.renderable("stress-buttons-only", category: category) {
                AlertDialog(
                    title: String?.none,
                    subtitle: String?.none,
                    primary: StressCatalog.primaryFull,
                    secondary: StressCatalog.secondaryFull,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.notRenderable(
                "stress-title-only", category: category, reason: noPrimaryReason
            )
        ]
    }

    // MARK: D. Nasty interactions

    static var stressNastyEntries: [SwiftUICatalogEntry] {
        let category = StressCatalog.nastyCategory
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
                    primary: StressCatalog.primaryWrapped,
                    secondary: StressCatalog.secondaryWrapped,
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
                    primary: StressCatalog.primaryWrapped,
                    secondary: StressCatalog.secondaryWrapped,
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
                    subtitle: StressCatalog.subtitle10Line,
                    primary: StressCatalog.primaryFull,
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
                category: StressCatalog.closeButtonCategory
            ) {
                AlertDialog(
                    title: StressCatalog.title10Line,
                    subtitle: String?.none,
                    primary: StressCatalog.primaryFull,
                    closeOnTapOverlay: true,
                    showCloseButton: true
                )
            }
        ]
    }

    // MARK: F. Extra combos

    static var stressExtraEntries: [SwiftUICatalogEntry] {
        let category = StressCatalog.extraCategory
        return [
            // The landscape subtitle-slicing shape. Rotate to see it: this is the one title
            // short enough that UIKit's subtitle floor ALMOST holds, which is the condition
            // that draws half a line of body text under the button.
            SwiftUICatalogEntry.renderable("stress-title-4x-sliced-subtitle", category: category) {
                AlertDialog(
                    title: StressCatalog.title4Repeat,
                    subtitle: StressCatalog.subtitleOneLine,
                    primary: "Okay",
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.notRenderable(
                "stress-no-buttons", category: category, reason: noPrimaryReason
            ),
            SwiftUICatalogEntry.renderable("stress-two-wrapped-vertical", category: category) {
                AlertDialog(
                    title: String?.none,
                    subtitle: String?.none,
                    primary: StressCatalog.primaryWrapped,
                    secondary: StressCatalog.secondaryWrapped,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.notRenderable(
                "stress-widebanner-title-only", category: category, reason: noPrimaryReason
            ),
            SwiftUICatalogEntry.renderable(
                "stress-close-button-horizontal-wrapped",
                category: category
            ) {
                AlertDialog(
                    title: String?.none,
                    subtitle: String?.none,
                    primary: StressCatalog.primaryWrapped,
                    secondary: StressCatalog.secondaryWrapped,
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
                    title: StressCatalog.title10Line,
                    subtitle: StressCatalog.subtitle10Line,
                    primary: StressCatalog.primaryWrapped,
                    secondary: StressCatalog.secondaryWrapped,
                    closeOnTapOverlay: true,
                    style: .stressWideBannerHorizontal
                )
            }
        ]
    }
}
