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
/// * `test_discriminationGuard_theHuggedLabelExclusionIsNarrow` pins the harness's ONE measurement
///   exclusion — UIKit's whole-point rounding of a hugging label's intrinsic width — to exactly the
///   shape of that rounding: a whole point, a fractional UIKit width, a UIKit width NARROWER than
///   SwiftUI's, a drifted centre, a moved y and a changed height are all still reported, and the
///   exclusion applies to one element. If it ever degrades into "1pt is fine here", this goes RED.
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
        // +20 on the CONTENT cap, which moves the card by the same 20 (the card is content + 32 + 32).
        //
        // It was +40 while `cardMaxWidth` was a stored field applied to the card; now that the card's
        // cap is DERIVED (`contentMaxWidth + leftMax + rightMax`, i.e. 256 + 64 = 320) the headroom
        // before the 350pt available width clamps the card is 30pt, and a 40pt perturbation would be
        // reported as 30 — a guard failing for a reason that has nothing to do with discrimination.
        // 20pt is still FORTY times the 0.5pt tolerance, so what this proves is unchanged.
        perturbed.contentMaxWidth += 20   // card 320 -> 340, inside the 350pt available width

        // Both sides of this one comparison are SwiftUI readings (baseline on the left, perturbed on
        // the right) — the guard is about whether `compare` SEES a change, so it holds the renderer
        // fixed and moves one token.
        let baseline = DifferentialGeometry.swiftUIFrames(shape)
        let moved = DifferentialGeometry.swiftUIFrames(shape, tokens: perturbed)
        let rows = DifferentialGeometry.compare(uiKit: baseline, swiftUI: moved)
        let card = try XCTUnwrap(rows.first { $0.element == .card })

        XCTAssertEqual(
            card.verdict, .differ,
            "a 20pt card-width perturbation on the SwiftUI side was NOT reported. The comparison "
                + "cannot detect a difference introduced on purpose, so it cannot detect a real one.\n"
                + DifferentialGeometry.table(
                    name: "SwiftUI baseline (left column) vs SwiftUI +20pt contentMaxWidth (right column)",
                    rows: rows
                )
        )
        let baselineCard = try XCTUnwrap(card.uiKit)
        let movedCard = try XCTUnwrap(card.swiftUI)
        XCTAssertEqual(
            abs(movedCard.width - baselineCard.width), 20, accuracy: DifferentialGeometry.tolerance,
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

    /// **The guard on the one exclusion.**
    ///
    /// `DifferentialGeometry.agreesOnAHuggedLabel` absorbs UIKit's whole-point rounding of a hugging
    /// label's intrinsic width — and nothing else. This pins "nothing else", because an exclusion that
    /// quietly became a 1pt tolerance would let a real design difference through on the two shapes that
    /// use it, and no other test would see it.
    ///
    /// The 0.5pt tolerance stays in force for every other element:
    /// `test_discriminationGuard_toleranceIsSubPixelOnly` tests `agrees`, which is what every
    /// non-hug element is still compared with, and this test's own first assertion shows the strict
    /// predicate rejects the very case the exclusion accepts.
    func test_discriminationGuard_theHuggedLabelExclusionIsNarrow() {
        // The real measurement it exists for: UIKit 54.0 (an integral ceiling) against SwiftUI 53.3,
        // both centred on the same point (so the leading edges differ by half the width delta).
        let uiKit = CGRect(x: 133.0, y: 112, width: 54.0, height: 48)
        let swiftUI = CGRect(x: 133.3, y: 112, width: 53.3, height: 48)
        XCTAssertFalse(
            DifferentialGeometry.agrees(uiKit, swiftUI),
            "premise: the STRICT predicate must reject this, or the exclusion is not doing anything "
                + "and this test proves nothing"
        )
        XCTAssertTrue(
            DifferentialGeometry.agreesOnAHuggedLabel(uiKit: uiKit, swiftUI: swiftUI),
            "the rounding this exclusion is argued for was not accepted"
        )

        // A WHOLE POINT wider is a design difference, not a rounding: rejected.
        XCTAssertFalse(
            DifferentialGeometry.agreesOnAHuggedLabel(
                uiKit: CGRect(x: 132.5, y: 112, width: 55.0, height: 48), swiftUI: swiftUI
            ),
            "1.0pt of hug width was absorbed — that is a tolerance, not a rounding rule"
        )
        // A NON-INTEGRAL UIKit width cannot be a ceiling, so the mechanism does not apply: rejected.
        XCTAssertFalse(
            DifferentialGeometry.agreesOnAHuggedLabel(
                uiKit: CGRect(x: 133.0, y: 112, width: 54.5, height: 48),
                swiftUI: CGRect(x: 133.3, y: 112, width: 53.8, height: 48)
            ),
            "a fractional UIKit width was accepted as a rounded-up one"
        )
        // UIKit NARROWER than SwiftUI is not a ceiling either: rejected.
        XCTAssertFalse(
            DifferentialGeometry.agreesOnAHuggedLabel(
                uiKit: CGRect(x: 133.6, y: 112, width: 53.0, height: 48), swiftUI: swiftUI
            ),
            "a UIKit width NARROWER than SwiftUI's was accepted as a rounding of it"
        )
        // The rounding excuse must not buy anything on the other three edges: a drifted CENTRE, a
        // different y and a different height are all still reported.
        XCTAssertFalse(
            DifferentialGeometry.agreesOnAHuggedLabel(
                uiKit: CGRect(x: 140.0, y: 112, width: 54.0, height: 48), swiftUI: swiftUI
            ),
            "a hug that drifted sideways was absorbed"
        )
        XCTAssertFalse(
            DifferentialGeometry.agreesOnAHuggedLabel(
                uiKit: CGRect(x: 133.0, y: 113, width: 54.0, height: 48), swiftUI: swiftUI
            ),
            "a 1pt y difference was absorbed"
        )
        XCTAssertFalse(
            DifferentialGeometry.agreesOnAHuggedLabel(
                uiKit: CGRect(x: 133.0, y: 112, width: 54.0, height: 49), swiftUI: swiftUI
            ),
            "a 1pt height difference was absorbed"
        )

        // And it is scoped: exactly one element is compared this way, and it is the one whose width
        // UIKit takes from a label rather than from a container.
        XCTAssertEqual(DifferentialGeometry.hugWidthElements, [.secondaryButton])
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

    /// The scrolling path, gated for the first time — see the shape's note in
    /// `DifferentialGeometrySupport`. Every other shape here is short enough that UIKit's subtitle
    /// scroll slot IS its label's height, so this is the only one that compares the two backends
    /// while both are actually scrolling.
    /// **The scrolling path, gated element by element — because one element is not comparable.**
    ///
    /// Deliberately NOT `assertAgrees`, which would demand every row agree and would have to be
    /// silenced wholesale. Three of the four rows DO agree, exactly, and that is a real new
    /// guarantee: two backends both scrolling produce the same card, the same title and the same
    /// button position. Measured — card 778.0 both, title 28.7 both, primary button y 711.0 both.
    ///
    /// The `subtitle` row cannot agree, and not because either backend is wrong: the two probes are
    /// on different things once a scroll exists. UIKit's `.subtitle` sits on `svSubtitleContainer` —
    /// the VIEWPORT (645.3) — while SwiftUI's sits on the `Text` — the CONTENT (1222.0). SwiftUI has
    /// no per-subtitle viewport to probe, because its scroll wraps title AND subtitle together.
    /// That is the residue of D-7, now stated in numbers instead of prose.
    func test_geometry_longSubtitleScrolling_agreesExceptOnTheScrollViewport() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "long-subtitle-scrolling"))
        let rows = DifferentialGeometry.rows(for: shape)

        for element in [ModalGeometryElement.card, .title, .primaryButton] {
            let row = try XCTUnwrap(rows.first { $0.element == element })
            XCTAssertFalse(
                row.verdict.isDisagreement,
                "'\(element)' disagrees under scrolling — the outer geometry of the two scrolling "
                    + "backends is supposed to be identical. Full table:\n"
                    + DifferentialGeometry.table(name: shape.name, rows: rows)
            )
        }

        // And the one that cannot: pinned by its MECHANISM, so that if SwiftUI ever grows a real
        // per-subtitle viewport this fails and says to compare the two properly rather than leaving
        // a stale exception behind.
        let subtitle = try XCTUnwrap(rows.first { $0.element == .subtitle })
        let uiKit = try XCTUnwrap(subtitle.uiKit)
        let swiftUI = try XCTUnwrap(subtitle.swiftUI)
        XCTAssertLessThan(
            uiKit.height, swiftUI.height,
            "UIKit's subtitle probe is no longer smaller than SwiftUI's. It is supposed to be a "
                + "scroll VIEWPORT measured against SwiftUI's CONTENT; if that is no longer true, "
                + "the two are finally comparable and this exception should be replaced by a real "
                + "row in the gate."
        )
    }

    /// **The banner, compared for the first time.**
    ///
    /// `bannerIsUnresolvableInTheLibraryBundle` is still correct for every OTHER shape — their assets
    /// live in the app — so the exclusion stays. This shape sidesteps it by naming the test target's
    /// own resource bundle, which is what `ModalImage.bundleIdentifier` exists for.
    /// Gated element-by-element, because the banner's HEIGHT is a live, measured divergence and
    /// `assertAgrees` would have to be silenced wholesale to accommodate it.
    ///
    /// **What agrees, and it did not before:** the banner's x and WIDTH. UIKit's `vwBanner` fills the
    /// 256pt content column; SwiftUI drew 47.7pt wide, centred, because the row was deliberately not
    /// given `ContentRowWidth` on reasoning no gate could check. Now both are `x 32, w 256`.
    ///
    /// **What does NOT agree — an open bug, recorded in numbers rather than prose:** the HEIGHT.
    /// UIKit's slot is 160pt; SwiftUI's is 26.8. UIKit models the banner as TWO views — `vwBanner`
    /// fills the content column and `ivBanner` is ratio-sized inside it, so the slot's height follows
    /// the ratio-sized image (square at `bannerRatio: 1`, sized from the 160pt-wide source). SwiftUI
    /// has one view carrying `.resizable().scaledToFit()` plus `ModalBannerGeometry`, and an outer
    /// width frame does not make it grow vertically. Everything below the banner is displaced by the
    /// difference, which is why the card comes out 70pt shorter.
    ///
    /// Pinned as an INEQUALITY rather than as the current numbers, so the day SwiftUI's banner height
    /// reaches UIKit's this test fails and says to promote the row to a full comparison — instead of
    /// freezing today's wrong answer as the expectation.
    func test_geometry_bannerComparable_agreesOnWidth_notYetOnHeight() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "banner-comparable"))
        let rows = DifferentialGeometry.rows(for: shape)
        let banner = try XCTUnwrap(rows.first { $0.element == .banner })
        let uiKit = try XCTUnwrap(banner.uiKit)
        let swiftUI = try XCTUnwrap(banner.swiftUI)

        XCTAssertEqual(
            swiftUI.minX, uiKit.minX, accuracy: DifferentialGeometry.tolerance,
            "the banner is no longer aligned to the content column"
        )
        XCTAssertEqual(
            swiftUI.width, uiKit.width, accuracy: DifferentialGeometry.tolerance,
            "the banner no longer fills the content width the way vwBanner does"
        )
        XCTAssertLessThan(
            swiftUI.height, uiKit.height,
            "SwiftUI's banner height has reached UIKit's. That is the OPEN BUG being tracked here — "
                + "if it is fixed, replace this test with `assertAgrees(\"banner-comparable\")` and "
                + "delete the height exception rather than leaving a stale one behind."
        )
    }

    /// And the premise: the `.banner` row must carry TWO frames. If the asset failed to resolve the
    /// row would read `absent (both)` — agreement about an absence — and the test above would pass
    /// while measuring nothing, which is the exact failure mode the banner exclusion was documented
    /// to avoid.
    func test_theBannerRow_actuallyMeasuresABanner() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "banner-comparable"))
        XCTAssertFalse(
            DifferentialGeometry.bannerIsUnresolvableInTheLibraryBundle(shape),
            "the banner asset stopped resolving, so this shape is back to comparing nothing"
        )
        let rows = DifferentialGeometry.rows(for: shape)
        let banner = try XCTUnwrap(rows.first { $0.element == .banner })
        XCTAssertNotNil(banner.uiKit, "UIKit drew no banner")
        XCTAssertNotNil(banner.swiftUI, "SwiftUI drew no banner")
        XCTAssertNotEqual(
            banner.verdict, .absentOnBoth,
            "the banner row is an absence, not a comparison"
        )
    }

    // MARK: - Landscape, gated for the first time

    /// **Every landscape fix in this module was verified by snapshot and by eye until now.**
    ///
    /// The harness hosted portrait only, because `SwiftUIAlertModal` hardcoded `isLandscape: false`
    /// for the resolver — a landscape comparison would have measured that assumption rather than the
    /// layout. Both backends now read orientation from the container they are given, so this is the
    /// same element-for-element comparison the portrait rows get, at 844x390.
    ///
    /// This is the coverage gap that mattered most: the subtitle floor, the whitespace rung, the
    /// ladder ordering and the zeroed vertical margin are ALL landscape-motivated changes, and none
    /// of them was ever checked against UIKit's measured numbers.
    func test_geometry_landscape_standardOneButton() { assertAgrees("standard-one-button", size: DifferentialGeometry.landscapeHost) }
    func test_geometry_landscape_standardTwoButton() { assertAgrees("standard-two-button", size: DifferentialGeometry.landscapeHost) }
    func test_geometry_landscape_permissionDenied() { assertAgrees("permission-denied-settings", size: DifferentialGeometry.landscapeHost) }
    func test_geometry_landscape_obliqueRedLeaveConfirm() { assertAgrees("oblique-red-leave-confirm", size: DifferentialGeometry.landscapeHost) }
    func test_geometry_landscape_onboardingWelcomeNoBanner() { assertAgrees("onboarding-welcome-nobanner", size: DifferentialGeometry.landscapeHost) }

    /// **The premise behind the row above — without this it is another vacuous agreement.**
    ///
    /// The whole reason D-7 stayed open is that every shape in the gate is short enough for UIKit's
    /// `svSubtitleContainer` to be exactly its label's height, so "the slot agrees with the `Text`"
    /// was true for a reason that had nothing to do with scrolling. A new shape that ALSO fails to
    /// engage the scroll would extend that mistake rather than fix it.
    ///
    /// So: the UIKit slot must be strictly shorter than its content (it is scrolling), and the
    /// SwiftUI side must have `contentScrollable` on. Then the agreement above is a statement about
    /// two scrolling backends.
    @MainActor
    func test_theScrollingShape_actuallyScrolls() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "long-subtitle-scrolling"))

        XCTAssertTrue(
            ModalTokens(from: shape.properties).contentScrollable,
            "the SwiftUI side of this shape is not scrolling, so the row compares a scroll against a "
                + "plain column"
        )

        let modal = GBAlertModal(
            properties: shape.properties,
            holder: UIKitModalRenderer.AlertHolder.make(for: shape.dialog, resolve: { _ in })
        )
        renderForSnapshot(modal, size: DifferentialGeometry.host)
        let slot = try XCTUnwrap(modal.svSubtitleContainer)

        XCTAssertLessThan(
            slot.bounds.height, slot.contentSize.height - 0.5,
            "UIKit's subtitle slot (\(slot.bounds.height)pt) is not shorter than its content "
                + "(\(slot.contentSize.height)pt) — this shape does not engage the scroll, so the "
                + "differential row it feeds proves nothing about the scrolling path"
        )
    }

    private func assertAgrees(
        _ name: String,
        size: CGSize = DifferentialGeometry.host,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let shape = DifferentialGeometry.shape(named: name) else {
            XCTFail("no differential shape named '\(name)'", file: file, line: line)
            return
        }
        let rows = DifferentialGeometry.rows(for: shape, size: size)
        let orientation = size.width > size.height ? "landscape" : "portrait"
        let table = DifferentialGeometry.table(name: "\(name) [\(orientation)]", rows: rows)

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

/// The differential gate reports a WIDTH; this isolates the one decision it comes from, so a
/// regression names a cause rather than a symptom.
///
/// The cause, now fixed in production: `ModalTokens.init(from:)` used to map
/// `ContentProperty.maxWidthPortrait` onto a field called `cardMaxWidth` which
/// `AlertModalScaffold` applied to the CARD. Those are not the same measurement. In UIKit that number
/// constrains `svContentContainer` — the stack INSIDE the card — and the card (`vwContainer`) ends up
/// wider by the horizontal content padding on each side. So one preset value produced a card of
/// `width + 2 * padding` on UIKit and `width` on SwiftUI, and a content area of `width` versus
/// `width − 2 * padding`: 320/256 against 256/192 on the real preset.
///
/// This class asserts BOTH DIRECTIONS, and the second one is why it still earns its place now that
/// the per-shape gate is green:
///
/// 1. **The width agrees through the full pipeline**, on the card and on the primary button (which
///    fills the content area on both backends). This is also a second, independent discrimination
///    signal — an AGREEMENT produced through both complete measurement paths, which a harness that
///    could only ever report `DIFFER` would fail.
/// 2. **Re-introducing the conflation is still reported.** Subtracting `2 × leftMax` from
///    `contentMaxWidth` reproduces the shipped defect EXACTLY (card 256, content 192) and must come
///    back as a 64pt card disagreement. Without this, a future change that quietly re-conflated the
///    two levels would only be caught by the nine per-shape tests — and this file exists because
///    "the suite went green" is not, on its own, evidence about the layout.
@MainActor
final class DifferentialGeometryRootCauseTests: XCTestCase {

    func test_cardWidthAgrees_onceTheContentWidthIsNotTreatedAsTheCardWidth() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "standard-two-button"))
        let tokens = ModalTokens(from: shape.properties)
        XCTAssertEqual(tokens.contentMaxWidth, 256, "premise: the preset states a 256pt CONTENT width")
        XCTAssertEqual(tokens.cardMaxWidth, 320, "premise: the CARD is that plus 32 + 32 of padding")

        let uiKit = DifferentialGeometry.uiKitFrames(shape)
        let swiftUI = DifferentialGeometry.swiftUIFrames(shape)
        let rows = DifferentialGeometry.compare(uiKit: uiKit, swiftUI: swiftUI)
        let table = DifferentialGeometry.table(name: shape.name, rows: rows)

        let card = try XCTUnwrap(rows.first { $0.element == .card })
        let uiKitCard = try XCTUnwrap(card.uiKit)
        let swiftUICard = try XCTUnwrap(card.swiftUI)
        XCTAssertEqual(
            uiKitCard.width, swiftUICard.width,
            accuracy: DifferentialGeometry.tolerance,
            "card WIDTH disagrees. The preset's width must be applied to the CONTENT container on "
                + "both backends, with the card coming out as content + leftMax + rightMax.\n" + table
        )

        let primary = try XCTUnwrap(rows.first { $0.element == .primaryButton })
        let uiKitPrimary = try XCTUnwrap(primary.uiKit)
        let swiftUIPrimary = try XCTUnwrap(primary.swiftUI)
        XCTAssertEqual(
            uiKitPrimary.width, swiftUIPrimary.width,
            accuracy: DifferentialGeometry.tolerance,
            "the primary button fills the content area on both backends, so its width follows the "
                + "content width.\n" + table
        )
    }

    /// The other direction: the defect that shipped is still VISIBLE to this harness.
    func test_reConflatingTheContentWidthWithTheCardWidth_isStillReported() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "standard-two-button"))
        var conflated = ModalTokens(from: shape.properties)
        // Exactly the shipped defect: the card is capped at the number the preset states for the
        // CONTENT (256), and the padding is then subtracted from it (content 192).
        conflated.contentMaxWidth -= 2 * conflated.contentPadding.leftMax

        let uiKit = DifferentialGeometry.uiKitFrames(shape)
        let swiftUI = DifferentialGeometry.swiftUIFrames(shape, tokens: conflated)
        let rows = DifferentialGeometry.compare(uiKit: uiKit, swiftUI: swiftUI)
        let table = DifferentialGeometry.table(name: "\(shape.name) [re-conflated]", rows: rows)

        let card = try XCTUnwrap(rows.first { $0.element == .card })
        XCTAssertEqual(
            card.verdict, .differ,
            "re-introducing the content-width/card-width conflation was NOT reported. That is the "
                + "defect this whole suite exists to catch, and it is 64pt wide.\n" + table
        )
        let uiKitCard = try XCTUnwrap(card.uiKit)
        let swiftUICard = try XCTUnwrap(card.swiftUI)
        XCTAssertEqual(
            uiKitCard.width - swiftUICard.width,
            2 * conflated.contentPadding.leftMax,
            accuracy: DifferentialGeometry.tolerance,
            "reported, but not with the size of the defect — the SwiftUI card should be exactly the "
                + "horizontal padding narrower on both sides.\n" + table
        )
    }
}
