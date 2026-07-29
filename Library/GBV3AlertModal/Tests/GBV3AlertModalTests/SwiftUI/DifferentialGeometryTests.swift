import XCTest
import SwiftUI
import UIKit
@testable import GBV3AlertModal

// MARK: - The harness's own honesty

/// **The gate on the gate.**
///
/// A previous task on this plan shipped 26 green "renders a non-empty body" assertions that proved
/// nothing, because the thing being measured always filled the screen; it was caught only because
/// that implementer wrote a guard on their own methodology and left it failing. This class is that
/// guard for the differential-geometry harness. Every test here MUST pass. If any of them goes red,
/// every green (and every red) in `DifferentialGeometryTests` is meaningless and must be re-read
/// from scratch.
///
/// What each guard would report if the comparison logic silently stopped working:
///
/// * `test_discriminationGuard_swiftUIMeasurementRespondsToAPerturbedToken` and
///   `..._uiKitMeasurementRespondsToAPerturbedPreset` deliberately move the card width by 40pt on
///   ONE side and require the comparison to say `DIFFER` with a ~40pt delta. If `compare` started
///   returning `agree` unconditionally, or if either measurement started returning a constant, both
///   go RED — they cannot pass while the comparison is blind.
/// * `test_discriminationGuard_identicalInputsReportNoDifference` is the other half: it requires the
///   comparison to say `agree` when nothing was changed. Without it, a `compare` that returned
///   `DIFFER` unconditionally would satisfy the perturbation guards.
/// * `test_discriminationGuard_toleranceIsSubPixelOnly` pins the tolerance itself: 0.4pt is
///   absorbed, 1.0pt is not. A tolerance widened to make a shape pass makes this RED.
/// * `test_harness_measuresEveryElementBothBackendsDraw` requires a real, non-degenerate rectangle
///   for every element the shared resolver says is drawn. If the probes stopped publishing, or
///   published `.zero`, this goes RED rather than the shapes going green on empty dictionaries.
// @MainActor: drives `GBAlertModal`, `UIWindow` and `UIHostingController`.
@MainActor
final class DifferentialGeometryHarnessTests: XCTestCase {

    // MARK: Non-vacuity

    func test_harness_measuresEveryElementBothBackendsDraw() throws {
        for shape in DifferentialGeometry.shapes {
            let expected = expectedElements(of: shape)
            let uiKit = DifferentialGeometry.uiKitFrames(shape)
            let swiftUI = DifferentialGeometry.swiftUIFrames(shape)

            XCTAssertFalse(
                uiKit.isEmpty,
                "'\(shape.name)': the UIKit reader produced NO frames — it measured nothing"
            )
            XCTAssertFalse(
                swiftUI.isEmpty,
                "'\(shape.name)': the SwiftUI probes produced NO frames. Either the "
                    + "GeometryReader/PreferenceKey instrumentation is not reaching the sink, or the "
                    + "settle budget in `pump` is too small. Every geometry result for this shape is "
                    + "worthless until this passes."
            )

            for element in expected.sorted(by: { $0.rawValue < $1.rawValue }) {
                let lhs = try XCTUnwrap(
                    uiKit[element],
                    "'\(shape.name)': the resolver says \(element.rawValue) is drawn, but the UIKit "
                        + "reader has no frame for it"
                )
                let rhs = try XCTUnwrap(
                    swiftUI[element],
                    "'\(shape.name)': the resolver says \(element.rawValue) is drawn, but no SwiftUI "
                        + "probe published a frame for it"
                )
                assertNonDegenerate(lhs, shape.name, element, "UIKit")
                assertNonDegenerate(rhs, shape.name, element, "SwiftUI")
            }
        }
    }

    private func assertNonDegenerate(
        _ rect: CGRect,
        _ shape: String,
        _ element: ModalGeometryElement,
        _ side: String
    ) {
        XCTAssertGreaterThan(
            rect.width, 0,
            "'\(shape)' \(side) \(element.rawValue) has zero width — a zero rect compares equal to "
                + "another zero rect, which is how a measurement harness reports agreement about nothing"
        )
        XCTAssertGreaterThan(
            rect.height, 0,
            "'\(shape)' \(side) \(element.rawValue) has zero height — see above"
        )
    }

