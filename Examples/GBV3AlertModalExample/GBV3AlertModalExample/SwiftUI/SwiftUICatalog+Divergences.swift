//
//  SwiftUICatalog+Divergences.swift
//  GBV3AlertModalExample
//
//  **The divergence/defect section: every KNOWN difference between the two
//  backends, as a dialog you can look at rather than a paragraph you have to
//  find.**
//
//  Each entry has a UIKit twin of the same name in `DivergenceCatalog.swift`,
//  built from the same `Properties` value (registered here as a `ModalStyle`
//  token) and the same content. Step the two galleries to the same name and the
//  difference — where there is one to see — is on the screen.
//
//  NOTHING here is a new finding. Provenance, per entry, in its caption and its
//  doc comment:
//
//   * D-A / D-B — `.superpowers/sdd/2026-08-02-swiftui-banner-geometry/progress.md`
//   * `banner-wide`'s landscape column — design spec §5, §5b, §5d, and
//     `ModalTokens.bannerGeometry`'s doc
//   * the vertical-compression band — design spec §5e
//   * the D-7 residual — design spec §5c and `DifferentialGeometrySupport`'s header
//
//  **Two of the five cannot show their divergence at this gallery's host size,
//  and their captions say so** rather than shipping an entry that looks identical
//  to its twin and reads as agreement.
//

import Foundation
import UIKit
import GBV3AlertModal

// MARK: - Style tokens

/// One token per divergence shape whose `Properties` differ from `.standard`.
/// `divergence-ratio-not-artwork-aspect` and `divergence-inset-band` need NO token: their
/// configuration IS `GalleryPresets.properties` (`bannerRatio: 1`, `bannerMaxHeight: nil`),
/// which the renderer already holds as `.standard`. That is not a shortcut — it is the finding:
/// D-B needs no unusual preset at all, only artwork whose aspect is not the stated ratio.
extension ModalStyle {
    static let divergenceTallUncapped = ModalStyle("divergence.tallUncapped")
    static let divergenceBannerWide = ModalStyle("divergence.bannerWide")
    static let divergenceScrollable = ModalStyle("divergence.scrollable")
}

extension SwiftUICatalogPresets {
    /// Every value comes from `DivergenceCatalog`, so the UIKit twin and this entry are drawn
    /// with ONE `Properties` instance's worth of configuration rather than two transcriptions.
    static var divergencePresets: [(ModalStyle, GBAlertModal.Properties)] {
        [
            (.divergenceTallUncapped, DivergenceCatalog.tallUncappedProperties),
            (.divergenceBannerWide, DivergenceCatalog.bannerWideProperties),
            (.divergenceScrollable, DivergenceCatalog.scrollableProperties)
        ]
    }
}

// MARK: - Captions
//
// Each caption says what to look for on screen and whether the difference is ACCEPTED or a
// DEFECT. Where a number was measured, the number is in the caption — a divergence entry whose
// caption says "differs somewhat" is a prose document with extra steps.

extension SwiftUIDivergence {
    static let dATallUncapped = SwiftUIDivergence(
        caption: "D-A · ACCEPTED. bannerRatio nil (natural aspect) and bannerMaxHeight nil, on "
            + "200x2000pt artwork. ModalTokens.bannerGeometry computes the artwork's FULL 2000pt "
            + "of height, where UIKit yields the slot to the RESIDUAL — measured 525.0pt at 390x844 "
            + "and 1047.0pt at 1024x1366 (BannerGeometryTruthTests). The residual is a property of "
            + "the host, not the artwork: 200x800 and 200x600 both measure 525.0 too. WHAT TO LOOK "
            + "FOR: the two should be CLOSE, not identical. BannerSlot applies the 2000 as a "
            + ".frame(maxHeight:) over a greedy Color.clear, so the SwiftUI slot yields too — but "
            + "each backend yields against its own arbitration, so the split between banner and "
            + "subtitle can land differently. Observed on a 402x874 simulator: the SwiftUI banner "
            + "runs roughly 13pt taller and its subtitle is clipped to one line where UIKit shows "
            + "two. The COLUMN is not part of it — both say 256. Accepted because no shipping asset "
            + "is in this regime: every real preset sets a bannerMaxHeight, which binds first and "
            + "makes the two agree exactly."
    )

    static let dBRatioMismatch = SwiftUIDivergence(
        caption: "D-B · DEFECT, measured and unfixed. A 320x190pt asset under bannerRatio 1 "
            + "(GalleryPresets.properties — no unusual preset needed; that IS the finding). "
            + "UIKit measures a 305.67pt content column; the SwiftUI rule computes 318 on a "
            + "390-wide host and 320 on a 1024-wide one. WHAT TO LOOK FOR: the SwiftUI card and "
            + "every row inside it about 12pt WIDER than the UIKit twin's, at the same host size "
            + "— a small difference, and the numbers above are the 390x844 reading, so on a wider "
            + "simulator expect the same SHAPE at different values. Reproduced at both columns "
            + "(256 and 300) and both hosts; a 320x320 matching-ratio control agrees exactly, so "
            + "the trigger is 'stated ratio != artwork aspect', not 'has a banner'. Cause: the "
            + "rule's demand reads the artwork's WIDTH, which is what ivBanner asks for only when "
            + "the picture fills a slot of that ratio; letterboxed under scaleAspectFit it asks "
            + "for something else and the rule cannot see it. No app preset is in this regime."
    )

