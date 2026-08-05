//
//  SwiftUICatalog+Variants.swift
//  GBV3AlertModalExample
//
//  The SwiftUI twin of `Gallery/VariantsCatalog.swift` — every title/subtitle
//  representation and every `GBAlertModal.ActionStyle` case, name-for-name with the
//  UIKit side so the two galleries can be compared row by row.
//
//  THREE of the eleven are `notRenderable`, and all three for the same reason: the
//  UIKit entry reaches PAST the descriptor. `variant-subtitle-customview` hands the
//  holder a live `UIView`; the two button-state entries call
//  `changePrimaryActionEnableState` / `changeSecondaryActionEnableState` on the modal
//  AFTER `init` has built the view graph. A `ModalDescriptor` is a `Sendable` value —
//  it carries no view and has no post-construction hook — so neither backend can
//  express these THROUGH a descriptor. This is a descriptor-vocabulary limit, not a
//  SwiftUI one, and the same limit produces the six `notRenderable` stress twins and
//  the `showsPrimary` divergence.
//
//  `notRenderable` rather than an approximation on purpose: an entry that renders
//  something adjacent looks like agreement and is worse than an honest gap.
//

import Foundation
import SwiftUI
import UIKit
import GBV3AlertModal

// MARK: - Title representations

extension SwiftUICatalog {
    static var variantTitleEntries: [SwiftUICatalogEntry] {
        [
            SwiftUICatalogEntry.renderable("variant-title-plain", category: "Variant · Title") {
                AlertDialog(
                    title: "Plain String Title",
                    subtitle: "This dialog's title is a plain `String` — set via `DataHolder.title`.",
                    primary: "Okay",
                    closeOnTapOverlay: true
                )
            },
            // The UIKit twin builds an `NSAttributedString` with per-span colours and fonts.
            // `AlertDialog.title` is an `AttributedString`, so the spans survive — but see the
            // divergence: an AMBIENT `.foregroundColor` on an `AttributedString` binds to the
            // SwiftUI attribute scope, which the UIKit renderer does not read, so it draws
            // unstyled. Per-run attributes (below) are what both backends agree on.
            SwiftUICatalogEntry.renderable(
                "variant-title-attributed",
                category: "Variant · Title",
                divergences: [.attributedRuns]
            ) {
                var accent = AttributedString("Attributed ")
                accent.foregroundColor = .orange
                accent.font = .system(size: 24, weight: .heavy)

                var rest = AttributedString("Title")
                rest.foregroundColor = .purple
                rest.font = .system(size: 24, weight: .bold)

                return AlertDialog(
                    title: accent + rest,
                    subtitle: "This dialog's title is an `AttributedString` — set via "
                        + "`AlertDialog.title` — with mixed colors and weights across spans.",
                    primary: "Okay",
                    closeOnTapOverlay: true
                )
            }
        ]
    }
}

// MARK: - Subtitle representations

