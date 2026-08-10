import XCTest
@testable import GBV3AlertModal

/// **The Swift 6 acceptance test for Pass 5 (§2, `2026-08-07-uikit-retirement.md`).**
///
/// `GBAlertModal.resolve` has always been `nonisolated` — its own doc says why: "genuinely pure
/// (value inputs only, no main-actor state), so it is callable off the main actor." Before Pass 5
/// step 6 that promise was unreachable from the SwiftUI half in practice: the only way to GET a
/// holder to hand it was `UIKitModalRenderer.AlertHolder.make` (`@MainActor`), so resolving a
/// SwiftUI presentation always meant a main-actor hop first, promise or not.
///
/// `ModalContent.make` carries no such annotation, and `resolve(inputs:content:isLandscape:)` takes
/// `any ModalContentInputs` rather than the concrete, UIKit-backed `DataHolder` — so the full chain,
/// descriptor through `ResolvedModal` and `ModalTokens`, should now be reachable without one.
///
/// This is a COMPILE-TIME claim as much as a runtime one. `resolveOffMainActor` below is
/// `nonisolated` with no `await` in its body — if a future change reintroduced a main-actor
/// requirement anywhere in the chain, this file would fail to BUILD, and the compiler would name
/// the exact call that broke the promise, rather than this test merely failing at runtime.
/// Plain `Bool`/`CGFloat`, not `ResolvedModal`/`ModalTokens` themselves — neither conforms to
/// `Sendable` (both are value types nobody has needed to cross a task boundary before), and this
/// test's whole point is the CALL CHAIN's isolation, not those types' concurrency safety.
struct OffMainActorResult: Sendable {
    let showsTitle: Bool
    let subtitleIsExpectedPlainText: Bool
    let showsPrimary: Bool
    let showsSecondary: Bool
    let buttonsMatchParent: Bool
    let contentMaxWidth: CGFloat
}

final class OffMainActorResolutionTests: XCTestCase {

    /// Descriptor + `ModalProperties` in, no `@MainActor`, no `await` — exactly what
    /// `2026-08-07-uikit-retirement.md` §2 asks for: "a descriptor and `ModalProperties`, resolves,
    /// and derives `ModalTokens`."
    nonisolated static func resolveOffMainActor(
        _ descriptor: AlertDialog, properties: ModalProperties
    ) -> OffMainActorResult {
        let content = ModalContent.make(for: descriptor)
        let resolved = GBAlertModal.resolve(inputs: properties, content: content, isLandscape: false)
        let tokens = ModalTokens(from: properties)

        let subtitleIsExpectedPlainText: Bool
        if case .plain(let text) = resolved.subtitle {
            subtitleIsExpectedPlainText = (text == "Resolved without a hop")
        } else {
            subtitleIsExpectedPlainText = false
        }

        return OffMainActorResult(
            showsTitle: resolved.showsTitle,
            subtitleIsExpectedPlainText: subtitleIsExpectedPlainText,
            showsPrimary: resolved.showsPrimary,
            showsSecondary: resolved.showsSecondary,
            buttonsMatchParent: resolved.buttonsMatchParent,
            contentMaxWidth: tokens.contentMaxWidth
        )
    }

    /// Runs the chain on a DETACHED task — genuinely off the main actor, not merely "on a background
    /// queue while still able to hop". `Task.detached` has no actor context of its own, so if
    /// `resolveOffMainActor`'s signature had to be `async` to satisfy a hidden main-actor
    /// requirement, this closure would fail to COMPILE (a synchronous call inside a non-`async`
    /// closure cannot `await`), not merely fail at runtime.
    ///
    /// Calls `OffMainActorResolutionTests.resolveOffMainActor`, not `Self.resolveOffMainActor` —
    /// `Self` inside this `Task.detached` closure tripped a Swift 6 region-isolation-checker
    /// limitation ("pattern that the region-based isolation checker does not understand how to
    /// check — please file a bug"); the fully-qualified name sidesteps it and means the same thing.
    func test_resolve_isReachableOffTheMainActor() async {
        let dialog = AlertDialog(title: "Off-actor", subtitle: "Resolved without a hop", primary: "OK", secondary: "No")
        var properties = ModalProperties()
        properties.buttonActionShouldMatchParent = true
        properties.primaryActionStyle = .plain(.init())
        properties.secondaryActionStyle = .plain(.init())

        let result = await Task.detached {
            OffMainActorResolutionTests.resolveOffMainActor(dialog, properties: properties)
        }.value

        // Non-vacuity: every field asserted here is a distinct decision `resolve`/`ModalTokens`
        // made, not just the ones that would pass on an all-nil/default holder.
        XCTAssertTrue(result.showsTitle)
        XCTAssertTrue(result.subtitleIsExpectedPlainText)
        XCTAssertTrue(result.showsPrimary)
        XCTAssertTrue(result.showsSecondary)
        XCTAssertTrue(result.buttonsMatchParent)
        XCTAssertGreaterThan(result.contentMaxWidth, 0)
    }
}
