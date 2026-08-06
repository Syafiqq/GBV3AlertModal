//
//  SwiftUICatalog+Variants.swift
//  GBV3AlertModalExample
//
//  The SwiftUI twin of `Gallery/VariantsCatalog.swift` — every title/subtitle
//  representation and every `GBAlertModal.ActionStyle` case, name-for-name with the
//  UIKit side so the two galleries can be compared row by row.
//
//  ONE of the eleven is `notRenderable`, down from three (Pass 2). All three used to
//  fail the same way — the UIKit entry reaches PAST the descriptor — but that was two
//  different limits wearing one description, and they have different answers:
//
//   * NO POST-CONSTRUCTION HOOK (the two button-state entries). Fixed. `AlertDialog`
//     carries `primaryEnabled`/`secondaryEnabled` and `update(_:to:)` was already the
//     channel; see `ButtonEnablement`.
//   * CANNOT CARRY A VIEW (`variant-subtitle-customview`). NOT fixed, deliberately —
//     `ModalDescriptor: Sendable` is the thing being protected, and the bespoke-view
//     route already serves the real use case. See that entry's own reason.
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
                reason: "WON'T FIX, not can't — the only row here that is a decision. The UIKit "
                    + "entry sets `DataHolder.subtitleCustomView` to a live, bordered `UIView`, and "
                    + "`ModalDescriptor` is `Sendable` precisely so descriptors can cross actor "
                    + "boundaries (it is why `ModalImage` carries an asset NAME and not a "
                    + "`UIImage`). Making a descriptor carry a view would trade that for one "
                    + "gallery row. The bespoke-view route "
                    + "(`SwiftUIModalRenderer.register(_:view:)`) already covers the real use case "
                    + "— see the `badge-detail-popup` entry for a worked example."
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
    /// **Both entries render now (Pass 2), and the reason they could not is worth keeping.**
    ///
    /// It was: the UIKit twins call `changeSecondaryActionEnableState` /
    /// `changePrimaryActionEnableState` on the modal AFTER `init(properties:holder:)` has built the
    /// view graph — the buttons do not exist before that — and "a descriptor carries content and
    /// style, not presentation state."
    ///
    /// That last clause is what changed, and it was already untrue: `LoadingDialog.isLoading` is
    /// presentation state on a descriptor and has been since it shipped. `AlertDialog` carries
    /// `primaryEnabled`/`secondaryEnabled` (`ButtonEnablement`), and no new channel was needed —
    /// `update(_:to:)` already rebuilt a live presentation on both backends, so the UIKit renderer
    /// makes those same two calls after its rebuild and the SwiftUI one passes the flags into
    /// `AlertModalScaffold`. `secondaryEnabled` did not exist on the SwiftUI side at all and was
    /// added with them.
    ///
    /// These entries present the DISABLED state directly rather than presenting-then-updating: the
    /// gallery is a shape catalog, and the shape is what the row is for. `ButtonEnablementTests`
    /// covers the update path, in both directions, on both backends.
    static var variantButtonStateEntries: [SwiftUICatalogEntry] {
        [
            SwiftUICatalogEntry.renderable(
                "variant-button-states", category: "Variant · Button State"
            ) {
                AlertDialog(
                    title: "Disabled Secondary",
                    subtitle: "The secondary action is present but not tappable.",
                    primary: "Okay",
                    secondary: "Cancel",
                    secondaryEnabled: false,
                    closeOnTapOverlay: true
                )
            },
            SwiftUICatalogEntry.renderable(
                "variant-button-primary-disabled", category: "Variant · Button State"
            ) {
                AlertDialog(
                    title: "Disabled Primary",
                    subtitle: "The primary action is present but not tappable.",
                    primary: "Okay",
                    secondary: "Cancel",
                    primaryEnabled: false,
                    closeOnTapOverlay: true
                )
            }
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
