//
//  SwiftUICatalog.swift
//  GBV3AlertModalExample
//
//  The SwiftUI TWIN of `DialogCatalog`: the same 26 real Geniebook dialog
//  shapes, expressed as EXECUTOR DESCRIPTORS (`AlertDialog` + a `ModalStyle`,
//  `TextInputDialog`, `DatePickerDialog`, and the bespoke `BadgeDialog` /
//  `LoadingDialog` ports) and presented through
//  `DefaultModalExecutor` → `SwiftUIModalRenderer` → `ModalHost`.
//
//  Entry `name`s are IDENTICAL to their `DialogCatalog` counterparts (e.g.
//  `"badge-unlock-multi"`), so the UIKit gallery and this one are comparable
//  entry-for-entry — that is the whole point of the screen: the owner steps the
//  same shape on both backends and looks at them.
//
//  CONTENT is transcribed from `DialogCatalog+*.swift` (which is itself mined
//  from `docs/superpowers/specs/2026-07-21-dialog-catalog.md`); `[API]`
//  placeholders are kept verbatim. STYLING comes from `GalleryPresets` — the
//  citation-backed mirror of the app's `Presentation.UiKit.V3AlertModal`
//  preset — reached through `ModalStyle` tokens registered on the renderer
//  (see `SwiftUICatalogPresets`).
//
//  NOTHING here is tuned to make a shape look right. Where the SwiftUI render is
//  KNOWN to differ from the UIKit one, the difference is declared as a
//  `SwiftUIDivergence` and shown in the UI rather than papered over.
//

import SwiftUI
import UIKit
import GBV3AlertModal

// MARK: - Style tokens

/// The style presets the 26 shapes ask for. The library ships only `.standard`
/// and `.popup`; everything else is a CONSUMER preset, which is exactly the
/// claim `ModalStyle` makes ("Extend it from the app side"). This block is that
/// extension, written the way the real app would write it, and every token is
/// mapped to a `GBAlertModal.Properties` in `SwiftUICatalogPresets`.
extension ModalStyle {
    static let geniePermissionAlert = ModalStyle("genie.permissionAlert")
    static let genieObliqueRed = ModalStyle("genie.obliqueRed")
    static let genieErrorBanner = ModalStyle("genie.errorBanner")
    static let genieForceUpdateBanner = ModalStyle("genie.forceUpdateBanner")
    static let genieCapBanner = ModalStyle("genie.capBanner")
    static let genieQuizBanner = ModalStyle("genie.quizBanner")
    static let genieTrialBanner = ModalStyle("genie.trialBanner")
    static let genieAiNotesBanner = ModalStyle("genie.aiNotesBanner")
    static let genieCreditDeduction = ModalStyle("genie.creditDeduction")
    static let genieStreak = ModalStyle("genie.streak")
    static let genieTimerBanner = ModalStyle("genie.timerBanner")
    static let genieExitWorksheetBanner = ModalStyle("genie.exitWorksheetBanner")
    static let genieRenameInput = ModalStyle("genie.renameInput")
    static let genieDatePickerInput = ModalStyle("genie.datePickerInput")
    static let genieBadgeUnlock = ModalStyle("genie.badgeUnlock")
    static let genieBadgeMulti = ModalStyle("genie.badgeMulti")
    static let genieBadgeDetail = ModalStyle("genie.badgeDetail")
}

// MARK: - Divergences

/// A KNOWN difference between what this SwiftUI entry draws and what its UIKit
/// twin draws, surfaced in the gallery UI so nobody has to remember it.
///
/// This exists because the failure this whole screen guards against is
/// "snapshots green, card visibly wrong". A divergence that lives only in a doc
/// comment is a divergence nobody looking at the screen will know about.
struct SwiftUIDivergence: Hashable {
    let caption: String

