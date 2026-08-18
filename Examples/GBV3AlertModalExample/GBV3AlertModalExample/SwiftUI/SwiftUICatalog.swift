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
//  TWO MORE SECTIONS follow the 26, on the same terms:
//   * `SwiftUICatalog+Stress.swift` — the 28 `StressCatalog` shapes, same names,
//     same categories, same strings, same `Properties`.
//   * `SwiftUICatalog+Divergences.swift` — one dialog per RECORDED difference
//     between the two backends, each captioned with what to look for and whether
//     it is accepted or a defect. Twins live in `Gallery/DivergenceCatalog.swift`.
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
import GBV3AlertModalCore
import GBV3AlertModalSwiftUI

// MARK: - Style tokens

/// The style presets the 26 shapes ask for. The library ships only `.standard`
/// `.standard`; everything else is a CONSUMER preset, which is exactly the
/// claim `ModalStyle` makes ("Extend it from the app side"). This block is that
/// extension, written the way the real app would write it, and every token is
/// mapped to native `ModalProperties` values in `SwiftUICatalogPresets`.
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

    // The four `GBAlertModal.ActionStyle` cases, as styles the Variants section asks for by
    // name. The UIKit twins pass `properties.copy(primaryActionStyle:)` directly at the call
    // site; a descriptor cannot carry a `Properties`, so each case is registered as its own
    // style instead. Same four themes either way — see `SwiftUICatalogPresets`.
    static let variantCapsule = ModalStyle("variant.capsule")
    static let variantCapsuleOutlined = ModalStyle("variant.capsuleOutlined")
    static let variantPlain = ModalStyle("variant.plain")
    static let variantOblique = ModalStyle("variant.oblique")
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
                + "from ModalTokens.bannerGeometry (mirroring UIKit's vwBanner/ivBanner split); UIKit passes a "
                + "real UIImage and lets constraint priorities decide. Same inputs, different layout engines — "
                + "compare every banner shape side by side."
        ),
        SwiftUIDivergence(
            caption: "Fonts. Title/subtitle/button fonts use platform-native descriptors; attributed runs "
                + "retain their explicitly authored SwiftUI font."
        ),
        SwiftUIDivergence(
            caption: "Orientation. SwiftUIModalRenderer pins isLandscape: false, so the resolver always takes the "
                + "portrait reading."
        )
    ]

    /// Closed: legacy attributed text is converted at the Migration boundary before rendering.
    static let attributedRuns = SwiftUIDivergence(
        caption: "Attributed text: bold/colour runs are converted at the Migration boundary and render "
            + "consistently across backends."
    )
    static let bespokePort = SwiftUIDivergence(
        caption: "Bespoke port: drawn by a register(_:view:) body, where the UIKit entry builds a UIView and hands "
            + "it to holder.subtitleCustomView."
    )
    static let bannerArtworkNote = SwiftUIDivergence(
        caption: "Banner geometry is GATED, not eyeballed: the slot's column and height come from "
            + "ModalTokens.bannerGeometry, pinned against measured UIKit output in "
            + "BannerGeometryTruthTests and compared element-for-element in DifferentialGeometryTests "
            + "(PORTRAIT only). Landscape banner shapes are not gated at all, and the divergence there "
            + "is not merely a taller banner: UIKit's height-constrained residual arbitration also "
            + "narrows the banner's WIDTH demand, and that wrong column reaches the CARD and every row "
            + "that matches the card's width — see the design spec §5."
    )
    static let badgeBannerMissing = SwiftUIDivergence(
        caption: "No banner drawn: the UIKit entry's banner is a GENERATED placeholder standing in for the [API] "
            + "per-record badge artwork, and ModalImage can carry only an asset NAME — so this entry carries none."
    )
    static let badgeArtworkMissing = SwiftUIDivergence(
        caption: "Badge artwork is [API] (badge.localImageName): no such asset in this bundle, so the badge cell "
            + "draws its name and description with no picture."
    )
    /// NOT a renderer divergence, and the old caption implied it was. The library's two backends
    /// AGREE: `TextInputHolder` constrains a `UITextField` to 44pt and the SwiftUI view draws a
    /// `TextField` at 44pt. What differs is the GALLERY's UIKit entry, which hand-builds a bordered
    /// `UITextView` at the call site — the bespoke construction the descriptor path exists to
    /// replace. Worth showing on screen, but as a comparison note rather than a gap.
    static let inputChrome = SwiftUIDivergence(
        caption: "Input chrome: this SwiftUI entry renders TextInputDialog through the descriptor path "
            + "(TextField, 44pt — matching the library's UITextField holder). The UIKit entry beside it "
            + "hand-builds a bordered UITextView at the call site, which is what the descriptor replaces."
    )
    static let subtitleSlotNone = SwiftUIDivergence(
        caption: "Subtitle slot resolves .none here — bespoke content lives in Presentation.customContent, and no "
            + "empty UIView is fabricated on the holder just to make the resolver say .custom."
    )
    /// CLOSED 2026-08-01 — `DatePickerDialog` now carries `minimumDate`/`maximumDate` and BOTH
    /// renderers apply them, so the wheel is bounded identically on either backend.
    static let datePickerRange = SwiftUIDivergence(
        caption: "Date range: DatePickerDialog now carries minimumDate/maximumDate and both renderers "
            + "apply them. This entry leaves them unset, so the wheel is unbounded on both."
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
    let divergences: [SwiftUIDivergence]
    /// Returns a short description of the descriptor's own result, shown in the traversal pill.
    ///
    /// Takes the CONCRETE `DefaultModalExecutor` rather than `any ModalExecutor`:
    /// this closure is stored in a `@MainActor` value and awaited from a `Task`,
    /// and a concrete `@MainActor final class` is unambiguously `Sendable` where a
    /// main-actor-isolated existential is not. Nothing in the body depends on the
    /// concrete type — it only calls the `ModalExecutor` front door.
    let present: @MainActor (DefaultModalExecutor) async -> String

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
            divergences: divergences,
            present: { executor in
                let result = await executor.presentAndWait(descriptor())
                return String(describing: result)
            }
        )
    }

}

