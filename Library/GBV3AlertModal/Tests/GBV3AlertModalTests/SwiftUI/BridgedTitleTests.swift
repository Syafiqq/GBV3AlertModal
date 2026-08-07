import SwiftUI
import UIKit
import XCTest
@testable import GBV3AlertModal

/// **Closes the title's version of the bug `AttributedTextBridge` exists to fix for the subtitle.**
///
/// `SwiftUIAlertModal`'s title rendered `Text(config.title)` directly — the raw descriptor value,
/// never routed through `AttributedTextBridge.swiftUIRenderable`. A caller's UIKit-scoped styling
/// (`GenieShapeCatalog.styled(_:color:)`'s exact shape, and the real `switch-device-recommendation`
/// catalog entry: `title: GenieShapeCatalog.styled("Device Switch Recommended", color: .systemBlue)`)
/// reached `Text`'s draw call on the wrong scope and was silently dropped — not degraded to a
/// default, DROPPED, same mechanism `AttributedTextBridgeTests` already proves for the subtitle, just
/// never applied to the title's call site.
///
/// `AttributedTextBridge.swiftUIRenderable` itself is already proven correct at the value level
/// (`AttributedTextBridgeTests`); what was never true is that the title path CALLED it. This tests
/// `SwiftUIAlertModal.bridgedTitle(_:)` — the exact value `Text` now draws — directly, the same way
/// `subtitlePayload` is tested without hosting a view.
// @MainActor: `bridgedTitle` is a static member of `SwiftUIAlertModal`, a @MainActor type, same as
// `SubtitlePayloadTests` for its sibling `subtitlePayload`.
@MainActor
final class BridgedTitleTests: XCTestCase {

    /// The real catalog shape's exact construction, not a synthetic stand-in.
    private var realCatalogTitle: AttributedString {
        var title = AttributedString("Device Switch Recommended")
        title.uiKit.foregroundColor = .systemBlue
        return title
    }

    func test_uiKitScopedTitleColour_reachesSwiftUIsScope() throws {
        let bridged = SwiftUIAlertModal.bridgedTitle(realCatalogTitle)
        let run = try XCTUnwrap(bridged.runs.first)

        XCTAssertEqual(
            run.swiftUI.foregroundColor, Color(uiColor: .systemBlue),
            "the real switch-device-recommendation title's blue never reached SwiftUI's scope — "
                + "Text would draw it in the default title colour, exactly the bug this closes"
        )
    }

    /// The UIKit scope survives the round trip (additive re-scoping, not a move) — a UIKit consumer
    /// of the same descriptor is unaffected.
    func test_theUIKitScopeSurvives() throws {
        let bridged = SwiftUIAlertModal.bridgedTitle(realCatalogTitle)
        let run = try XCTUnwrap(bridged.runs.first)
        XCTAssertEqual(run.uiKit.foregroundColor, .systemBlue)
    }

    /// A caller who already wrote SwiftUI-scoped styling directly is not second-guessed — same rule
    /// `AttributedTextBridgeTests.test_anExplicitSwiftUIScope_isNotOverwritten` pins for the subtitle.
    func test_anExplicitSwiftUIScopedTitle_isNotOverwritten() throws {
        var title = AttributedString("Mixed")
        title.uiKit.foregroundColor = .red
        title.swiftUI.foregroundColor = .green

        let bridged = SwiftUIAlertModal.bridgedTitle(title)
        let run = try XCTUnwrap(bridged.runs.first)
        XCTAssertEqual(run.swiftUI.foregroundColor, .green)
    }

    /// A plain title gains nothing — the bridge must not invent styling nothing asked for.
    func test_plainTitle_gainsNothing() throws {
        let bridged = SwiftUIAlertModal.bridgedTitle(AttributedString("Plain title"))
        let run = try XCTUnwrap(bridged.runs.first)
        XCTAssertNil(run.swiftUI.foregroundColor)
        XCTAssertNil(run.swiftUI.font)
    }
}
