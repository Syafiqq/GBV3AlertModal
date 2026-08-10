import SwiftUI
import XCTest
@testable import GBV3AlertModal

/// **The one crossing point between UIKit's axis vocabulary and SwiftUI's.**
///
/// `GBAlertModal.ResolvedModal.buttonAxis` speaks `NSLayoutConstraint.Axis` — it must, because
/// `UIStackView.axis` takes exactly that type and the UIKit renderer is frozen. `AlertModalScaffold`
/// speaks `SwiftUI.Axis`, because it is a public SwiftUI view and its callers should not have to
/// import UIKit for a two-case enum. `swiftUIAxis` is the single translation, applied once in
/// `SwiftUIAlertModal`.
///
/// Pinned rather than assumed: the mapping is trivial, which is exactly why nobody would notice it
/// being wrong. A swapped pair would render every two-button dialog on the wrong axis while every
/// geometry test still passed, because the differential gate compares a SwiftUI render against a
/// UIKit render of the SAME resolved value — both would move together.
final class ModalAxisBridgeTests: XCTestCase {
    func test_horizontal_mapsToHorizontal() {
        XCTAssertEqual(NSLayoutConstraint.Axis.horizontal.swiftUIAxis, Axis.horizontal)
    }

    func test_vertical_mapsToVertical() {
        XCTAssertEqual(NSLayoutConstraint.Axis.vertical.swiftUIAxis, Axis.vertical)
    }

    /// The mapping must be injective — a bridge that collapsed both cases onto one value would pass
    /// a naive "does it return something" check while silently pinning every dialog to one axis.
    func test_theTwoCases_doNotCollapseOntoOneValue() {
        XCTAssertNotEqual(
            NSLayoutConstraint.Axis.horizontal.swiftUIAxis,
            NSLayoutConstraint.Axis.vertical.swiftUIAxis,
            "the axis bridge collapsed both UIKit cases onto a single SwiftUI case"
        )
    }

    /// `ResolvedModal.buttonAxis` defaults to `.vertical` when `Properties` states no orientation
    /// (`GBAlertModal.resolve`), and `@unknown default` in the bridge maps to `.vertical` for the
    /// same reason. This pins that the default a caller sees THROUGH the bridge is the same one the
    /// resolver documents, so the two cannot drift apart.
    func test_theResolverDefault_survivesTheBridge() {
        let resolved = GBAlertModal.resolve(properties: nil, holder: .default, isLandscape: false)
        XCTAssertEqual(resolved.buttonAxis, .vertical, "the resolver's documented default moved")
        XCTAssertEqual(
            resolved.buttonAxis.swiftUIAxis, Axis.vertical,
            "the resolver default and the bridge's default no longer agree"
        )
    }
}