    /// True of EVERY entry — rendered once in the screen's header rather than
    /// repeated on 26 rows.
    static let global: [SwiftUIDivergence] = [
        SwiftUIDivergence(
            caption: "No animation. SwiftUI presents and tears down instantly; the UIKit gallery animates."
        ),
        SwiftUIDivergence(
            caption: "Banner artwork + geometry. SwiftUI resolves the asset by NAME (Image(_:)) and sizes the slot "
                + "with ModalBannerGeometry; UIKit passes a real UIImage and lets constraint priorities decide. "
                + "Same inputs, different layout engines — compare every banner shape side by side."
        ),
        SwiftUIDivergence(
            caption: "Fonts. Title/subtitle/button fonts DO flow from the same Properties (UIFont→Font bridge over "
                + "the bundled OpenSans stand-in for SHSans). Per-RUN fonts inside attributed text do NOT: "
                + "SwiftUI's Text ignores UIKit-scoped attributes, so those runs fall back to the system font."
        ),
        SwiftUIDivergence(
            caption: "Orientation. SwiftUIModalRenderer pins isLandscape: false, so the resolver always takes the "
                + "portrait reading."
        )
    ]

    static let attributedRuns = SwiftUIDivergence(
        caption: "Attributed text: the bold/colour RUNS are UIKit-scoped, so SwiftUI draws them unstyled."
    )
    static let bespokePort = SwiftUIDivergence(
        caption: "Bespoke port: drawn by a register(_:view:) body, where the UIKit entry builds a UIView and hands "
            + "it to holder.subtitleCustomView."
    )
    static let bannerArtworkNote = SwiftUIDivergence(
        caption: "Banner shape: same asset name as the UIKit entry, but drawn by Image(_:) + ModalBannerGeometry. "
            + "Check the height, aspect and cropping against the UIKit gallery entry of the same name."
    )
    static let badgeBannerMissing = SwiftUIDivergence(
        caption: "No banner drawn: the UIKit entry's banner is a GENERATED placeholder standing in for the [API] "
            + "per-record badge artwork, and ModalImage can carry only an asset NAME — so this entry carries none."
    )
    static let badgeArtworkMissing = SwiftUIDivergence(
        caption: "Badge artwork is [API] (badge.localImageName): no such asset in this bundle, so the badge cell "
            + "draws its name and description with no picture."
    )
    static let inputChrome = SwiftUIDivergence(
        caption: "Input chrome: SwiftUI draws a RoundedBorderTextFieldStyle field / wheel DatePicker; the UIKit entry "
            + "builds a 48pt bordered UITextView / UIDatePicker in the subtitle slot."
    )
    static let subtitleSlotNone = SwiftUIDivergence(
        caption: "Subtitle slot resolves .none here — bespoke content lives in Presentation.customContent, and no "
            + "empty UIView is fabricated on the holder just to make the resolver say .custom."
    )
    static let datePickerRange = SwiftUIDivergence(
        caption: "No date RANGE: DatePickerDialog carries only an initial date, where the UIKit entry pins "
            + "minimumDate = tomorrow and maximumDate = +2 years."
    )
    static let loadingPort = SwiftUIDivergence(
        caption: "Ported to LoadingDialog, which additionally carries a busy-primary state the UIKit gallery entry "
            + "has no way to ask for (shown here in its resting state, as the catalog does)."
    )
}

// MARK: - Entry

/// One demo-able SwiftUI shape: the same `name`/`category` its `DialogCatalog`
/// twin carries, a `present` closure that drives it through the executor, and
/// the honesty fields the gallery renders.
struct SwiftUICatalogEntry: Identifiable {
    var id: String { name }

    let name: String
    let category: String
    /// Non-nil = this shape has NO SwiftUI presentation yet. The gallery still
    /// lists it, marked "not yet renderable: <reason>" — a gallery that quietly
    /// lists 23 of 26 is worse than one that shows 26 with 3 marked broken.
    let notRenderableReason: String?
    let divergences: [SwiftUIDivergence]
    /// `nil` iff `notRenderableReason` is non-nil. Returns a short description of
    /// the descriptor's own result, shown in the traversal pill.
    ///
    /// Takes the CONCRETE `DefaultModalExecutor` rather than `any ModalExecutor`:
    /// this closure is stored in a `@MainActor` value and awaited from a `Task`,
    /// and a concrete `@MainActor final class` is unambiguously `Sendable` where a
    /// main-actor-isolated existential is not. Nothing in the body depends on the
    /// concrete type — it only calls the `ModalExecutor` front door.
    let present: (@MainActor (DefaultModalExecutor) async -> String)?

