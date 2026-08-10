import XCTest
import UIKit
@testable import GBV3AlertModal

/// **Presentation state through the channel that already existed.**
///
/// The gallery's two button-state shapes (`variant-button-states`,
/// `variant-button-primary-disabled`) were `notRenderable` because the UIKit twins call
/// `changePrimaryActionEnableState` / `changeSecondaryActionEnableState` on the modal AFTER its view
/// graph is built, and a descriptor had no way to say it. `AlertDialog` carries the two flags now
/// (`ButtonEnablement`), and `ModalRenderer.update(_:to:)` — which both backends already
/// implemented as a full rebuild — is how a caller changes them mid-presentation. No new renderer
/// method was added.
///
/// These tests are here rather than in the differential harness on purpose: enablement is not
/// geometry. A disabled button occupies exactly the same frame as an enabled one, so `assertAgrees`
/// is green through the entire feature and can never be the gate for it.
@MainActor
final class ButtonEnablementTests: XCTestCase {

    private func makeUIKitStack() -> (DefaultModalExecutor, UIKitModalRenderer) {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        let renderer = UIKitModalRenderer(
            alertProperties: GeniePresets.standardProperties(), windowProvider: { window }
        )
        renderer.registerBuiltInDescriptors()
        return (DefaultModalExecutor(renderer: renderer), renderer)
    }

    private func alert(primaryEnabled: Bool = true, secondaryEnabled: Bool = true) -> AlertDialog {
        AlertDialog(
            title: "T", subtitle: "S", primary: "OK", secondary: "No",
            primaryEnabled: primaryEnabled, secondaryEnabled: secondaryEnabled
        )
    }

    // MARK: - Defaults

    /// The whole feature has to be inert unless asked for — every one of the ~114 existing call
    /// sites omits both flags.
    func test_bothFlags_defaultToEnabled() {
        let dialog = AlertDialog(primary: "OK")
        XCTAssertTrue(dialog.primaryEnabled)
        XCTAssertTrue(dialog.secondaryEnabled)
    }

    // MARK: - UIKit

    func test_uiKit_appliesEnablementAtPresent() throws {
        let (executor, renderer) = makeUIKitStack()

        let token = executor.present(alert(primaryEnabled: false, secondaryEnabled: false))

        let modal = try XCTUnwrap(renderer.live[token.id]?.modal)
        XCTAssertEqual(modal.btPrimaryAction?.isEnabled, false)
        XCTAssertEqual(modal.btSecondaryAction?.isEnabled, false)
    }

    /// **The `update` channel, and the ORDERING inside it.**
    ///
    /// `updateDialog` tears the view graph down and rebuilds it, so the buttons this touches do not
    /// exist until after it runs — enablement applied before the rebuild is discarded by it. This
    /// test fails if `applyButtonEnablement` is moved above `updateDialog` in the rebuild closure.
    func test_uiKit_updateChangesEnablement_onTheSameModalInstance() throws {
        let (executor, renderer) = makeUIKitStack()
        let token = executor.present(alert())
        let before = try XCTUnwrap(renderer.live[token.id]?.modal)
        XCTAssertEqual(before.btPrimaryAction?.isEnabled, true)

        executor.update(token, to: alert(primaryEnabled: false))

        let after = try XCTUnwrap(renderer.live[token.id]?.modal)
        XCTAssertTrue(before === after, "update must re-render in place, not swap the modal")
        XCTAssertEqual(after.btPrimaryAction?.isEnabled, false)
        XCTAssertEqual(after.btSecondaryAction?.isEnabled, true, "only the primary was disabled")
    }

    /// And back again — a one-way latch would pass every assertion above.
    func test_uiKit_updateCanReEnable() throws {
        let (executor, renderer) = makeUIKitStack()
        let token = executor.present(alert(primaryEnabled: false))

        executor.update(token, to: alert(primaryEnabled: true))

        let modal = try XCTUnwrap(renderer.live[token.id]?.modal)
        XCTAssertEqual(modal.btPrimaryAction?.isEnabled, true)
    }

    // MARK: - SwiftUI

    /// `registerStandard`'s `D -> AlertDialog` projection is what `ModalHost` draws from, and it is
    /// built field by field — so a flag it forgets to copy reaches the UIKit renderer and silently
    /// never reaches `SwiftUIAlertModal`. That is the failure this pins.
    func test_swiftUI_carriesEnablementIntoTheContentProjection() throws {
        let renderer = SwiftUIModalRenderer(alertProperties: GeniePresets.standardProperties())
        let id = ModalID()

        renderer.present(alert(primaryEnabled: false, secondaryEnabled: false), id: id, resolve: { _ in })

        let content = try XCTUnwrap(renderer.presentations.first?.content)
        XCTAssertFalse(content.primaryEnabled)
        XCTAssertFalse(content.secondaryEnabled)
    }

    func test_swiftUI_updateChangesEnablement() throws {
        let renderer = SwiftUIModalRenderer(alertProperties: GeniePresets.standardProperties())
        let id = ModalID()
        renderer.present(alert(), id: id, resolve: { _ in })

        renderer.update(id, to: alert(primaryEnabled: false))

        let content = try XCTUnwrap(renderer.presentations.first?.content)
        XCTAssertFalse(content.primaryEnabled)
        XCTAssertTrue(content.secondaryEnabled)
    }

    /// A descriptor that does NOT conform to `ButtonEnablement` must come through enabled rather
    /// than crash or default to disabled — both renderers ask with a cast.
    func test_aDescriptorWithoutEnablement_rendersEnabled() throws {
        // `PopupDialog` is registered by `init` only when popup styling is supplied — same rule as
        // UIKit — so the other tests' `alertProperties`-only renderer would silently drop it.
        let renderer = SwiftUIModalRenderer(
            alertProperties: GeniePresets.standardProperties(),
            popupProperties: GeniePresets.standardProperties()
        )
        let id = ModalID()

        renderer.present(
            PopupDialog(title: "T", subtitle: "S", primary: "OK"), id: id, resolve: { _ in }
        )

        let content = try XCTUnwrap(renderer.presentations.first?.content)
        XCTAssertTrue(content.primaryEnabled)
        XCTAssertTrue(content.secondaryEnabled)
    }
}