    /// Which elements the SHARED resolver says are drawn, so "did the probe fire" is asked against
    /// the library's own decision rather than against a hand-written list per shape.
    private func expectedElements(of shape: DifferentialGeometry.Shape) -> Set<ModalGeometryElement> {
        let holder = UIKitModalRenderer.AlertHolder.make(for: shape.dialog, resolve: { _ in })
        let resolved = GBAlertModal.resolve(
            properties: shape.properties, holder: holder, isLandscape: false
        )
        var expected: Set<ModalGeometryElement> = [.card]
        if resolved.showsTitle { expected.insert(.title) }
        if resolved.subtitle != .none { expected.insert(.subtitle) }
        if resolved.showsPrimary { expected.insert(.primaryButton) }
        if resolved.showsSecondary { expected.insert(.secondaryButton) }
        if resolved.showsCloseButton { expected.insert(.closeButton) }
        // `banner` is deliberately absent whatever the resolver says — see
        // `test_bannerExclusion_isABundleFact_notAnOmission`.
        return expected
    }

    // MARK: Discrimination — the comparison must be able to say DIFFER

    func test_discriminationGuard_swiftUIMeasurementRespondsToAPerturbedToken() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "standard-two-button"))

        var perturbed = ModalTokens(from: shape.properties)
        perturbed.cardMaxWidth += 40   // 256 -> 296, still well inside the 350pt available width

        // Both sides of this one comparison are SwiftUI readings (baseline on the left, perturbed on
        // the right) — the guard is about whether `compare` SEES a change, so it holds the renderer
        // fixed and moves one token.
        let baseline = DifferentialGeometry.swiftUIFrames(shape)
        let moved = DifferentialGeometry.swiftUIFrames(shape, tokens: perturbed)
        let rows = DifferentialGeometry.compare(uiKit: baseline, swiftUI: moved)
        let card = try XCTUnwrap(rows.first { $0.element == .card })

        XCTAssertEqual(
            card.verdict, .differ,
            "a 40pt card-width perturbation on the SwiftUI side was NOT reported. The comparison "
                + "cannot detect a difference introduced on purpose, so it cannot detect a real one.\n"
                + DifferentialGeometry.table(
                    name: "SwiftUI baseline (left column) vs SwiftUI +40pt cardMaxWidth (right column)",
                    rows: rows
                )
        )
        let baselineCard = try XCTUnwrap(card.uiKit)
        let movedCard = try XCTUnwrap(card.swiftUI)
        XCTAssertEqual(
            abs(movedCard.width - baselineCard.width), 40, accuracy: DifferentialGeometry.tolerance,
            "the perturbation was reported, but not with the size it was made — the SwiftUI reader "
                + "is not measuring the card it was handed"
        )
    }

    func test_discriminationGuard_uiKitMeasurementRespondsToAPerturbedPreset() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "standard-two-button"))
        // 216 rather than 256, so the card (content + 2x32 padding) stays inside the 350pt available
        // width on both readings and the whole 40pt shows up as a width delta.
        let narrowed = DifferentialGeometry.Shape(
            name: shape.name,
            dialog: shape.dialog,
            properties: shape.properties.copy(
                contentProperty: GBAlertModal.Properties.ContentProperty(
                    backgroundColor: .white,
                    cornerRadius: 16,
                    fixedWidthPortrait: 216,
                    maxWidthPortrait: 216,
                    fixedWidthLandscape: 216,
                    maxWidthLandscape: 216,
                    childShouldMatchParent: true
                )
            )
        )

        // Both sides are UIKit readings here (256pt preset on the left, 216pt on the right).
        let baseline = DifferentialGeometry.uiKitFrames(shape)
        let moved = DifferentialGeometry.uiKitFrames(narrowed)
        let rows = DifferentialGeometry.compare(uiKit: baseline, swiftUI: moved)
        let card = try XCTUnwrap(rows.first { $0.element == .card })

        XCTAssertEqual(
            card.verdict, .differ,
            "a 40pt content-width perturbation on the UIKit side was NOT reported — the UIKit "
                + "reader is not reading the modal it was handed.\n"
                + DifferentialGeometry.table(
                    name: "UIKit 256pt content (left column) vs UIKit 216pt content (right column)",
                    rows: rows
                )
        )
        let wide = try XCTUnwrap(card.uiKit)
        let narrow = try XCTUnwrap(card.swiftUI)
        XCTAssertEqual(
            abs(narrow.width - wide.width), 40, accuracy: DifferentialGeometry.tolerance,
            "the perturbation was reported, but not with the size it was made"
        )
    }

    /// The other side of the discrimination guard: the comparison must also be able to say `agree`.
    /// Without this, a `compare` hard-wired to `DIFFER` would satisfy both perturbation guards.
    func test_discriminationGuard_identicalInputsReportNoDifference() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "standard-two-button"))
        let once = DifferentialGeometry.swiftUIFrames(shape)
        let twice = DifferentialGeometry.swiftUIFrames(shape)
        XCTAssertFalse(once.isEmpty, "nothing was measured, so 'no differences' means nothing")

        let rows = DifferentialGeometry.compare(uiKit: once, swiftUI: twice)
        XCTAssertEqual(
            rows.filter { $0.verdict.isDisagreement }.count, 0,
            "the SAME view measured twice reported a difference — the measurement is not "
                + "deterministic, so no verdict from it can be trusted.\n"
                + DifferentialGeometry.table(name: "self comparison", rows: rows)
        )
        // And it really did compare something, rather than finding both sides empty.
        XCTAssertGreaterThan(rows.filter { $0.verdict == .agree }.count, 0)
    }

    func test_discriminationGuard_toleranceIsSubPixelOnly() {
        let base = CGRect(x: 10, y: 20, width: 100, height: 48)
        XCTAssertTrue(
            DifferentialGeometry.agrees(base, base.offsetBy(dx: 0.4, dy: 0)),
            "sub-pixel rounding must be absorbed"
        )
        XCTAssertFalse(
            DifferentialGeometry.agrees(base, base.offsetBy(dx: 1, dy: 0)),
            "a whole point of displacement must NOT be absorbed — a tolerance that hides a point is "
                + "wide enough to hide a design disagreement"
        )
        XCTAssertFalse(
            DifferentialGeometry.agrees(base, CGRect(x: 10, y: 20, width: 101, height: 48)),
            "a whole point of width must NOT be absorbed"
        )
        XCTAssertFalse(
            DifferentialGeometry.agrees(base, CGRect(x: 10, y: 20, width: 100, height: 49)),
            "a whole point of height must NOT be absorbed"
        )
    }

    func test_discriminationGuard_aPerturbedLayerVisualIsReported() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "standard-two-button"))
        let measured = DifferentialGeometry.uiKitLayerVisuals(shape)

        var noDrop = ModalTokens(from: shape.properties)
        noDrop.obliqueOffset = .zero      // "a corner cut, not a shadow" — the defect that shipped
        XCTAssertNotEqual(
            measured.primaryButton, DifferentialGeometry.swiftUILayerVisuals(shape, tokens: noDrop).primaryButton,
            "removing the oblique drop entirely was NOT reported. This is the exact defect class "
                + "C-3b exists for: the frames are identical either way, so if this comparison is "
                + "blind then nothing in this suite can see the oblique style at all."
        )

        var wrongRadius = ModalTokens(from: shape.properties)
        wrongRadius.buttonCornerRadius += 4
        XCTAssertNotEqual(
            measured.primaryButton,
            DifferentialGeometry.swiftUILayerVisuals(shape, tokens: wrongRadius).primaryButton,
            "a 4pt button corner-radius change was not reported"
        )

        var wrongCard = ModalTokens(from: shape.properties)
        wrongCard.cornerRadius += 4
        XCTAssertNotEqual(
            measured.card, DifferentialGeometry.swiftUILayerVisuals(shape, tokens: wrongCard).card,
            "a 4pt card corner-radius change was not reported"
        )
    }

    // MARK: The one exclusion, verified rather than asserted

    /// `banner` is excluded from every shape, and this proves it is a BUNDLE fact rather than a
    /// convenient omission: the asset does not resolve, so BOTH backends draw no banner and the two
    /// agree about its absence. See `DifferentialGeometry.bannerIsUnresolvableInTheLibraryBundle`.
    func test_bannerExclusion_isABundleFact_notAnOmission() throws {
        let named = ["streak-popup-banner", "database-error-banner"]
        for name in named {
            let shape = try XCTUnwrap(DifferentialGeometry.shape(named: name))
            XCTAssertNotNil(shape.dialog.image, "'\(name)' is supposed to be a banner shape")
            XCTAssertTrue(
                DifferentialGeometry.bannerIsUnresolvableInTheLibraryBundle(shape),
                "'\(name)' banner asset now RESOLVES in the library bundle. The banner exclusion is "
                    + "no longer justified: add `.banner` to the comparison and delete this branch."
            )
            let rows = DifferentialGeometry.rows(for: shape)
            let banner = try XCTUnwrap(rows.first { $0.element == .banner })
            XCTAssertEqual(
                banner.verdict, .absentOnBoth,
                "'\(name)': the banner is absent on one side only, which would be a fixture "
                    + "asymmetry masquerading as a renderer divergence"
            )
        }
    }
}