    /// The ordinary case: present `descriptor` and stringify whatever result the
    /// descriptor's own vocabulary resolves with.
    static func renderable<D: ModalDescriptor>(
        _ name: String,
        category: String,
        divergences: [SwiftUIDivergence] = [],
        descriptor: @escaping @MainActor () -> D
    ) -> SwiftUICatalogEntry {
        SwiftUICatalogEntry(
            name: name,
            category: category,
            notRenderableReason: nil,
            divergences: divergences,
            present: { executor in
                let result = await executor.presentAndWait(descriptor())
                return String(describing: result)
            }
        )
    }

    /// The honest case: a shape that cannot be presented on this backend yet.
    /// Kept in the list, visibly broken, never silently dropped.
    static func notRenderable(
        _ name: String,
        category: String,
        reason: String
    ) -> SwiftUICatalogEntry {
        SwiftUICatalogEntry(
            name: name,
            category: category,
            notRenderableReason: reason,
            divergences: [],
            present: nil
        )
    }
}

// MARK: - The catalog

@MainActor
enum SwiftUICatalog {
    /// All 26 shapes, in `DialogCatalog.entries` order (cross-cutting, worksheet,
    /// GenieClass, campaign, working-space, badges) so the two galleries step in
    /// lockstep. `SwiftUIDemoScreenSmokeTests` pins this list against
    /// `DialogCatalog.entries` name-for-name and order-for-order.
    static let entries: [SwiftUICatalogEntry] =
        crossCuttingEntries
            + worksheetEntries
            + genieClassEntries
            + campaignEntries
            + workingSpaceEntries
            + badgeEntries

    static func index(ofEntryNamed name: String) -> Int? {
        entries.firstIndex { $0.name == name }
    }

    // MARK: Renderer

    /// A renderer carrying every preset, factory and SwiftUI body the 26 shapes
    /// need — the app-side equivalent of the modal setup a real screen would do
    /// once at composition time.
    ///
    /// Structurally identical to `GalleryViewController.openTier0Demo`'s UIKit
    /// registration, which is the point: a consumer's preset table and holder
    /// factories are portable between the two backends verbatim.
    static func makeRenderer() -> SwiftUIModalRenderer {
        let renderer = SwiftUIModalRenderer(
            alertProperties: GalleryPresets.properties,
            popupProperties: GalleryPresets.popupProperties
        )
        for (style, properties) in SwiftUICatalogPresets.stylePresets {
            renderer.register(style: style, properties: properties)
        }
        registerInputDialogs(on: renderer)
        registerBespokeContent(on: renderer)
        return renderer
    }

    /// The two input descriptors the library ships. Each gets BOTH a factory
    /// (descriptor → `Properties` + `DataHolder`, so the presentation resolves a
    /// real structure and real tokens) and a view (`register(_:view:)`, so
    /// `ModalHost` has a body to draw). The two registrations are independent
    /// and neither clears the other.
    private static func registerInputDialogs(on renderer: SwiftUIModalRenderer) {
        let renameProperties = SwiftUICatalogPresets.renameInput
        renderer.register(TextInputDialog.self) { descriptor, resolve in
            (renameProperties, UIKitModalRenderer.TextInputHolder.make(for: descriptor, resolve: resolve))
        }
        renderer.register(TextInputDialog.self, view: { descriptor, resolve in
            SwiftUIModalRenderer.TextInputContent.make(
                for: descriptor,
                tokens: ModalTokens(from: renameProperties),
                resolve: resolve
            )
        })

        let datePickerProperties = SwiftUICatalogPresets.datePickerInput
        renderer.register(DatePickerDialog.self) { descriptor, resolve in
            (datePickerProperties, UIKitModalRenderer.DatePickerHolder.make(for: descriptor, resolve: resolve))
        }
        renderer.register(DatePickerDialog.self, view: { descriptor, resolve in
            SwiftUIModalRenderer.DatePickerContent.make(
                for: descriptor,
                tokens: ModalTokens(from: datePickerProperties),
                resolve: resolve
            )
        })
    }

