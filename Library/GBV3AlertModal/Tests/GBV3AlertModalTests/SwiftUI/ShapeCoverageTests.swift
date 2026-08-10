import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModal

/// **The acceptance gate: all 26 real Geniebook dialog shapes, expressed and rendered on the
/// SwiftUI backend.**
///
/// One test per catalog entry, named after it, so a gap is visible in the test LIST rather than
/// buried in a diff — plus `test_manifest_coversAllTwentySixCatalogShapes`, which fails if a name
/// is dropped from coverage. The shapes themselves live in `Support/GenieShapeCatalog.swift`
/// (transcribed from `Examples/.../Gallery/DialogCatalog+*.swift`, the source of truth).
///
/// ## What a green run here means — read this before quoting it
///
/// Each test proves TWO things and no more:
///
/// 1. **Structure.** Presenting the shape through `SwiftUIModalRenderer` produces the expected
///    `GBAlertModal.ResolvedModal` slots — the SAME pure resolver the UIKit renderer runs, over the
///    shape's real `Properties`. This is the "the descriptor resolves correctly" claim.
/// 2. **A body that actually draws.** `ModalHost` has something to draw for it, and hosting that
///    body in a real key window produces real output — non-transparent pixels off
///    `layer.render(in:)`, and/or a non-empty lowered `UIView` tree
///    (`GenieShapeCatalog.BodyEvidence`). It proves the modal DREW, not that any particular slot
///    inside it did: a scrim alone covers the screen.
///
///    This half was VACUOUS in the first version of this file, which measured
///    `UIHostingController.sizeThatFits(in:)` — the size of the HOST, which fills its proposal
///    whatever the content is. `test_measure_discriminatesAnEmptyBody` caught it. The structural
///    half was never affected.
///
/// It does **NOT** prove visual fidelity. There is no snapshot baseline for the SwiftUI backend in
/// this repo, and this codebase has a documented history of snapshot-green-but-visually-wrong
/// (spec C-0). Specifically NOT proven, per shape:
///
/// * **Typography.** The real presets use SHSans/DMSans; these use system fonts (see `GeniePresets`'
///   catalog-preset note). `ModalTokens` bridges whatever `UIFont` a `Properties` carries, so the
///   real fonts WOULD flow through — but nothing here demonstrates that.
/// * **Banner artwork.** The 12 asset files live in the example app, not in this package, so the
///   factory substitutes a generated image for any NAMED asset
///   (`GenieShapeCatalog.substitutedBanner`). The banner SLOT is proven; the picture is not.
///   `test_bannerSubstitution_isTheOnlyDeviationFromProduction` pins that deviation to exactly one
///   resolver field.
/// * **Animation.** Neither renderer's present/dismiss transition is exercised anywhere.
/// * **Banner GEOMETRY, as pixels.** `bannerRatio` / `bannerMaxHeight` are no longer a token-set gap
///   — both are derived into `ModalTokens.bannerGeometry` and applied by `SwiftUIAlertModal`'s
///   `BannerSlot` (the standard path) with the UIKit constraint precedence (`bannerFixedHeight` is
///   dropped entirely — measured inert on both UIKit paths, `BannerGeometryTruthTests`), and the
///   derivation + precedence are unit-tested (`ModalTokensProvenanceTests`, `ModalBannerLayoutTests`,
///   `ModalBannerGeometryRuleTests`). What is still NOT proven here is the resulting on-screen SIZE:
///   no test measures the drawn banner on either backend, and the artwork is substituted anyway (see
///   the bullet above) — that comparison lives in `DifferentialGeometryTests.test_geometry_
///   bannerComparable`, which is the one shape not routed through this substitution.
@MainActor
final class ShapeCoverageTests: XCTestCase {

    // MARK: - The shared assertion