    static let bannerWideLandscapeWidth = SwiftUIDivergence(
        caption: "banner-wide landscape column · DEFECT, parked. ROTATE TO LANDSCAPE — in "
            + "portrait the two agree and this row is uninteresting. UIKit's ivBanner is "
            + "height x ratio wide, so when landscape compression shrinks its height the required "
            + "width == height * ratio tie shrinks its WIDTH DEMAND too: UIKit's column never grows "
            + "past 256 where the portrait rule computes 320. 64pt out, and it reaches the CARD and "
            + "every row that matches the card's width (title, subtitle, primary button) — one root "
            + "cause, four rows. Gated on every ORIGIN and every HEIGHT at 0.5pt; WIDTH excluded, "
            + "deliberately. See landscape-width-report.md for why closing it needs a feedback pass."
    )

    static let insetBand = SwiftUIDivergence(
        caption: "Vertical-compression band · ACCEPTED, and UNMATCHABLE. CANNOT BE SHOWN HERE: it "
            + "lives at host heights 844x417...431 only, which this gallery cannot pose. Even at "
            + "those sizes there is nothing single-valued to match — UIKit's answer is "
            + "PATH-DEPENDENT. The same modal at 844x440 reports an 18.67pt top inset over a "
            + "38.33pt subtitle laid out fresh, and 24.00 over 27.33 after passing through a "
            + "smaller size: 16pt apart from identical inputs, on nineteen consecutive host "
            + "heights. Cause: svContentContainer's top padding tie and svSubtitleContainer's "
            + "height tie are BOTH defaultLow (250), so every split of a deficit costs Auto Layout "
            + "the same and the optimum is a face, not a point. SwiftUI's layout is a pure function "
            + "of (tree, proposed size) with no previous pass, and reproduces UIKit's FRESH branch. "
            + "The dialog is here so the compression itself can be watched (rotate); the band will "
            + "not reproduce by eye."
    )

    static let d7Residual = SwiftUIDivergence(
        caption: "D-7 residual · ACCEPTED. D-7 itself is CLOSED: SubtitleSlot mirrors UIKit's "
            + "svSubtitleContainer, and with contentScrollable OFF this 1222pt subtitle measures "
            + "645.33 against 645.33 in portrait and 161.33 against 161.33 in landscape. This entry "
            + "turns the flag ON, which is the residual — contentScrollable is SwiftUI-ONLY "
            + "(UIKit's renderer ignores it), and ScrollableContent wraps title AND subtitle, so "
            + "inside it the height proposal is unbounded and the subtitle slot is never pressured: "
            + "it reports the full 1222pt where UIKit's viewport is 645.3. WHAT TO LOOK FOR: HOW "
            + "MUCH subtitle each backend shows before it clips, and what scrolls — UIKit clips to "
            + "svSubtitleContainer with the title pinned above it, SwiftUI's outer ScrollableContent "
            + "carries the title too. In PORTRAIT the two look close; rotate to LANDSCAPE, where "
            + "UIKit's viewport falls to 161.33pt and SwiftUI's stays unpressured. Deciding input "
            + "for 2026-08-02-content-scrollable-review.md."
    )
}

// MARK: - The entries

extension SwiftUICatalog {
    /// Five shapes, one per recorded divergence, in the order the design spec discusses them.
    static var divergenceEntries: [SwiftUICatalogEntry] {
        let category = DivergenceCatalog.category
        return [
            // D-A — tall uncapped artwork.
            SwiftUICatalogEntry.renderable(
                "divergence-tall-uncapped-artwork",
                category: category,
                divergences: [.dATallUncapped]
            ) {
                AlertDialog(
                    image: ModalImage("banner_ultratall"),
                    title: "Tall uncapped artwork",
                    subtitle: DivergenceCatalog.comparableSubtitle,
                    primary: "Okay",
                    closeOnTapOverlay: true,
                    style: .divergenceTallUncapped
                )
            },
            // D-B — the stated ratio is not the artwork's aspect. No style token: the
            // configuration is `.standard` (GalleryPresets.properties) unchanged.
            SwiftUICatalogEntry.renderable(
                "divergence-ratio-not-artwork-aspect",
                category: category,
                divergences: [.dBRatioMismatch]
            ) {
                AlertDialog(
                    image: ModalImage("banner_wide_320x190"),
                    title: "Ratio vs aspect",
                    subtitle: DivergenceCatalog.comparableSubtitle,
                    primary: "Okay",
                    closeOnTapOverlay: true
                )
            },
            // `banner-wide`'s landscape column — the one shape the landscape gate excludes
            // a coordinate for.
            SwiftUICatalogEntry.renderable(
                "divergence-banner-wide-landscape-width",
                category: category,
                divergences: [.bannerWideLandscapeWidth]
            ) {
                AlertDialog(
                    image: ModalImage("banner_wide_320x190"),
                    title: "Heads up",
                    subtitle: DivergenceCatalog.comparableSubtitle,
                    primary: "Okay",
                    closeOnTapOverlay: true,
                    style: .divergenceBannerWide
                )
            },
            // The vertical-compression band. Same `.standard` preset as its twin; the
            // artwork is narrower than the content column so nothing but the vertical
            // stack is under pressure.
            SwiftUICatalogEntry.renderable(
                "divergence-inset-band",
                category: category,
                divergences: [.insetBand]
            ) {
                AlertDialog(
                    image: ModalImage("img_badge_multi_achievement"),
                    title: "Heads up",
                    subtitle: DivergenceCatalog.comparableSubtitle,
                    primary: "Okay",
                    closeOnTapOverlay: true
                )
            },
            // The D-7 residual: `contentScrollable`, which only this backend honours.
            SwiftUICatalogEntry.renderable(
                "divergence-d7-subtitle-viewport",
                category: category,
                divergences: [.d7Residual]
            ) {
                AlertDialog(
                    title: "Heads up",
                    subtitle: DivergenceCatalog.longSubtitle,
                    primary: "Okay",
                    closeOnTapOverlay: true,
                    style: .divergenceScrollable
                )
            }
        ]
    }
}