// MARK: - The differential gate

/// **SwiftUI's computed geometry against UIKit's measured geometry, one test per shape.**
///
/// A failure here is the POINT of this suite, not a defect in it: it means the SwiftUI backend does
/// not lay a real Geniebook dialog out the way the shipping UIKit renderer does, and the failure
/// message is the full element table with both sides' numbers. Do not widen
/// `DifferentialGeometry.tolerance` to turn one of these green — that is the failure mode this whole
/// file exists to make impossible (see `DifferentialGeometryHarnessTests`).
@MainActor
final class DifferentialGeometryTests: XCTestCase {

    func test_geometry_standardOneButton() { assertAgrees("standard-one-button") }
    func test_geometry_standardTwoButton() { assertAgrees("standard-two-button") }
    func test_geometry_titleNilError() { assertAgrees("title-nil-error") }
    func test_geometry_closeButtonDismiss() { assertAgrees("close-button-dismiss") }
    func test_geometry_obliqueRedLeaveConfirm() { assertAgrees("oblique-red-leave-confirm") }
    func test_geometry_permissionDeniedSettings() { assertAgrees("permission-denied-settings") }
    func test_geometry_onboardingWelcomeNoBanner() { assertAgrees("onboarding-welcome-nobanner") }
    func test_geometry_streakPopupBanner() { assertAgrees("streak-popup-banner") }
    func test_geometry_databaseErrorBanner() { assertAgrees("database-error-banner") }

