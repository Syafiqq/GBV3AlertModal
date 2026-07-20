import XCTest
import UIKit
@testable import GBV3AlertModal

/// Regression tests for Task 5's two known bugs.
///
/// ## Bug 1 — `Properties.copy()` / `init` default asymmetry on `buttonActionShouldMatchParent`
///
/// `init`'s default is `Bool? = false`; `copy`'s default is `Bool? = nil`. These are NOT
/// interchangeable, because `GBAlertModal.updateProperties` merges with
/// `properties.buttonActionShouldMatchParent ?? globalProperties.buttonActionShouldMatchParent`
/// (`GBAlertModal.swift:864-865`) and the resolver treats the merged value as
/// `properties?.buttonActionShouldMatchParent == true` (`GBAlertModal+ResolvedModal.swift:88`):
///   - `false` is an explicit "no" that **short-circuits** the `?? globalProperties` fallback.
///   - `nil` means "defer to `globalProperties`".
///
/// `globalProperties` itself is `public var globalProperties = GBAlertModal.Properties()`
/// (`GBV3AlertModal.swift:1`) — i.e. it is built with `Properties.init`'s defaults, so today
/// `globalProperties.buttonActionShouldMatchParent == false` unless a consumer app reassigns it.
///
/// Analysis of flipping `init`'s default `false -> false` (kept) vs `nil` (proposed by the task
/// brief):
///   - If `globalProperties` is left untouched (the common/tested case), flipping is a no-op:
///     `globalProperties.buttonActionShouldMatchParent` would also become `nil` under the new
///     default, so the merge `nil ?? nil == nil`, and the resolver's `== true` check still
///     resolves to `false` — same observable result as today's `false ?? false == false`.
///   - BUT if a consumer app customizes `globalProperties` (e.g. sets
///     `buttonActionShouldMatchParent: true` globally so most alerts fill-align their buttons),
///     today's `false` default means every per-instance `Properties` that doesn't explicitly set
///     this field **silently ignores** that global setting (`false ?? true == false`, short-
///     circuited). Flipping the default to `nil` would make it correctly defer
///     (`nil ?? true == true`) — a genuine *behavior change* for that (unverifiable from this
///     repo) scenario.
///   - `LayerB_WiringTests.test_propertiesDefault_matchesDocumentedDefaults` already pins
///     `GBAlertModal.Properties.default.buttonActionShouldMatchParent == false` as an
///     intentional, documented default. Flipping `init`'s default would silently redefine that
///     contract without evidence that no consumer relies on `Properties.default` (or any
///     no-arg-for-this-field `Properties`) meaning "explicit false" today.
///
/// Conclusion: `init`'s default is **not** flipped here. The `copy()` side (Step 1 below) is
/// already correct and needs no change. See `task-5-report.md` for the full writeup and
/// recommendation to the maintainers.
///
/// ## Bug 2 — memoization/localization staleness
///
/// Lives in the consumer app's `V3AlertModal+GBV3AlertModal.swift` (`_holder`/`_properties`
/// static caches that memoize localized strings at first access). Not present in this library
/// (no static/memoized holder or properties exist here), so there is nothing to regression-test
/// in this repo. Documented as an app-side follow-up in `task-5-report.md`.
final class BugRegressionTests: XCTestCase {
    // MARK: - Bug 1, Step 1: copy() must not drop an explicitly-set true

    /// The unambiguous, plan-specified regression test: `copy()`'s own default (`nil`) must not
    /// stomp an explicitly-set `true` when copying an unrelated field.
    func test_copy_preservesMatchParentTrue() {
        let base = GBAlertModal.Properties(buttonActionShouldMatchParent: true)
        let copied = base.copy(titleColor: .red) // unrelated field
        XCTAssertEqual(
            copied.buttonActionShouldMatchParent, true,
            "copy() must not drop an explicitly-set true"
        )
    }

    /// Symmetric case: an explicitly-set `false` must also survive an unrelated `copy()`.
    func test_copy_preservesMatchParentFalse() {
        let base = GBAlertModal.Properties(buttonActionShouldMatchParent: false)
        let copied = base.copy(titleColor: .blue)
        XCTAssertEqual(
            copied.buttonActionShouldMatchParent, false,
            "copy() must not drop an explicitly-set false"
        )
    }

