@testable import GBV3AlertModalCore
@testable import GBV3AlertModalSwiftUI
@testable import GBV3AlertModalUIKit
import XCTest
import UIKit

/// A consumer-defined STATEFUL descriptor, registered from outside the library — proves the
/// extension mechanism and the `update(token,to:)` re-render path (the Gc2Gs shape, minus app UI).
private struct StepDialog: ModalDescriptor {
    enum Result: Sendable, Equatable { case done, dismissed }
    static var dismissedResult: Result { .dismissed }
    var title: String
}

@MainActor
final class ExecutorStatefulTests: XCTestCase {
    private func makeStack() -> (DefaultModalExecutor, UIKitModalRenderer) {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        let renderer = UIKitModalRenderer(alertProperties: GeniePresets.standardProperties(),
                                          windowProvider: { window })
        renderer.register(StepDialog.self) { descriptor, resolve in
            let holder = GBAlertModal.DataHolder(
                title: descriptor.title,
                primaryAction: "Next",
                dismissOnAction: false,
                completion: { _, action in
                    resolve(action == .primary ? .done : .dismissed)
                }
            )
            return (GeniePresets.standardProperties(), holder)
        }
        return (DefaultModalExecutor(renderer: renderer), renderer)
    }

    func test_update_reRendersSameInstance_withNewContent() {
        let (executor, renderer) = makeStack()
        let token = executor.present(StepDialog(title: "Step 1"))
        let modalBefore = renderer.live[token.id]?.modal
        XCTAssertEqual(modalBefore?.lbTitle?.text, "Step 1")

        executor.update(token, to: StepDialog(title: "Step 2"))

        let modalAfter = renderer.live[token.id]?.modal
        XCTAssertTrue(modalBefore === modalAfter)          // same instance, not swapped
        XCTAssertEqual(modalAfter?.lbTitle?.text, "Step 2") // re-rendered
    }

    func test_statefulDialog_resolvesOnce_afterUpdates() async {
        let (executor, renderer) = makeStack()
        let token = executor.present(StepDialog(title: "Step 1"))
        executor.update(token, to: StepDialog(title: "Step 2"))
        renderer.live[token.id]?.modal.dismissAndEmit(event: .primary)
        let result = await token.result
        XCTAssertEqual(result, .done)
        XCTAssertNil(renderer.live[token.id]) // torn down + registry cleared
    }
}