    /// Presents `name` and asserts its resolved structure and that it has a real, laid-out body.
    ///
    /// `showsPrimary` is not a parameter: every one of the 26 catalog shapes has a primary action
    /// and every preset supplies a `primaryActionStyle`, so it is asserted unconditionally — if one
    /// ever stops being true, that is a defect and not a per-shape expectation.
    @discardableResult
    private func assertRenders(
        _ name: String,
        showsBanner: Bool,
        showsTitle: Bool,
        subtitle: GBAlertModal.ResolvedModal.SubtitleKind,
        showsSecondary: Bool,
        showsCloseButton: Bool = false,
        closeOnTapOverlay: Bool = false,
        bespoke: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> GenieShapeCatalog.Presented {
        let presented = try GenieShapeCatalog.present(name)
        let resolved = presented.resolved

        XCTAssertEqual(resolved.showsBanner, showsBanner, "\(name): banner slot", file: file, line: line)
        XCTAssertEqual(resolved.showsTitle, showsTitle, "\(name): title slot", file: file, line: line)
        XCTAssertEqual(resolved.subtitle, subtitle, "\(name): subtitle kind", file: file, line: line)
        XCTAssertTrue(resolved.showsPrimary, "\(name): every catalog shape has a primary action",
                      file: file, line: line)
        XCTAssertEqual(resolved.showsSecondary, showsSecondary, "\(name): secondary slot",
                       file: file, line: line)
        XCTAssertEqual(resolved.showsCloseButton, showsCloseButton, "\(name): close button",
                       file: file, line: line)
        XCTAssertEqual(resolved.closeOnTapOverlay, closeOnTapOverlay, "\(name): scrim tap",
                       file: file, line: line)

        XCTAssertEqual(
            presented.isBespoke, bespoke,
            "\(name): bespoke shapes must draw a registered view; standard ones the AlertDialog projection",
            file: file, line: line
        )
        XCTAssertTrue(presented.hasBody, "\(name): ModalHost must have a body to draw",
                      file: file, line: line)

        let evidence = GenieShapeCatalog.bodyEvidence(of: presented.presentation)
        XCTAssertTrue(
            evidence.isNonEmpty,
            "\(name): the body drew nothing and lowered to nothing — \(evidence)",
            file: file, line: line
        )
        return presented
    }

    // MARK: - THE MANIFEST GATE

    /// **The gate against silent under-delivery.** The 26 catalog names are hard-coded in
    /// `GenieShapeCatalog.names`; this asserts there are exactly 26 of them, that they are distinct,
    /// and that every single one has a covered shape that actually presents. Drop a shape and this
    /// goes red even if every other test in this file still passes.
    func test_manifest_coversAllTwentySixCatalogShapes() throws {
        let names = GenieShapeCatalog.names

        XCTAssertEqual(names.count, 26, "the catalog defines exactly 26 distinct dialog shapes")
        XCTAssertEqual(Set(names).count, 26, "catalog names must be distinct")

        let covered = GenieShapeCatalog.shapes.map(\.name)
        XCTAssertEqual(Set(covered).count, covered.count, "a shape must not be registered twice")
        XCTAssertEqual(
            Set(names).subtracting(covered), [],
            "catalog shapes with NO SwiftUI coverage — this is the under-delivery gate"
        )
        XCTAssertEqual(
            Set(covered).subtracting(names), [],
            "covered shapes that are not in the catalog manifest — add them to `names` or remove them"
        )

        // Every one of them must actually present and have a body; a `Shape` that throws or draws
        // nothing is not coverage.
        for name in names {
            let presented = try GenieShapeCatalog.present(name)
            XCTAssertTrue(presented.hasBody, "\(name) presents but has no body to draw")
        }
    }

    /// The control that keeps every "non-empty body" assertion above honest: the SAME measurement
    /// helper, over a body that genuinely renders nothing, must measure `.zero`. Without this, a
    /// measurement that always returned a non-zero size would make all 26 tests vacuously green.
    /// **The guard on the guard — and it has already earned its keep.**
    ///
    /// The first version of the body check asked `UIHostingController.sizeThatFits(in:)` for a size.
    /// That measures the HOST, which fills its proposal no matter what is inside it: an `EmptyView`
    /// measured the full 390×844, identically to a real modal. This test failed, which is the only
    /// reason the vacuity was caught instead of shipped as 26 green assertions that proved nothing.
    ///
    /// So it stays, and it stays strict: an EMPTY body must FAIL the exact predicate the 26 populated
    /// shapes PASS. If `BodyEvidence.isNonEmpty` ever stops discriminating, this goes red first.
    func test_measure_discriminatesAnEmptyBody() {
        let empty = GenieShapeCatalog.bodyEvidence(of: EmptyView())
        XCTAssertFalse(
            empty.isNonEmpty,
            "an empty body produced \(empty) — it must FAIL the same predicate the 26 shape tests "
                + "pass, otherwise every one of those body assertions is vacuous"
        )

        // The positive half: a populated scaffold must pass the same predicate, so the control
        // cannot be satisfied by a predicate that simply says "no" to everything.
        let populated = GenieShapeCatalog.bodyEvidence(
            of: AlertModalScaffold(primaryTitle: "Okay", onPrimary: {}) { Text("Body") }
        )
        XCTAssertTrue(populated.isNonEmpty, "a populated scaffold produced \(populated)")
    }

    // MARK: - Cross-cutting shapes

    func test_shape_standard_one_button_rendersOnSwiftUI() throws {
        try assertRenders(
            "standard-one-button",
            showsBanner: false,
            showsTitle: true,
            subtitle: .plain("You don't have microphone."),
            showsSecondary: false,
            closeOnTapOverlay: true
        )
    }

    func test_shape_standard_two_button_rendersOnSwiftUI() throws {
        try assertRenders(
            "standard-two-button",
            showsBanner: false,
            showsTitle: true,
            subtitle: .plain("[API] Are you sure you want to proceed?"),
            showsSecondary: true,
            closeOnTapOverlay: true
        )
    }

    /// `title: nil` is the whole point of this shape (12 WKWebView failure call sites) — the title
    /// slot must resolve ABSENT while the subtitle still renders.
    func test_shape_title_nil_error_rendersOnSwiftUI() throws {
        try assertRenders(
            "title-nil-error",
            showsBanner: false,
            showsTitle: false,
            subtitle: .plain("[API] The operation couldn't be completed. (NSURLErrorDomain error -1009.)"),
            showsSecondary: false,
            closeOnTapOverlay: true
        )
    }

    func test_shape_close_button_dismiss_rendersOnSwiftUI() throws {
        try assertRenders(
            "close-button-dismiss",
            showsBanner: false,
            showsTitle: true,
            subtitle: .plain("[API] You are not allowed to send messages in this class right now."),
            showsSecondary: false,
            showsCloseButton: true,
            closeOnTapOverlay: true
        )
    }

    /// One of the four "own preset" shapes. The preset reaches the presentation through the
    /// `ModalStyle` token, which is what this asserts on top of the structure.
    func test_shape_permission_denied_settings_rendersOnSwiftUI() throws {
        let presented = try assertRenders(
            "permission-denied-settings",
            showsBanner: false,
            showsTitle: true,
            subtitle: .plain("Allow Geniebook to access your camera in your device's settings."),
            showsSecondary: true,
            closeOnTapOverlay: true
        )
        XCTAssertTrue(presented.renderer.isRegistered(style: .permissionAlert))
        // `permissionAlertProperties` sets ComponentSpace.subtitle = 20 (standard is 16) — a field
        // that survives the whole styling pipeline, so it proves the PRESET reached the tokens and
        // not just the descriptor.
        XCTAssertEqual(presented.tokens.gapBelowSubtitle, 20, "the permission preset must reach the tokens")
    }

    /// The red oblique theme is a per-call-site `ActionStyle` override, and `ModalTokens` derives
    /// the primary button's palette from exactly that style — so the accent colour is the evidence
    /// the theme survived.
    func test_shape_oblique_red_leave_confirm_rendersOnSwiftUI() throws {
        let presented = try assertRenders(
            "oblique-red-leave-confirm",
            showsBanner: false,
            showsTitle: true,
            subtitle: .plain("The live class has not ended yet. Are you sure you want to leave?"),
            showsSecondary: true,
            closeOnTapOverlay: true
        )
        // Compared against the STANDARD preset's derived accent rather than a literal `Color`:
        // `Color` equality across two independently-constructed dynamic system colours is not a
        // guarantee worth leaning on, whereas "the red preset's accent differs from the standard
        // preset's" is exactly the claim — the per-call-site theme reached the palette.
        let standardTokens = ModalTokens(from: GeniePresets.standardProperties())
        XCTAssertNotEqual(
            presented.tokens.palette.accent, standardTokens.palette.accent,
            "the red oblique theme must reach the primary button's palette"
        )
        // …and must NOT reach the SECONDARY button: this shape overrides only `primaryActionStyle`,
        // so the secondary label stays the standard preset's own colour. The SwiftUI secondary used
        // to be coloured from `palette.accent`, which made exactly this shape draw a red secondary.
        XCTAssertEqual(
            presented.tokens.palette.secondaryLabel, standardTokens.palette.secondaryLabel,
            "the secondary style is unchanged here, so its label colour must be too"
        )
        XCTAssertNotEqual(
            presented.tokens.palette.secondaryLabel, presented.tokens.palette.accent,
            "the secondary label must not follow the primary theme"
        )
    }

    func test_shape_database_error_banner_rendersOnSwiftUI() throws {
        let presented = try assertRenders(
            "database-error-banner",
            showsBanner: true,
            showsTitle: true,
            subtitle: .plain("We're fixing our servers as fast as we can.\nTake a break and try again later."),
            showsSecondary: false
        )
        XCTAssertEqual(presented.tokens.bannerMaxHeight, 320, "the preset's banner cap must reach the tokens")
    }

    func test_shape_force_update_banner_rendersOnSwiftUI() throws {
        try assertRenders(
            "force-update-banner",
            showsBanner: true,
            showsTitle: true,
            subtitle: .plain("[API] Head over to the App Store to download the latest version."),
            showsSecondary: false
        )
    }

    // MARK: - Worksheet shapes

    /// BESPOKE PORT. Resolves like the two-button confirm the catalog describes, but through
    /// `LoadingDialog` — the descriptor that can also ask for the busy primary button (see
    /// `test_bespoke_loadingState_...` below).
    func test_shape_worksheet_generating_abused_rendersOnSwiftUI() throws {
        try assertRenders(
            "worksheet-generating-abused",
            showsBanner: false,
            showsTitle: true,
            subtitle: .plain("[API] Something went wrong while generating your worksheet.\n\nContinue?"),
            showsSecondary: true,
            bespoke: true
        )
    }

    func test_shape_worksheet_abused_cap_banner_rendersOnSwiftUI() throws {
        try assertRenders(
            "worksheet-abused-cap-banner",
            showsBanner: true,
            showsTitle: true,
            subtitle: .plain("[API] You've reached your daily worksheet generation limit for today."),
            showsSecondary: true
        )
    }

    /// The subtitle slot resolves `.custom` here because `TextInputHolder` really does put a
    /// `UITextField` in `holder.subtitleCustomView` — the SwiftUI body is the registered
    /// `TextInputModalView`, drawn from `customContent`.
    func test_shape_rename_worksheet_rendersOnSwiftUI() throws {
        try assertRenders(
            "rename-worksheet",
            showsBanner: false,
            showsTitle: true,
            subtitle: .custom,
            showsSecondary: true,
            closeOnTapOverlay: true,
            bespoke: true
        )
    }

    func test_shape_date_picker_worksheet_rendersOnSwiftUI() throws {
        try assertRenders(
            "date-picker-worksheet",
            showsBanner: false,
            showsTitle: true,
            subtitle: .custom,
            showsSecondary: true,
            closeOnTapOverlay: true,
            bespoke: true
        )
    }

    func test_shape_streak_popup_banner_rendersOnSwiftUI() throws {
        let presented = try assertRenders(
            "streak-popup-banner",
            showsBanner: true,
            showsTitle: true,
            subtitle: .plain(
                "[API] You missed your 7 days streak and 15 extra bubbles. "
                    + "Save your streak by doing 5 questions!"
            ),
            showsSecondary: false
        )
        XCTAssertTrue(presented.renderer.isRegistered(style: .streak))
        XCTAssertEqual(presented.tokens.bannerMaxHeight, 168, "the streak preset must reach the tokens")
    }

    /// Attributed title AND subtitle — the only shape in the catalog that uses `titleAttributed`
    /// plus `subtitleAttributed` with no other override.
    func test_shape_switch_device_recommendation_rendersOnSwiftUI() throws {
        try assertRenders(
            "switch-device-recommendation",
            showsBanner: false,
            showsTitle: true,
            subtitle: .attributed,
            showsSecondary: false,
            closeOnTapOverlay: true
        )
    }

    // MARK: - GenieClass shapes

    func test_shape_quiz_info_banner_rendersOnSwiftUI() throws {
        try assertRenders(
            "quiz-info-banner",
            showsBanner: true,
            showsTitle: true,
            subtitle: .plain("[API] You've completed the quiz for Algebra Fundamentals."),
            showsSecondary: false
        )
    }

    func test_shape_quiz_begin_banner_rendersOnSwiftUI() throws {
        try assertRenders(
            "quiz-begin-banner",
            showsBanner: true,
            showsTitle: true,
            subtitle: .plain(
                "[API] The GenieClass Algebra Fundamentals Quiz contains 10 MCQ questions "
                    + "and should take about 15 minutes to complete. Are you ready?"
            ),
            showsSecondary: true
        )
    }

    func test_shape_credit_deduction_popup_rendersOnSwiftUI() throws {
        try assertRenders(
            "credit-deduction-popup",
            showsBanner: false,
            showsTitle: true,
            subtitle: .plain(
                "[API] Joining this class will use 1 Mathematics lesson credit.\n\n"
                    + "Mathematics lesson credits left: 5"
            ),
            showsSecondary: true
        )
    }

    /// `title: nil` WITH a banner — the combination that would expose a title/banner slot mix-up.
    func test_shape_ai_notes_ready_banner_rendersOnSwiftUI() throws {
        try assertRenders(
            "ai-notes-ready-banner",
            showsBanner: true,
            showsTitle: false,
            subtitle: .plain("[API] Your Personalised Summary Notes for Algebra Fundamentals is ready!"),
            showsSecondary: true
        )
    }

    // MARK: - Campaign shapes

    /// Presented as `PopupDialog` rather than `AlertDialog(style: .popup)` — both spellings must
    /// resolve through the same style map, and `gapBelowSubtitle == 24` is the popup preset's value
    /// (standard is 16), so it proves the popup `Properties` were the ones used.
    func test_shape_onboarding_welcome_nobanner_rendersOnSwiftUI() throws {
        let presented = try assertRenders(
            "onboarding-welcome-nobanner",
            showsBanner: false,
            showsTitle: true,
            subtitle: .plain("Let's explore Geniebook!"),
            showsSecondary: false
        )
        XCTAssertEqual(presented.tokens.gapBelowSubtitle, 24, "PopupDialog must draw with the popup preset")
    }

    func test_shape_onboarding_trial_banner_rendersOnSwiftUI() throws {
        try assertRenders(
            "onboarding-trial-banner",
            showsBanner: true,
            showsTitle: true,
            subtitle: .plain("Subscribe to continue learning with Geniebook"),
            showsSecondary: true
        )
    }

    // MARK: - Working-space shapes

    func test_shape_exit_worksheet_confirm_banner_rendersOnSwiftUI() throws {
        let presented = try assertRenders(
            "exit-worksheet-confirm-banner",
            showsBanner: true,
            showsTitle: true,
            subtitle: .plain("[API] Don't give up, you still have 3 questions remaining. You can do it!"),
            showsSecondary: true,
            closeOnTapOverlay: true
        )
        XCTAssertEqual(presented.tokens.bannerMaxHeight, 144)
    }

    func test_shape_worksheet_ready_timer_banner_rendersOnSwiftUI() throws {
        let presented = try assertRenders(
            "worksheet-ready-timer-banner",
            showsBanner: true,
            showsTitle: true,
            subtitle: .attributed,
            showsSecondary: false
        )
        // The timer preset's uniform 32pt padding reaches `contentPaddingV/H`.
        XCTAssertEqual(presented.tokens.contentPaddingV, 32)
        XCTAssertEqual(presented.tokens.contentPaddingH, 32)
    }

    func test_shape_worksheet_timeup_timer_banner_rendersOnSwiftUI() throws {
        try assertRenders(
            "worksheet-timeup-timer-banner",
            showsBanner: true,
            showsTitle: true,
            subtitle: .attributed,
            showsSecondary: true
        )
    }

    // MARK: - Badge shapes (all three are bespoke ports)

    /// The per-badge artwork is `[API]` (`badge.localImageName`, resolved per record at runtime) —
    /// a NAME, which is exactly what `ModalImage` carries, so the descriptor stays `Sendable`.
    func test_shape_badge_unlock_single_rendersOnSwiftUI() throws {
        let presented = try assertRenders(
            "badge-unlock-single",
            showsBanner: true,
            showsTitle: true,
            // Mixed-run attributed subtitle ("you unlocked the **X** badge!"), as BadgesPopUpView builds it.
            subtitle: .attributed,
            showsSecondary: true,
            bespoke: true
        )
        XCTAssertTrue(presented.renderer.isRegistered(style: .badgeUnlock))
        XCTAssertEqual(presented.tokens.bannerMaxHeight, 144, "the badge preset must reach the tokens")
    }

    func test_shape_badge_unlock_multi_rendersOnSwiftUI() throws {
        let presented = try assertRenders(
            "badge-unlock-multi",
            showsBanner: true,
            showsTitle: true,
            subtitle: .plain("You unlocked new badges."),
            showsSecondary: true,
            bespoke: true
        )
        XCTAssertEqual(presented.tokens.bannerMaxHeight, 216, "the multi variant's taller banner cap")
    }

    /// No banner, no title, no subtitle: the ENTIRE content is the badge grid, which is why this
    /// shape needed the content seam at all. See
    /// `test_bespokeContent_isNotHolderSubtitleCustomView` for why `subtitle` resolves `.none`
    /// rather than `.custom` on this backend.
    func test_shape_badge_detail_popup_rendersOnSwiftUI() throws {
        let presented = try assertRenders(
            "badge-detail-popup",
            showsBanner: false,
            showsTitle: false,
            subtitle: .none,
            showsSecondary: false,
            closeOnTapOverlay: true,
            bespoke: true
        )
        XCTAssertEqual(presented.tokens.gapBelowSubtitle, 24, "the detail preset's ComponentSpace")
    }

    // MARK: - The bespoke ports' own behaviour
    //
    // The shape tests above prove each bespoke shape RESOLVES and DRAWS. These prove the ported
    // content actually does its job — which is the part a structural assertion cannot see.

    /// The satisfaction row: NOT one of the 26 (the catalog does not list it), ported as the
    /// exemplar of the seam. Its result carries a value the VIEW owns, which no pre-registered
    /// `(ActionType) -> Result` route could produce.
    func test_bespoke_satisfactionRow_rendersAndCarriesTheSelectedIndex() throws {
        let renderer = GenieShapeCatalog.makeRenderer()
        let id = ModalID()
        GenieShapeCatalog.satisfactionExemplar.present(renderer, id)

        let presentation = try XCTUnwrap(renderer.presentations.first(where: { $0.id == id }))
        XCTAssertNotNil(presentation.customContent, "the satisfaction row is bespoke content")
        let evidence = GenieShapeCatalog.bodyEvidence(of: presentation)
        XCTAssertTrue(evidence.isNonEmpty, "the satisfaction row drew nothing — \(evidence)")

        // The validation gate, as a pure function: nothing selected → a primary tap cannot fabricate
        // an index (the button is disabled in the UI, and the mapping refuses to invent one).
        XCTAssertEqual(SatisfactionModalView.result(for: .primary, selectedIndex: nil), .dismissed)
        XCTAssertEqual(SatisfactionModalView.result(for: .primary, selectedIndex: 2), .submitted(index: 2))
        XCTAssertEqual(SatisfactionModalView.result(for: .close, selectedIndex: 2), .dismissed)
    }

    /// The seam's whole point, exercised through the satisfaction row: the registered view is handed
    /// the resolve GATE, so it resolves with a value read at interaction time.
    func test_bespoke_satisfactionRow_submittedIndexReachesTheToken() throws {
        let renderer = GenieShapeCatalog.makeRenderer()
        var submit: ((SatisfactionDialog.Result) -> Void)?
        renderer.register(SatisfactionDialog.self, view: { _, resolve in
            submit = resolve
            return AnyView(EmptyView())
        })
        var result: SatisfactionDialog.Result?
        let id = ModalID()

        renderer.present(
            SatisfactionDialog(
                options: [SatisfactionDialog.Option(id: "a", symbolName: "star.fill", label: "A")],
                primary: "Submit"
            ),
            id: id, resolve: { result = $0 }
        )
        try XCTUnwrap(submit)(.submitted(index: 0))

        XCTAssertEqual(result, .submitted(index: 0))
        XCTAssertTrue(renderer.presentations.isEmpty, "resolving must tear the presentation down")
        XCTAssertNil(renderer.live[id])
    }

    /// The loading state `worksheet-generating-abused` needed: the SAME descriptor, flipped through
    /// the executor's own `update(_:to:)`, must rebuild the body without resolving the token.
    func test_bespoke_loadingState_flipsInPlaceWithoutResolving() throws {
        let renderer = GenieShapeCatalog.makeRenderer()
        let id = ModalID()
        var resolvedCount = 0
        let resting = LoadingDialog(
            title: AttributedString("Generating Worksheet"),
            subtitle: AttributedString("[API] Continue?"),
            primary: "Continue",
            secondary: "Cancel"
        )

        renderer.present(resting, id: id, resolve: { _ in resolvedCount += 1 })
        var busy = resting
        busy.isLoading = true
        renderer.update(id, to: busy)

        let presentation = try XCTUnwrap(renderer.presentations.first(where: { $0.id == id }))
        XCTAssertEqual(renderer.presentations.count, 1, "update must not add a presentation")
        XCTAssertNotNil(presentation.customContent, "the busy body must still be there")
        XCTAssertEqual(resolvedCount, 0, "update must never resolve the token")
        let evidence = GenieShapeCatalog.bodyEvidence(of: presentation)
        XCTAssertTrue(
            evidence.isNonEmpty,
            "the loading body (spinner in place of the label) must still draw — \(evidence)"
        )
    }

    /// The badge grid's action mapping, kept out of the view body so it is assertable without
    /// hosting: "View my badges" navigates, everything else dismisses.
    func test_bespoke_badgeGrid_mapsActionsToItsOwnResultVocabulary() {
        XCTAssertEqual(BadgeModalView.result(for: .primary), .viewBadges)
        XCTAssertEqual(BadgeModalView.result(for: .secondary), .dismissed)
        XCTAssertEqual(BadgeModalView.result(for: .close), .dismissed)
    }

    func test_bespoke_loadingDialog_mapsActionsToItsOwnResultVocabulary() {
        XCTAssertEqual(LoadingModalView.result(for: .primary), .confirmed)
        XCTAssertEqual(LoadingModalView.result(for: .secondary), .cancelled)
        XCTAssertEqual(LoadingModalView.result(for: .close), .dismissed)
    }

    // MARK: - Honesty guards
    //
    // Two known divergences, asserted rather than described, so they cannot rot into folklore.

    /// **Recorded structural divergence, NOT a shortfall in expressibility.**
    ///
    /// `ResolvedModal.SubtitleKind.custom` is defined as `holder.subtitleCustomView != nil` — a
    /// UIKit-only classification (`UIView`). On the SwiftUI backend bespoke content lives in
    /// `AlertModalScaffold`'s `@ViewBuilder` slot, i.e. `Presentation.customContent`, and the holder
    /// carries no view at all. So `badge-detail-popup` — whose UIKit twin resolves `.custom` —
    /// resolves `.none` here while still drawing its full content.
    ///
    /// The alternative would have been to fabricate an empty `UIView` on the holder purely to make
    /// the resolver say `.custom`. That would be a fake: a value invented to satisfy an assertion,
    /// describing a view nobody renders.
    func test_bespokeContent_isNotHolderSubtitleCustomView() throws {
        let presented = try GenieShapeCatalog.present("badge-detail-popup")

        XCTAssertEqual(
            presented.resolved.subtitle, .none,
            "no UIView is fabricated on the holder just to make the UIKit-scoped resolver say .custom"
        )
        XCTAssertNotNil(
            presented.presentation.customContent,
            "the content IS there — on the SwiftUI backend it lives in customContent, not the holder"
        )
    }

    /// Pins the blast radius of the banner-asset substitution (see
    /// `GenieShapeCatalog.registerStandardFamily`): with the production registration, the SAME
    /// descriptor resolves identically EXCEPT `showsBanner`, which is false only because the asset
    /// file is not in this bundle. If the substitution ever started changing anything else, this
    /// fails.
    func test_bannerSubstitution_isTheOnlyDeviationFromProduction() throws {
        let descriptor = AlertDialog(
            image: ModalImage("img_database_error"),
            title: "Something went wrong :(",
            subtitle: "We're fixing our servers as fast as we can.",
            primary: "Okay",
            style: .errorBanner
        )

        // Production registration: no substitution, so `UIImage(named:)` returns nil here.
        let production = SwiftUIModalRenderer(
            alertProperties: GeniePresets.standardProperties(),
            popupProperties: GeniePresets.popupProperties()
        )
        for (style, properties) in GenieShapeCatalog.stylePresets {
            production.register(style: style, properties: properties)
        }
        let productionID = ModalID()
        production.present(descriptor, id: productionID, resolve: { _ in })
        let productionResolved = try XCTUnwrap(
            production.presentations.first(where: { $0.id == productionID })
        ).resolved

        let substitutedID = ModalID()
        let substituted = GenieShapeCatalog.makeRenderer()
        substituted.present(descriptor, id: substitutedID, resolve: { _ in })
        let substitutedResolved = try XCTUnwrap(
            substituted.presentations.first(where: { $0.id == substitutedID })
        ).resolved

        XCTAssertFalse(
            productionResolved.showsBanner,
            "the app's banner assets are not in this bundle — this is the gap the substitution fills"
        )
        XCTAssertTrue(substitutedResolved.showsBanner)

        var normalised = substitutedResolved
        normalised.showsBanner = productionResolved.showsBanner
        XCTAssertEqual(
            normalised, productionResolved,
            "substituting the banner image must change NOTHING except the banner slot"
        )
    }
}
