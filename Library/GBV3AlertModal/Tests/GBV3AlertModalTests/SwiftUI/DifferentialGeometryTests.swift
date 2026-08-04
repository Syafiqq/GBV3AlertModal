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
    /// The `subtitle` row cannot agree — and **the reason has changed, so read this rather than
    /// remembering it.** It used to be D-7: SwiftUI had no per-subtitle viewport at all, so its probe
    /// sat on a `Text` reporting CONTENT (1222.0) against UIKit's `svSubtitleContainer` reporting a
    /// VIEWPORT (645.3). `SwiftUIAlertModal.SubtitleSlot` supplies that viewport now, unconditionally,
    /// and `long-subtitle-unscrolled` — the identical dialog with `contentScrollable` OFF — measures
    /// **645.33 against 645.33** and goes through the full `assertAgrees`, subtitle row included.
    ///
    /// What is left here is `contentScrollable` itself, which is a SwiftUI-ONLY feature: it wraps
    /// title AND subtitle in an outer `ScrollableContent`, and inside that the height proposal is
    /// unbounded, so the subtitle slot is never pressured and reports its full 1222. UIKit has no
    /// wrapper to correspond to it and compresses its own slot as usual. So this row is not a missing
    /// capability any more; it is the measured cost of a divergence the owner chose on purpose, and
    /// it is an input to whether `contentScrollable` should exist at all
    /// (`docs/superpowers/specs/2026-08-02-content-scrollable-review.md`).
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

        // And the one that cannot: pinned by its MECHANISM, so that if the outer scroll ever stops
        // de-pressurising the subtitle slot this fails and says to compare the two properly rather
        // than leaving a stale exception behind.
        let subtitle = try XCTUnwrap(rows.first { $0.element == .subtitle })
        let uiKit = try XCTUnwrap(subtitle.uiKit)
        let swiftUI = try XCTUnwrap(subtitle.swiftUI)
        XCTAssertLessThan(
            uiKit.height, swiftUI.height,
            "UIKit's subtitle probe is no longer smaller than SwiftUI's. It is supposed to be a "
                + "compressed VIEWPORT measured against a slot that `ScrollableContent` has removed "
                + "all height pressure from; if that is no longer true, the two are finally "
                + "comparable and this shape should join `long-subtitle-unscrolled` in "
                + "`assertAgrees` instead of keeping an exception."
        )
    }

    /// **The same 1222pt subtitle with `contentScrollable` OFF — compared in full, subtitle included.**
    ///
    /// This is the real comparison the inequality above stood in for. UIKit compresses
    /// `svSubtitleContainer` to a 645.33pt viewport; `SwiftUIAlertModal.SubtitleSlot` compresses to
    /// 645.33pt; every other row was already exact. Nothing here is excluded and nothing is pinned by
    /// mechanism — it is the ordinary gate at the ordinary 0.5pt.
    ///
    /// Its premise (that the slot is genuinely engaged at this length) is
    /// `test_theUnscrolledShape_actuallyClipsOnBothBackends`.
    func test_geometry_longSubtitleUnscrolled() { assertAgrees("long-subtitle-unscrolled") }

    /// And in landscape, where the viewport falls to 161.33 on BOTH backends — a quarter of the
    /// content, on a card against its ceiling. This is the same regime `banner-comparable` is in,
    /// with the banner taken out of the picture.
    func test_geometry_landscape_longSubtitleUnscrolled() {
        assertAgrees("long-subtitle-unscrolled", size: DifferentialGeometry.landscapeHost)
    }

    /// **The premise for both of those: the FIXTURE is long enough to engage the slot at all.**
    ///
    /// Same failure mode `test_theScrollingShape_actuallyScrolls` exists for — a shape whose content
    /// happens to fit makes its comparison vacuous, and the card's ceiling has moved once already on
    /// this branch. Asserted in both orientations, against the content the slot is holding.
    ///
    /// **UIKit only, and that is deliberate rather than an omission.** The obvious SwiftUI half — "its
    /// subtitle row is shorter than its content too" — was written, and it PASSES against a build with
    /// no `SubtitleSlot` in it: a `Text` under `NeverTruncates` answers pressure by scaling its glyphs,
    /// so it is also shorter than its unpressured height, for an entirely different reason. The probe
    /// reports a rectangle and cannot tell a clipped viewport from shrunken type, so that assertion
    /// would have read as a guarantee while being unable to fail. The SwiftUI side's non-vacuity is
    /// carried instead by `test_bannerComparable_landscape_bothBackendsAreClippingTheSubtitle`, whose
    /// subtitle is short enough that no scaling is in play and which does go red without the slot.
    func test_theUnscrolledShape_actuallyClipsItsSubtitle() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "long-subtitle-unscrolled"))

        for size in [DifferentialGeometry.host, DifferentialGeometry.landscapeHost] {
            let modal = DifferentialGeometry.makeUIKitModal(shape)
            let window = DifferentialGeometry.makeWindow(size: size)
            defer { DifferentialGeometry.teardown(window) }
            modal.show(parent: window, completion: {})
            window.setNeedsLayout()
            window.layoutIfNeeded()
            let viewport = try XCTUnwrap(modal.svSubtitleContainer, "UIKit built no subtitle slot")
            let content = try XCTUnwrap(modal.lbSubtitle, "UIKit built no subtitle label").bounds.height

            XCTAssertLessThan(
                viewport.bounds.height, content - DifferentialGeometry.tolerance,
                "at \(size) UIKit's subtitle viewport (\(viewport.bounds.height)pt) is not smaller "
                    + "than its \(content)pt of content, so the shape no longer engages the slot and "
                    + "its comparison is vacuous. Lengthen the subtitle."
            )
        }
    }

    /// **The banner, compared element-for-element.**
    ///
    /// This replaces an inequality pin (`swiftUI.height < uiKit.height`) that recorded the open bug
    /// rather than freezing its wrong numbers. The bug is closed: UIKit's slot is 256x160 (the
    /// artwork is 160pt wide at ratio 1, so `max(imageH, imageW/r)` is 160) and SwiftUI now
    /// computes the same from `ModalTokens.bannerGeometry`.
    ///
    /// `bannerIsUnresolvableInTheLibraryBundle` is still correct for every OTHER banner shape —
    /// their assets live in the app — so that exclusion stays. This shape sidesteps it by naming
    /// the test target's own resource bundle, which is what `ModalImage.bundleIdentifier` is for.
    func test_geometry_bannerComparable() { assertAgrees("banner-comparable") }

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

    /// The wide-artwork case — see the shape's note. This is the regime every real app banner is in.
    func test_geometry_bannerWide() { assertAgrees("banner-wide") }

    /// The premise: this shape must actually be in the wider-than-column regime, or it is just
    /// `banner-comparable` with a different asset and proves nothing.
    func test_bannerWide_actuallyExceedsTheColumn() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "banner-wide"))
        let artwork = try XCTUnwrap(shape.dialog.image).pointSize
        // The TOKEN, not `contentProperty.maxWidthPortrait`. They are the same number for every
        // preset in the app, and they are not the same QUANTITY: `ModalTokens.init(from:)` folds all
        // four width fields into one cap as `min(fixed, max)` when both are set, and that resolved
        // value is what `bannerGeometry` and `AlertModalScaffold` actually lay out with. Reading the
        // raw `Properties` field here meant a premise about column growth was checked against a
        // number the code under test does not use — inert today, wrong the moment a preset sets a
        // fixed width below its max.
        let column = ModalTokens(from: shape.properties).contentMaxWidth
        XCTAssertGreaterThan(
            artwork.width, column,
            "'banner-wide' artwork (\(artwork.width)pt) no longer exceeds the column (\(column)pt), "
                + "so this shape has stopped testing column growth"
        )
        let frames = DifferentialGeometry.uiKitFrames(shape)
        let banner = try XCTUnwrap(frames[.banner])
        XCTAssertGreaterThan(
            banner.width, column,
            "UIKit stopped widening the column for wide artwork — the rule in "
                + "ModalTokens.bannerGeometry is now wrong, not just this shape"
        )
    }

    /// **The ceiling's honesty, on a host wide enough for the card's own cap to bite.**
    ///
    /// `AlertModalScaffold.body` derives `availableCardWidth` from the HOST
    /// (`proxy.size.width − 2·cardMarginH`) and not from `tokens.cardMaxWidth`. On a host wider than
    /// `cardMaxWidth + 2·cardMarginH` — landscape, or any iPad — that is a larger number than a card
    /// pinned at `cardMaxWidth` could ever hand the column, and it was harmless only while `column`
    /// could not exceed `contentMaxWidth`. It can now, and `BannerSlot`'s WIDTH frame is RIGID
    /// (`.frame(width:)`, not `maxWidth` — only its HEIGHT yields), so a column wider than its
    /// container would be an overflow rather than a layout that compresses. Not even a clipped one:
    /// the slot carries no `.clipped()`, and UIKit's `vwBanner` sets no `clipsToBounds` either.
    ///
    /// What makes it safe is the card cap growing by the SAME `column` (see `body`'s note): the card
    /// is `min(host − 2·cardMarginH, max(cardMaxWidth, column + leftMax + rightMax))`, so either the
    /// host clamps it — and then `column ≤ host − 2·cardMarginH − leftMin − rightMin` by the ceiling
    /// itself — or it does not, and the card is at least `column + leftMax + rightMax`, which clears
    /// `column + leftMin + rightMin`. Either way the slot fits. That argument is only as good as its
    /// two premises, so this asserts the CONSEQUENCE at three host widths that exercise both branches
    /// rather than restating the algebra.
    func test_bannerWide_theSlotNeverOverflowsTheCard_atAnyHostWidth() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "banner-wide"))
        // 390x844 clamps the card (350 < the 374 it asks for); 844x390 and the iPad-width host do
        // not, and are the hosts on which the host-derived ceiling over-reports.
        let hosts: [(String, CGSize)] = [
            ("portrait phone", DifferentialGeometry.host),
            ("landscape phone", DifferentialGeometry.landscapeHost),
            ("iPad-width", DifferentialGeometry.iPadWidthHost)
        ]
        for (label, size) in hosts {
            let frames = DifferentialGeometry.swiftUIFrames(shape, size: size)
            let card = try XCTUnwrap(frames[.card], "\(label): SwiftUI measured no card")
            let banner = try XCTUnwrap(frames[.banner], "\(label): SwiftUI drew no banner")
            // Frames are normalised to the card's origin, so the card spans 0...card.width.
            XCTAssertGreaterThanOrEqual(
                banner.minX, -Self.containmentSlack,
                "\(label) (\(size.width)pt): the banner slot starts \(-banner.minX)pt LEFT of the "
                    + "card. The column outgrew its container — `availableCardWidth`'s ceiling and "
                    + "the card's cap have stopped agreeing."
            )
            XCTAssertLessThanOrEqual(
                banner.maxX, card.width + Self.containmentSlack,
                "\(label) (\(size.width)pt): the banner slot (\(banner.width)pt, ending at "
                    + "\(banner.maxX)) overflows the card (\(card.width)pt) — the column was "
                    + "allowed a width the card cannot give."
            )
            // And the slot must still be inside the card's RIGID minimum padding, which is the
            // bound `bannerGeometry`'s ceiling is written against.
            let minima = ModalTokens(from: shape.properties).contentPadding
            XCTAssertLessThanOrEqual(
                banner.width, card.width - minima.leftMin - minima.rightMin + Self.containmentSlack,
                "\(label) (\(size.width)pt): the banner slot (\(banner.width)pt) is wider than the "
                    + "card (\(card.width)pt) minus its required minimum padding — UIKit's "
                    + "`.required` leading/trailing inequalities would not permit this."
            )
        }
    }

    /// **Slack for a SAME-BACKEND containment assertion, and deliberately not
    /// `DifferentialGeometry.tolerance`.**
    ///
    /// The three assertions above compare SwiftUI frames against other SwiftUI frames from the same
    /// measurement pass — the banner slot against the card that contains it. They used to borrow the
    /// harness's 0.5pt `tolerance`, whose stated rationale is CROSS-backend: "Auto Layout resolves to
    /// fractional points and SwiftUI rounds to the display scale, so a shared edge can legitimately
    /// land half a point apart". Neither Auto Layout nor a second renderer is anywhere near these
    /// numbers, so that argument does not reach them; borrowing the constant made the assertion look
    /// as if it did.
    ///
    /// The real reason a containment check needs any slack at all is different and smaller: both
    /// edges are rounded to the same display scale, so the residual is at most one device pixel —
    /// 1/3pt at 3x, 1/2pt at 2x. `0.5` is that bound at the coarsest scale this library supports,
    /// which is why the NUMBER is unchanged while the justification is not. It is a local constant so
    /// that a future change to the cross-backend tolerance cannot silently move it, and so that
    /// neither can be widened on the strength of the other's argument.
    private static let containmentSlack: CGFloat = 0.5

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

    /// **`banner-wide` in landscape — gated for the first time, on every origin and every height.**
    ///
    /// This shape used to have no landscape comparison at all. `BannerSlot`'s frame was RIGID, so the
    /// banner could not do what UIKit's does under pressure — yield — and every one of the five rows
    /// this shape draws diverged. The slot is now `Color.clear` under a `.frame(maxHeight:)`, which
    /// IS the yield (see `BannerSlot`'s doc), and the vertical half of the comparison closed
    /// completely: measured at 844x390, banner 102.0 against UIKit's 102.33, card 294.0 against
    /// 294.0, title/subtitle/button origins all inside 0.5pt.
    ///
    /// **Deliberately not `assertAgrees`, and the reason is a WIDTH that is still wrong.** UIKit's
    /// landscape column is 256 where `ModalTokens.bannerGeometry` computes 320, and that 64pt reaches
    /// the card and every row that matches the card. `assertAgrees` has no exclusion mechanism — spec
    /// §5 removed it on purpose — so gating this shape through it would fail, and the honest
    /// alternative is a test that states exactly which coordinates it does and does not cover. This
    /// one covers `minX`, `minY` and `height` on every comparable row, at the same 0.5pt tolerance,
    /// and covers `width` on none of them. That is ten pinned numbers where there were zero.
    ///
    /// The width exclusion is not left to this comment to enforce —
    /// `test_bannerWide_landscape_theWidthGapIsTheColumnRule` pins its MECHANISM, so that if UIKit
    /// ever stops shrinking the image's width demand the justification fails loudly instead of
    /// rotting here.
    func test_geometry_landscape_bannerWide_agreesOnEveryOriginAndHeight() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "banner-wide"))
        let rows = DifferentialGeometry.rows(for: shape, size: DifferentialGeometry.landscapeHost)
        let table = DifferentialGeometry.table(name: "banner-wide [landscape]", rows: rows)

        let comparable = rows.filter { $0.verdict != .absentOnBoth }
        XCTAssertFalse(
            comparable.isEmpty,
            "'banner-wide': NOTHING was comparable in landscape — a gate that compares nothing is "
                + "not a gate.\n" + table
        )

        for row in comparable {
            let uiKit = try XCTUnwrap(row.uiKit, "'\(row.element.rawValue)': UIKit drew nothing")
            let swiftUI = try XCTUnwrap(row.swiftUI, "'\(row.element.rawValue)': SwiftUI drew nothing")
            let name = row.element.rawValue
            XCTAssertEqual(
                swiftUI.minX, uiKit.minX, accuracy: DifferentialGeometry.tolerance,
                "'\(name)' minX diverges in landscape.\n" + table
            )
            XCTAssertEqual(
                swiftUI.minY, uiKit.minY, accuracy: DifferentialGeometry.tolerance,
                "'\(name)' minY diverges in landscape.\n" + table
            )
            XCTAssertEqual(
                swiftUI.height, uiKit.height, accuracy: DifferentialGeometry.tolerance,
                "'\(name)' HEIGHT diverges in landscape. This is the coordinate the banner's "
                    + "`.frame(maxHeight:)` yield semantics buys — if it is red, the slot has "
                    + "stopped yielding the residual.\n" + table
            )
        }
    }

    /// **Why the test above excludes `width`, asserted as a mechanism rather than trusted as prose.**
    ///
    /// UIKit's height-constrained arbitration shrinks the banner's HEIGHT, and the required
    /// `ivBanner.width == ivBanner.height * ratio` tie shrinks the image's WIDTH DEMAND with it.
    /// Measured in landscape: `ivBanner` is 172pt wide inside a 256pt `vwBanner`, i.e. the image asks
    /// for less than the content column, so nothing pushes the column past `contentMaxWidth` and
    /// UIKit's column simply stays there. `ModalTokens.bannerGeometry` cannot reach that number: the
    /// column depends on the resolved height, the height depends on the residual, the residual
    /// depends on the text, and the text's wrapping depends on the column. Closing it needs a
    /// measurement pass, not a formula.
    ///
    /// So this asserts the two facts the exclusion rests on: that UIKit's image really is narrower
    /// than its slot in landscape (the demand collapsed), and that it is NOT in portrait (where the
    /// same shape's column growth is real and `test_geometry_bannerWide` gates it). If UIKit ever
    /// stops doing this the exclusion above is unjustified, and this goes red to say so.
    func test_bannerWide_landscape_theWidthGapIsTheColumnRule() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "banner-wide"))

        func measure(_ size: CGSize) throws -> (slot: CGFloat, image: CGFloat) {
            let modal = DifferentialGeometry.makeUIKitModal(shape)
            let window = DifferentialGeometry.makeWindow(size: size)
            defer { DifferentialGeometry.teardown(window) }
            modal.show(parent: window, completion: {})
            window.setNeedsLayout()
            window.layoutIfNeeded()
            let slot = try XCTUnwrap(modal.vwBanner, "UIKit built no banner slot")
            let image = try XCTUnwrap(modal.ivBanner, "UIKit built no banner image")
            return (slot.bounds.width, image.bounds.width)
        }

        let landscape = try measure(DifferentialGeometry.landscapeHost)
        XCTAssertLessThan(
            landscape.image, landscape.slot - DifferentialGeometry.tolerance,
            "UIKit's landscape `ivBanner` (\(landscape.image)pt) is no longer NARROWER than its "
                + "`vwBanner` (\(landscape.slot)pt). The height-driven collapse of the image's width "
                + "demand is what makes UIKit's landscape column stay at `contentMaxWidth`, and it is "
                + "the whole justification for "
                + "`test_geometry_landscape_bannerWide_agreesOnEveryOriginAndHeight` not comparing "
                + "widths. If this is red, either compare widths there or find the new reason not to."
        )

        let portrait = try measure(DifferentialGeometry.host)
        XCTAssertEqual(
            portrait.image, portrait.slot, accuracy: DifferentialGeometry.tolerance,
            "UIKit's PORTRAIT `ivBanner` (\(portrait.image)pt) no longer fills its `vwBanner` "
                + "(\(portrait.slot)pt). Portrait is the regime where the artwork's width demand "
                + "survives and genuinely widens the column — if it has stopped, "
                + "`ModalTokens.bannerGeometry`'s column rule is wrong in the orientation it WAS "
                + "written for, not just in landscape."
        )
    }

    /// **`banner-comparable` in landscape — the shape D-7 used to block, now gated in full.**
    ///
    /// This is the shape whose widths agree (its artwork never widens the column), so it isolates the
    /// height story with nothing else in the way — which is why it was the last one left. After the
    /// banner's `maxHeight` yield its card and primary button were already exact and a single
    /// **19.33pt** displacement remained: SwiftUI's banner came out 115.0 against UIKit's 134.33,
    /// because UIKit had compressed its subtitle viewport to 19.0 over a 38.33pt label and SwiftUI,
    /// having no per-subtitle viewport, kept the whole 38.3 and made the banner pay for it.
    ///
    /// `SwiftUIAlertModal.SubtitleSlot` supplies that viewport, so there is nothing left to exclude:
    /// this is the ordinary `assertAgrees`, every row, every coordinate, at the usual 0.5pt. It
    /// replaces `test_bannerComparable_landscape_divergesOnlyByTheSubtitleViewport`, which pinned the
    /// 19.33 by mechanism precisely so that closing it would come here.
    ///
    /// Its non-vacuity — that UIKit really is clipping here, so this agreement is SwiftUI reproducing
    /// the clip rather than neither backend being under pressure — is asserted separately, below.
    func test_geometry_landscape_bannerComparable() {
        assertAgrees("banner-comparable", size: DifferentialGeometry.landscapeHost)
    }

    /// **The premise of the test above: this shape is genuinely in the CLIPPED regime.**
    ///
    /// `assertAgrees` at `landscapeHost` would also pass if neither backend were under any pressure —
    /// and that is the one way it could be green while saying nothing about D-7. So both halves of
    /// the mechanism are asserted here:
    ///
    /// * UIKit's `svSubtitleContainer` is strictly shorter than the `lbSubtitle` inside it (measured
    ///   19.0 against 38.33) — it is showing half of an ordinary one-line-per-38pt subtitle because
    ///   landscape puts the card on its ceiling. This is the D-7 regime, and note that it is NOT the
    ///   `long-subtitle-scrolling` regime: nothing about this subtitle is long.
    /// * SwiftUI's subtitle row is strictly shorter than the text inside IT, by the same amount —
    ///   i.e. `SubtitleSlot` is clipping too, rather than the two agreeing because SwiftUI happened
    ///   to find the same number some other way.
    ///
    /// If UIKit ever stops compressing here this goes red, and the gate above becomes a comparison of
    /// two unpressured cards that no longer proves anything about the slot.
    func test_bannerComparable_landscape_bothBackendsAreClippingTheSubtitle() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "banner-comparable"))
        let host = DifferentialGeometry.landscapeHost

        let modal = DifferentialGeometry.makeUIKitModal(shape)
        let window = DifferentialGeometry.makeWindow(size: host)
        defer { DifferentialGeometry.teardown(window) }
        modal.show(parent: window, completion: {})
        window.setNeedsLayout()
        window.layoutIfNeeded()
        let viewport = try XCTUnwrap(modal.svSubtitleContainer, "UIKit built no subtitle container")
        let label = try XCTUnwrap(modal.lbSubtitle, "UIKit built no subtitle label")
        XCTAssertLessThan(
            viewport.bounds.height, label.bounds.height - DifferentialGeometry.tolerance,
            "UIKit's landscape subtitle viewport (\(viewport.bounds.height)pt) is no longer smaller "
                + "than its label (\(label.bounds.height)pt), so this shape has left the clipped "
                + "regime and `test_geometry_landscape_bannerComparable` is now comparing two "
                + "unpressured cards. Find a shape that IS clipped, or D-7 has no gate."
        )

        // The SwiftUI half: the slot must be clipping too, not merely agreeing.
        let rows = DifferentialGeometry.rows(for: shape, size: host)
        let subtitle = try XCTUnwrap(rows.first { $0.element == .subtitle })
        let swiftUISlot = try XCTUnwrap(subtitle.swiftUI, "SwiftUI drew no subtitle")
        XCTAssertLessThan(
            swiftUISlot.height, label.bounds.height - DifferentialGeometry.tolerance,
            "SwiftUI's landscape subtitle slot (\(swiftUISlot.height)pt) is no longer smaller than "
                + "the text it holds (\(label.bounds.height)pt of content). `SubtitleSlot` has "
                + "stopped yielding, and the agreement next door is a coincidence."
        )
    }

    /// **The card must fit inside the SAFE AREA, minus whatever vertical margin the preset asks for.**
    ///
    /// `AlertModalScaffold.body` applies `.frame(maxHeight: proxy.size.height - cardMarginV * 2)` to
    /// the card, and that only PROPOSES a height: a rigid child can still report a larger ideal size,
    /// and SwiftUI centres the overflow rather than clamping it. That used to be exactly what the
    /// banner shapes did in landscape, because `BannerSlot`'s frame was rigid. The slot yields now
    /// (`.frame(maxHeight:)` over a greedy `Color.clear` — see `BannerSlot`'s doc), and measured at
    /// 844x390 `banner-wide` went 374.6 -> 294.0 and `banner-comparable` 312.6 -> 294.0.
    ///
    /// **This test's cap used to be `host.height − cardMarginV * 2`, and that was ~150pt of slack.**
    /// `GeniePresets.margin` deliberately zeroes the vertical margin (top/bottom 0, see its note —
    /// UIKit pins to the SAFE AREA, so the card still clears the notch without a margin of its own),
    /// so `cardMarginV` is **0** for every shape here and the cap was the **full 390pt host**. The
    /// pre-fix `banner-wide` card was 374.6pt, comfortably under 390 — verified by reverting
    /// `BannerSlot` to its rigid `.frame(width:height:)`, under which the old assertion stayed GREEN
    /// while the shipping card bled ~40pt past each margin. A test that passes through the defect it
    /// names is not a backstop; it is a claim.
    ///
    /// **The real ceiling is the safe area**, and it is where both backends independently get their
    /// height from: UIKit's `adjustVwContainerConstraint` pins `vwContainer` against
    /// `safeAreaLayoutGuide`, and the `UIHostingController` hands `AlertModalScaffold`'s
    /// `GeometryReader` the inset height. On this device in landscape that is 390 − 62 − 34 = **294**,
    /// and both cards land on it exactly.
    ///
    /// The 62/34 are NOT written down here. They are a property of the simulator, so hardcoding them
    /// would make this red on a different device for a reason that is not a defect —
    /// `DifferentialGeometry.safeAreaInsets` reads them back off the same window class the
    /// measurements run in, which keeps the cap true on any host and still leaves it TIGHT: under the
    /// rigid slot this now goes red on both banner shapes, which is the mutation that proves it.
    ///
    /// Still strictly weaker than the differential gate —
    /// `test_geometry_landscape_bannerWide_agreesOnEveryOriginAndHeight` compares SwiftUI's card
    /// height against UIKit's MEASURED one at 0.5pt. This is the cheap structural backstop that now
    /// actually backs something up.
    func test_landscape_cardFitsWithinItsSafeArea() throws {
        let names = [
            "standard-one-button",
            "standard-two-button",
            "permission-denied-settings",
            "oblique-red-leave-confirm",
            "onboarding-welcome-nobanner",
            // The banner shapes, added once the slot learned to yield — and the two the tightened
            // cap actually bites on.
            "banner-wide",
            "banner-comparable"
        ]
        let host = DifferentialGeometry.landscapeHost
        let insets = DifferentialGeometry.safeAreaInsets(size: host)

        // **The premise, because without it this test silently reverts to the loose one it replaced.**
        // A host that reported no insets would put the cap back at the full 390pt, where the pre-fix
        // 374.6pt card passed. If this fires the cap is not measuring the safe area any more and the
        // assertions below prove nothing — find out why rather than deleting this.
        XCTAssertGreaterThan(
            insets.top + insets.bottom, 0,
            "the landscape host reports NO vertical safe-area insets, so the cap below is the whole "
                + "\(host.height)pt host again — the same ~150pt of slack this test was tightened to "
                + "remove, and the pre-fix 374.6pt card passes under it"
        )

        for name in names {
            let shape = try XCTUnwrap(DifferentialGeometry.shape(named: name))
            let cardMarginV = ModalTokens(from: shape.properties).cardMarginV
            let cap = host.height - insets.top - insets.bottom - cardMarginV * 2

            let uiKit = DifferentialGeometry.uiKitFrames(shape, size: host)
            let swiftUI = DifferentialGeometry.swiftUIFrames(shape, size: host)
            let uiKitCard = try XCTUnwrap(uiKit[.card], "'\(name)': UIKit measured no card")
            let swiftUICard = try XCTUnwrap(swiftUI[.card], "'\(name)': SwiftUI measured no card")

            // `containmentSlack`, not the cross-backend `tolerance` — see its doc. Both sides of
            // each comparison come from ONE backend: a card height against a cap derived from the
            // same window's insets.
            XCTAssertLessThanOrEqual(
                uiKitCard.height, cap + Self.containmentSlack,
                "'\(name)' UIKit: card height \(uiKitCard.height)pt exceeds the safe-area cap "
                    + "\(cap)pt (host \(host.height)pt, insets \(insets.top)/\(insets.bottom), "
                    + "cardMarginV \(cardMarginV)pt). If this fires the SHIPPING dialog breaches the "
                    + "safe area in landscape — do not weaken this assertion, report it."
            )
            XCTAssertLessThanOrEqual(
                swiftUICard.height, cap + Self.containmentSlack,
                "'\(name)' SwiftUI: card height \(swiftUICard.height)pt exceeds the safe-area cap "
                    + "\(cap)pt (host \(host.height)pt, insets \(insets.top)/\(insets.bottom), "
                    + "cardMarginV \(cardMarginV)pt). `.frame(maxHeight:)` only proposes a height; "
                    + "something in this shape's content is refusing to yield to it."
            )
        }
    }

    /// **The landscape presence check — still NOT a gate, and no longer the only thing there is.**
    ///
    /// When this was written there was no landscape comparison for `banner-wide` at all: all five of
    /// the elements it draws diverged, and excluding everything comparable is not a narrower gate but
    /// an assertion-free test wearing a gate's clothes. That is still why `assertAgrees` has no
    /// exclusion mechanism, and still why this shape does not go through it.
    ///
    /// **What changed: four of those five coordinates now agree.** Once `BannerSlot` began yielding,
    /// every origin and every height on this shape landed inside 0.5pt of UIKit, and
    /// `test_geometry_landscape_bannerWide_agreesOnEveryOriginAndHeight` gates them. Only `width`
    /// still diverges, for the column reason pinned in
    /// `test_bannerWide_landscape_theWidthGapIsTheColumnRule`.
    ///
    /// So this test is now a PREMISE for that one rather than the only landscape claim about the
    /// shape: it asserts that both backends render something real, so a regression that made the
    /// shape vanish (a `nil` frame, a zero-size rect) cannot leave the gate above quietly comparing
    /// fewer rows than it thinks. Strictly weaker than agreement, and the name still says so.
    func test_bannerWide_landscape_stillDrawsABannerOnBothSides() throws {
        let shape = try XCTUnwrap(DifferentialGeometry.shape(named: "banner-wide"))
        let rows = DifferentialGeometry.rows(for: shape, size: DifferentialGeometry.landscapeHost)
        let drawn = rows.filter { $0.verdict != .absentOnBoth }
        XCTAssertFalse(drawn.isEmpty, "'banner-wide': nothing drew on either backend in landscape")
        for row in drawn {
            let uiKit = try XCTUnwrap(
                row.uiKit, "'\(row.element.rawValue)': UIKit drew nothing in landscape"
            )
            let swiftUI = try XCTUnwrap(
                row.swiftUI, "'\(row.element.rawValue)': SwiftUI drew nothing in landscape"
            )
            XCTAssertGreaterThan(uiKit.width, 0, "'\(row.element.rawValue)': UIKit width is zero")
            XCTAssertGreaterThan(uiKit.height, 0, "'\(row.element.rawValue)': UIKit height is zero")
            XCTAssertGreaterThan(swiftUI.width, 0, "'\(row.element.rawValue)': SwiftUI width is zero")
            XCTAssertGreaterThan(swiftUI.height, 0, "'\(row.element.rawValue)': SwiftUI height is zero")
        }
    }

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

    /// **This compares EVERY element, and there is deliberately no way to exclude one.**
    ///
    /// An `excluding:` / `because:` pair was added here in Task 5 and is now DELETED, unused. The
    /// same task's ruling is why it never gained a caller: for the one shape that motivated it
    /// (`banner-wide` in landscape) every element it draws diverges, so the only honest exclusion
    /// set was the whole set — and the conclusion was to delete the comparison rather than narrow
    /// it. A partial-gate mechanism with no honest use is a mechanism whose own guard rail
    /// (`because:` must be non-empty) is itself untested. Re-add it if, and only if, a shape ever
    /// diverges on a proper subset of what it draws; the `comparable.isEmpty` check below is what
    /// would keep it honest, and it stays here regardless — it independently catches an
    /// unexcluded shape that measures nothing comparable at all.
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
        let allRows = DifferentialGeometry.rows(for: shape, size: size)
        let orientation = size.width > size.height ? "landscape" : "portrait"
        let table = DifferentialGeometry.table(name: "\(name) [\(orientation)]", rows: allRows)

        // Honesty first: an empty measurement must never read as agreement.
        guard allRows.contains(where: { $0.uiKit != nil }), allRows.contains(where: { $0.swiftUI != nil }) else {
            XCTFail(
                "'\(name)': one side measured nothing, so there is no comparison to report.\n" + table,
                file: file, line: line
            )
            return
        }

        let disagreements = allRows.filter { $0.verdict.isDisagreement }
        let comparable = allRows.filter { $0.verdict != .absentOnBoth }

        // The complementary failure mode to the guard above: a shape where every row is
        // `absentOnBoth` leaves nothing for `disagreements.isEmpty` below to be true ABOUT, so it
        // passes vacuously — an assertion-free test wearing a gate's clothes. Currently
        // UNREACHABLE: `comparable.isEmpty` implies no row has `uiKit != nil`, which means the
        // guard immediately above (`allRows.contains(where: { $0.uiKit != nil })…`) already fired
        // and returned — guard 1 strictly subsumes guard 2. It was reachable only while
        // `excluding:` existed and could empty `comparable` while `allRows` still held
        // measurements. Kept anyway, deliberately: it costs nothing, and it is what would keep a
        // future exclusion mechanism honest if one is ever reintroduced. Do not delete it on the
        // grounds that it is unreachable today.
        XCTAssertFalse(
            comparable.isEmpty,
            "'\(name)': NOTHING was comparable — every element is absent on both backends. A gate "
                + "that compares nothing is not a gate.\n" + table,
            file: file, line: line
        )

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