    private func assertAgrees(
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let shape = DifferentialGeometry.shape(named: name) else {
            XCTFail("no differential shape named '\(name)'", file: file, line: line)
            return
        }
        let rows = DifferentialGeometry.rows(for: shape)
        let table = DifferentialGeometry.table(name: name, rows: rows)

        // Honesty first: an empty measurement must never read as agreement.
        guard rows.contains(where: { $0.uiKit != nil }), rows.contains(where: { $0.swiftUI != nil }) else {
            XCTFail(
                "'\(name)': one side measured nothing, so there is no comparison to report.\n" + table,
                file: file, line: line
            )
            return
        }

        let disagreements = rows.filter { $0.verdict.isDisagreement }
        let comparable = rows.filter { $0.verdict != .absentOnBoth }
        XCTAssertTrue(
            disagreements.isEmpty,
            "\(disagreements.count) of \(comparable.count) comparable elements DIFFER.\n" + table,
            file: file, line: line
        )
    }
}

// MARK: - Layer visuals (spec C-3b)

/// **The defect class frames cannot express.**
///
/// The "oblique" primary button turned out to be a hard offset SHADOW, not a diagonal corner cut —
/// and a frame comparison is green through that entire defect, because the shadow falls outside the
/// button's bounds and a corner cut falls inside them. So the three properties where the difference
/// actually lives are compared directly: UIKit's real `CALayer` values, measured after hosting and
/// layout, against the values `ObliquePrimaryStyle` / `AlertModalScaffold.card` render from
/// (`ModalTokens.primaryButtonVisual` / `.cardVisual` — not a transcription of them; the views read
/// those same properties).
///
/// Narrow on purpose: two surfaces, three properties. The secondary button and the close button have
/// no layer identity on either backend (no radius, no shadow), so there is nothing to compare there
/// and nothing is invented.
@MainActor
final class DifferentialLayerVisualTests: XCTestCase {

    func test_layerVisuals_agreeOnEveryShape() throws {
        for shape in DifferentialGeometry.shapes {
            let measured = DifferentialGeometry.uiKitLayerVisuals(shape)
            let declared = DifferentialGeometry.swiftUILayerVisuals(shape)
            XCTAssertEqual(
                measured.card, declared.card,
                "'\(shape.name)' CARD layer visual: UIKit measured \(measured.card), SwiftUI renders "
                    + "\(declared.card)"
            )
            XCTAssertEqual(
                measured.primaryButton, declared.primaryButton,
                "'\(shape.name)' PRIMARY BUTTON layer visual: UIKit measured "
                    + "\(String(describing: measured.primaryButton)), SwiftUI renders "
                    + "\(String(describing: declared.primaryButton))"
            )
        }
    }