    /// The bespoke ports: the badge family (three catalog shapes, one descriptor)
    /// and the loading confirm. Both reach `Properties` through the SAME style map
    /// the standard family uses, so their cards are styled by `GalleryPresets`
    /// and not by `ModalTokens.standard`.
    private static func registerBespokeContent(on renderer: SwiftUIModalRenderer) {
        renderer.register(BadgeDialog.self) { [weak renderer] descriptor, _ in
            (renderer?.properties(for: descriptor.style), badgeHolder(for: descriptor))
        }
        renderer.register(BadgeDialog.self, view: { [weak renderer] descriptor, resolve in
            SwiftUIModalRenderer.BadgeContent.make(
                for: descriptor,
                tokens: tokens(for: descriptor.style, on: renderer),
                resolve: resolve
            )
        })

        renderer.register(LoadingDialog.self) { [weak renderer] descriptor, _ in
            (renderer?.properties(for: descriptor.style), loadingHolder(for: descriptor))
        }
        renderer.register(LoadingDialog.self, view: { [weak renderer] descriptor, resolve in
            SwiftUIModalRenderer.LoadingContent.make(
                for: descriptor,
                tokens: tokens(for: descriptor.style, on: renderer),
                resolve: resolve
            )
        })
    }

    private static func tokens(for style: ModalStyle, on renderer: SwiftUIModalRenderer?) -> ModalTokens {
        guard let properties = renderer?.properties(for: style) else {
            return .standard
        }
        return ModalTokens(from: properties)
    }

    // MARK: Holders for the bespoke descriptors
    //
    // The CONSUMER's descriptor→`DataHolder` mappings. They exist so the
    // presentation's `resolved`/`tokens` come from the shape's REAL `Properties`
    // rather than the renderer's neutral fallback. They deliberately do NOT
    // fabricate a `subtitleCustomView`: on this backend the bespoke content is
    // `Presentation.customContent`, and inventing an empty `UIView` purely to
    // make the UIKit-scoped resolver say `.custom` would be a lie about a view
    // nobody renders.

    static func badgeHolder(for descriptor: BadgeDialog) -> GBAlertModal.DataHolder {
        let (titlePlain, titleAttributed) = ModalText.split(descriptor.title)
        let (subtitlePlain, subtitleAttributed) = ModalText.split(descriptor.subtitle)
        return GBAlertModal.DataHolder(
            closeOnTapOverlay: descriptor.closeOnTapOverlay,
            banner: descriptor.banner.flatMap { UIImage(named: $0.assetName) },
            title: titlePlain,
            titleAttributed: titleAttributed,
            subtitle: subtitlePlain,
            subtitleAttributed: subtitleAttributed,
            primaryAction: descriptor.primary,
            secondaryAction: descriptor.secondary,
            showCloseButton: descriptor.showCloseButton,
            dismissOnAction: false      // the renderer's resolve gate owns teardown
        )
    }

    static func loadingHolder(for descriptor: LoadingDialog) -> GBAlertModal.DataHolder {
        let (titlePlain, titleAttributed) = ModalText.split(descriptor.title)
        let (subtitlePlain, subtitleAttributed) = ModalText.split(descriptor.subtitle)
        return GBAlertModal.DataHolder(
            closeOnTapOverlay: descriptor.closeOnTapOverlay,
            title: titlePlain,
            titleAttributed: titleAttributed,
            subtitle: subtitlePlain,
            subtitleAttributed: subtitleAttributed,
            primaryAction: descriptor.primary,
            secondaryAction: descriptor.secondary,
            showCloseButton: descriptor.showCloseButton,
            dismissOnAction: false
        )
    }

    // MARK: Text helpers

    /// An `AttributedString` carrying UIKIT-scoped styling — the only scope
    /// `ModalText.split` classifies as attributed, i.e. the scope that makes a
    /// shape's subtitle really resolve `.attributed` the way its UIKit twin's
    /// `NSAttributedString` does.
    static func styled(_ string: String, font: UIFont, color: UIColor) -> AttributedString {
        var value = AttributedString(string)
        value.uiKit.font = font
        value.uiKit.foregroundColor = color
        return value
    }
}