extension SwiftUICatalog {
    static var variantSubtitleEntries: [SwiftUICatalogEntry] {
        [
            SwiftUICatalogEntry.renderable("variant-subtitle-plain", category: "Variant · Subtitle") {
                AlertDialog(
                    title: "Plain String Subtitle",
                    subtitle: "This dialog's subtitle is a plain `String` — set via "
                        + "`DataHolder.subtitle`.",
                    primary: "Okay",
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.renderable(
                "variant-subtitle-attributed",
                category: "Variant · Subtitle",
                divergences: [.attributedRuns]
            ) {
                var lead = AttributedString("Attributed subtitle ")
                lead.foregroundColor = .orange
                lead.font = .system(size: 16, weight: .bold)

                var rest = AttributedString(
                    "with mixed colors and weights across spans, set via `AlertDialog.subtitle`."
                )
                rest.foregroundColor = .secondary

                return AlertDialog(
                    title: "Attributed Subtitle",
                    subtitle: lead + rest,
                    primary: "Okay",
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.notRenderable(
                "variant-subtitle-customview",
                category: "Variant · Subtitle",
                reason: "The UIKit entry sets `DataHolder.subtitleCustomView` to a live, bordered "
                    + "`UIView`. `ModalDescriptor` is a `Sendable` value type and cannot carry a "
                    + "view, so NEITHER backend can express this through a descriptor — the UIKit "
                    + "twin bypasses the descriptor path entirely. The bespoke-view route "
                    + "(`SwiftUIModalRenderer.register(_:view:)`) is how a real caller would do "
                    + "this; see the `badge-detail-popup` entry for a worked example."
            )
        ]
    }
}

// MARK: - Button styles

extension SwiftUICatalog {
    static var variantButtonStyleEntries: [SwiftUICatalogEntry] {
        [
            SwiftUICatalogEntry.renderable(
                "variant-button-capsule", category: "Variant · Button Style"
            ) {
                AlertDialog(
                    title: "Button Style · Capsule",
                    subtitle: "primaryActionStyle: .capsule(GalleryPresets.capsuleTheme)",
                    primary: "Capsule Button",
                    closeOnTapOverlay: true,
                    style: .variantCapsule
                )
            },
            SwiftUICatalogEntry.renderable(
                "variant-button-capsuleOutlined", category: "Variant · Button Style"
            ) {
                AlertDialog(
                    title: "Button Style · Capsule Outlined",
                    subtitle: "primaryActionStyle: "
                        + ".capsuleOutlined(GalleryPresets.capsuleOutlinedTheme)",
                    primary: "Capsule Outlined",
                    closeOnTapOverlay: true,
                    style: .variantCapsuleOutlined
                )
            },
            SwiftUICatalogEntry.renderable(
                "variant-button-plain", category: "Variant · Button Style"
            ) {
                AlertDialog(
                    title: "Button Style · Plain",
                    subtitle: "primaryActionStyle: .plain(GalleryPresets.plainTheme)",
                    primary: "Plain Button",
                    closeOnTapOverlay: true,
                    style: .variantPlain
                )
            },
            SwiftUICatalogEntry.renderable(
                "variant-button-oblique", category: "Variant · Button Style"
            ) {
                AlertDialog(
                    title: "Button Style · Oblique Bottom Left",
                    subtitle: "primaryActionStyle: "
                        + ".obliqueBottomLeft(GalleryPresets.obliqueBottomLeftTheme)",
                    primary: "Oblique Button",
                    closeOnTapOverlay: true,
                    style: .variantOblique
                )
            }
        ]
    }
}

// MARK: - Button enabled/disabled state

extension SwiftUICatalog {
    /// Both entries are `notRenderable` for the SAME reason, and it is worth stating once:
    /// the UIKit twins call `changeSecondaryActionEnableState` / `changePrimaryActionEnableState`
    /// on the modal AFTER `init(properties:holder:)` has built the view graph — the buttons do
    /// not exist before that. A descriptor has no post-construction hook.
    ///
    /// `SwiftUIAlertModal` DOES carry a `primaryEnabled` flag (see `SatisfactionDemoView`), so
    /// the SwiftUI backend can express a disabled primary — just not through the descriptor
    /// path this catalog renders. There is no `secondaryEnabled` counterpart at all.
    static var variantButtonStateEntries: [SwiftUICatalogEntry] {
        [
            SwiftUICatalogEntry.notRenderable(
                "variant-button-states",
                category: "Variant · Button State",
                reason: "The UIKit twin calls `changeSecondaryActionEnableState(isEnable: false)` "
                    + "after construction. A `ModalDescriptor` has no post-construction hook, and "
                    + "`SwiftUIAlertModal` has no `secondaryEnabled` flag to carry it — so this "
                    + "shape is unreachable from the descriptor path on either backend."
            ),
            SwiftUICatalogEntry.notRenderable(
                "variant-button-primary-disabled",
                category: "Variant · Button State",
                reason: "The UIKit twin calls `changePrimaryActionEnableState(isEnable: false)` "
                    + "after construction. `SwiftUIAlertModal.primaryEnabled` CAN express this "
                    + "(see `SatisfactionDemoView`), but the descriptor path this catalog renders "
                    + "has no way to set it — a descriptor carries content and style, not "
                    + "presentation state."
            )
        ]
    }
}

// MARK: - The section

extension SwiftUICatalog {
    /// The eleven variant twins, in `VariantsCatalog.entries` order.
    static var variantEntries: [SwiftUICatalogEntry] {
        variantTitleEntries
            + variantSubtitleEntries
            + variantButtonStyleEntries
            + variantButtonStateEntries
    }
}