    /// A CONDITIONAL cross-check, and it says so.
    ///
    /// SwiftUI is free to render `.shadow(...)` into its own drawing layer instead of setting
    /// `CALayer.shadowOffset`, so finding NO lowered shadow proves nothing and passes. But if SwiftUI
    /// did lower one, its offset must be the token offset — otherwise the two backends disagree about
    /// the oblique drop while every frame matches, which is precisely the invisible case.
    func test_layerVisuals_whenSwiftUILowersAShadowToALayer_itIsTheTokenOffset() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "standard-two-button"))
        let offsets = DifferentialGeometry.swiftUIHostedShadowOffsets(shape)
        guard !offsets.isEmpty else {
            // Recorded, not asserted: SwiftUI drew the drop without a CALayer shadow, so the
            // declared-token comparison above is the only available reading.
            return
        }
        let expected = DifferentialGeometry.CGSizeKey(
            ModalTokens(from: shape.properties).primaryButtonVisual.shadowOffset
        )
        XCTAssertTrue(
            offsets.contains(expected),
            "SwiftUI lowered shadow offsets \(offsets.map(\.description).sorted()) to real layers, "
                + "none of which is the oblique token offset \(expected)"
        )
    }
}

// MARK: - Root cause

/// The differential gate reports a disagreement; this isolates WHY, so the report names a cause
/// rather than a symptom.
///
/// Hypothesis: `ModalTokens.init(from:)` maps `ContentProperty.maxWidthPortrait` onto
/// `cardMaxWidth`, but those are not the same measurement. In UIKit that number constrains
/// `svContentContainer` — the stack INSIDE the card — and the card (`vwContainer`) is wider by the
/// horizontal content padding on each side. In SwiftUI `cardMaxWidth` caps the CARD, whose padding
/// is subtracted from it. So one preset value produces a card of `width + 2 * padding` on UIKit and
/// `width` on SwiftUI, and a content area of `width` versus `width - 2 * padding`.
///
/// If the hypothesis holds, adding the horizontal padding back makes the two card widths — and the
/// primary button's width, which fills the content area on both backends — agree EXACTLY. That is
/// the assertion below. It also doubles as a second, independent discrimination signal: it produces
/// an AGREEMENT through the full measurement pipeline on both sides, which a harness that can only
/// ever report `DIFFER` could not.
@MainActor
final class DifferentialGeometryRootCauseTests: XCTestCase {

    func test_cardWidthAgrees_onceTheContentWidthIsNotTreatedAsTheCardWidth() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "standard-two-button"))
        var corrected = ModalTokens(from: shape.properties)
        corrected.cardMaxWidth += 2 * corrected.contentPaddingH

        let uiKit = DifferentialGeometry.uiKitFrames(shape)
        let swiftUI = DifferentialGeometry.swiftUIFrames(shape, tokens: corrected)
        let rows = DifferentialGeometry.compare(uiKit: uiKit, swiftUI: swiftUI)
        let table = DifferentialGeometry.table(name: "\(shape.name) [corrected cardMaxWidth]", rows: rows)

        let card = try XCTUnwrap(rows.first { $0.element == .card })
        let uiKitCard = try XCTUnwrap(card.uiKit)
        let swiftUICard = try XCTUnwrap(card.swiftUI)
        XCTAssertEqual(
            uiKitCard.width, swiftUICard.width,
            accuracy: DifferentialGeometry.tolerance,
            "card WIDTH still disagrees after adding the horizontal content padding back, so the "
                + "conflation is not the whole story.\n" + table
        )

        let primary = try XCTUnwrap(rows.first { $0.element == .primaryButton })
        let uiKitPrimary = try XCTUnwrap(primary.uiKit)
        let swiftUIPrimary = try XCTUnwrap(primary.swiftUI)
        XCTAssertEqual(
            uiKitPrimary.width, swiftUIPrimary.width,
            accuracy: DifferentialGeometry.tolerance,
            "the primary button fills the content area on both backends, so its width should follow "
                + "the corrected card width.\n" + table
        )
    }
}