    // MARK: - Bug 1: pin the documented `init` default (intentionally NOT changed)

    /// Pins the current, tested, documented default so any future change to `init`'s default is
    /// a deliberate, visible diff here (mirrors `LayerB_WiringTests
    /// .test_propertiesDefault_matchesDocumentedDefaults`, kept in sync intentionally).
    func test_init_defaultButtonActionShouldMatchParentIsFalse() {
        let props = GBAlertModal.Properties()
        XCTAssertEqual(
            props.buttonActionShouldMatchParent, false,
            "init's default for buttonActionShouldMatchParent is intentionally false, not nil " +
            "(see the file-level doc comment for why flipping it is unsafe)"
        )
    }

    // MARK: - Bug 1: characterize the globalProperties short-circuit (documents the finding)

    private var savedGlobalProperties: GBAlertModal.Properties!

    override func setUpWithError() throws {
        // `globalProperties` is a mutable, package-wide global — save/restore around any test
        // that touches it so this suite stays order-independent and doesn't leak state into
        // LayerA/LayerB/LayerC.
        savedGlobalProperties = globalProperties
    }

    override func tearDownWithError() throws {
        globalProperties = savedGlobalProperties
    }

    /// Characterizes today's actual (documented-as-a-bug) behavior end-to-end: even when
    /// `globalProperties.buttonActionShouldMatchParent` is set to `true`, a per-instance
    /// `Properties` that doesn't touch the field still resolves to "does not match parent",
    /// because `init`'s `false` default short-circuits the `?? globalProperties` merge in
    /// `updateProperties`. This is a characterization test (pins current behavior, not a
    /// "should be fixed" assertion) — see the class-level doc comment for why this repo does not
    /// change `init`'s default to fix it.
    func test_globalPropertiesOverride_isSilentlyIgnored_whenInstanceOmitsField() {
        globalProperties = GBAlertModal.Properties(buttonActionShouldMatchParent: true)

        // `GeniePresets.standardProperties()` sets buttonActionShouldMatchParent explicitly
        // (to `true`), and `.copy(buttonActionShouldMatchParent: nil)` would fall back to that
        // `self` value rather than genuinely omitting the field (copy()'s own `?? self...`
        // behavior, proven correct by test_copy_preservesMatchParentTrue above). So build a
        // fresh `Properties` here that truly never touches the field, to isolate init's default.
        let freshProps = GeniePresets.standardProperties()
        let untouched = GBAlertModal.Properties(
            baseTint: freshProps.baseTint,
            overlayColor: freshProps.overlayColor,
            contentProperty: freshProps.contentProperty,
            margin: freshProps.margin,
            padding: freshProps.padding,
            bannerRatio: freshProps.bannerRatio,
            titleFont: freshProps.titleFont,
            titleColor: freshProps.titleColor,
            subtitleFont: freshProps.subtitleFont,
            subtitleColor: freshProps.subtitleColor,
            // buttonActionShouldMatchParent intentionally omitted -> init default `false`.
            buttonActionOrientation: freshProps.buttonActionOrientation,
            primaryActionStyle: freshProps.primaryActionStyle,
            secondaryActionStyle: freshProps.secondaryActionStyle,
            closeButtonTint: freshProps.closeButtonTint,
            space: freshProps.space
        )

        let modal = GBAlertModal(properties: untouched, holder: GeniePresets.twoButton())
        _ = renderForSnapshot(modal, size: CGSize(width: 390, height: 844))

        // Documents today's behavior: `.center`, NOT `.fill`, even though globalProperties says
        // `true`. If this ever flips to `.fill` on its own, the merge bug was fixed elsewhere and
        // this test (and its doc comment) should be revisited.
        XCTAssertEqual(
            modal.svMainActionContainer?.alignment, .center,
            "documents the known bug: init's false default short-circuits the globalProperties " +
            "fallback for buttonActionShouldMatchParent"
        )
    }
}