// MARK: - The catalog

@MainActor
enum SwiftUICatalog {
    /// The 26 real Geniebook shapes, in `DialogCatalog.entries` order (cross-cutting,
    /// worksheet, GenieClass, campaign, working-space, badges) so the two galleries step
    /// in lockstep. `CatalogContractTests` verifies that both backends expose the same unique entries.
    static let dialogEntries: [SwiftUICatalogEntry] =
        crossCuttingEntries
            + worksheetEntries
            + genieClassEntries
            + campaignEntries
            + workingSpaceEntries
            + badgeEntries

    /// Everything the gallery lists, in the same three-group order the UIKit gallery uses
    /// (`DialogCatalog + StressCatalog + …`): the 26 real shapes, then the 28 stress
    /// shapes (`SwiftUICatalog+Stress.swift`, twin of `StressCatalog`), then the five
    /// recorded divergences (`SwiftUICatalog+Divergences.swift`, twin of
    /// `DivergenceCatalog`).
    ///
    /// The `dialogEntries` split is deliberate: the mirror gate compares the 26 against
    /// `DialogCatalog`, and appending stress/divergence rows to one flat list would have
    /// silently turned that gate into a prefix check.
    static let entries: [SwiftUICatalogEntry] =
        dialogEntries + stressEntries + variantEntries + divergenceEntries

    static func index(ofEntryNamed name: String) -> Int? {
        entries.firstIndex { $0.name == name }
    }

    // MARK: Renderer

    /// A renderer carrying every preset, factory and SwiftUI body the catalog's
    /// shapes need — the app-side equivalent of the modal setup a real screen would
    /// do once at composition time. Three preset tables: the 26 real shapes', the
    /// stress matrix's, and the divergence section's.
    ///
    /// Structurally identical to `GalleryViewController.openTier0Demo`'s UIKit
    /// registration, which is the point: a consumer's preset table and holder
    /// factories are portable between the two backends verbatim.
    static func makeRenderer() -> SwiftUIModalRenderer {
        let renderer = SwiftUIModalRenderer(alertProperties: SwiftUICatalogPresets.standard)
        let presets = SwiftUICatalogPresets.stylePresets
            + SwiftUICatalogPresets.stressPresets
            + SwiftUICatalogPresets.variantPresets
            + SwiftUICatalogPresets.divergencePresets
        for (style, properties) in presets {
            renderer.register(style: style, properties: properties)
        }
        renderer.registerBuiltInDescriptors()
        renderer.register(CatalogCustomSubtitleDialog.self, view: { descriptor, resolve in
            AnyView(CatalogCustomSubtitleModalView(descriptor: descriptor, resolve: resolve))
        })
        return renderer
    }

    // MARK: Text helpers

    /// An `AttributedString` carrying native SwiftUI run styling.
    static func styled(_ string: String, font: Font, color: Color) -> AttributedString {
        var value = AttributedString(string)
        value.font = font
        value.foregroundColor = color
        return value
    }
}
