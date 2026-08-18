@testable import GBV3AlertModalCore
@testable import GBV3AlertModalSwiftUI
@testable import GBV3AlertModalUIKit
import XCTest
import UIKit

/// The executor does not change rendering — it only builds a `DataHolder`. This asserts the
/// AlertDialog→DataHolder mapping produces the SAME render decisions the Layer-A resolver
/// already guards, using `GBAlertModal.resolve(...)` as the oracle. No new snapshots.
@MainActor final class AlertDialogMappingTests: XCTestCase {
    func test_plainDescriptor_mapsToPlainSubtitle() {
        let holder = UIKitModalRenderer.AlertHolder.make(
            for: AlertDialog(title: "Title", subtitle: "Body", primary: "OK", secondary: "Cancel")
        ) { _ in }
        let resolved = GBAlertModal.resolve(
            properties: GeniePresets.standardProperties(), holder: holder, isLandscape: false
        )
        XCTAssertTrue(resolved.showsTitle)
        XCTAssertEqual(resolved.subtitle, .plain("Body"))
        XCTAssertFalse(resolved.dismissOnAction)
    }

    /// PopupDialog is content-identical to AlertDialog; it routes through the SAME shared holder and
    /// resolves the SAME way under the popup properties — only the style (Properties) differs.
    func test_popupDialog_mapsThroughSharedHolder() {
        let holder = UIKitModalRenderer.AlertHolder.make(
            for: PopupDialog(title: "Popup", subtitle: "Body", primary: "OK", secondary: "Cancel")
        ) { _ in }
        let resolved = GBAlertModal.resolve(
            properties: GeniePresets.popupProperties(), holder: holder, isLandscape: false
        )
        XCTAssertTrue(resolved.showsTitle)
        XCTAssertEqual(resolved.subtitle, .plain("Body"))
        XCTAssertTrue(resolved.showsSecondary)
    }

    func test_popupDialog_dismissedResult() {
        XCTAssertEqual(PopupDialog.dismissedResult, .dismissed)
    }

    /// End-to-end: a renderer given popupProperties registers PopupDialog, so presenting one installs
    /// a UIKit modal and resolving it (primary tap) flows the result back.
    func test_popupDialog_presents_and_resolves_through_renderer() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let renderer = UIKitModalRenderer(
            alertProperties: GeniePresets.standardProperties(),
            popupProperties: GeniePresets.popupProperties(),
            windowProvider: { window }
        )
        var result: AlertDialog.Result?
        renderer.present(PopupDialog(title: "P", primary: "OK"), id: ModalID()) { result = $0 }

        let modal = firstDescendant(GBAlertModal.self, in: window)
        XCTAssertNotNil(modal, "PopupDialog should present once popupProperties registered it")
        modal?.dismissAndEmit(event: .primary)
        XCTAssertEqual(result, .primary)
    }

    private func firstDescendant<T: UIView>(_ type: T.Type, in view: UIView) -> T? {
        for sub in view.subviews {
            if let hit = sub as? T { return hit }
            if let deep = firstDescendant(type, in: sub) { return deep }
        }
        return nil
    }

    /// Ambient `foregroundColor =` binds to SwiftUI's attribute scope even in this file, which has
    /// no `import SwiftUI` — that ambient setter is scope-ambiguous and resolves to
    /// `SwiftUI.ForegroundColor`. That key DOES bridge onto the resulting `NSAttributedString`,
    /// but under a key `UILabel` does not render, so it would not exercise a real attributed
    /// subtitle. The explicit `.uiKit.` scope is required to produce a run UIKit actually renders.
    /// (An earlier version of this test asserted the ambient behaviour directly, using dynamic
    /// cross-scope member lookup at runtime; that was measured at 184s for one test versus 0.001s
    /// for the explicit-scope form, and was removed — see `ModalTextTests.testSwiftUIScopedColorStaysPlain`
    /// for the fast, equivalent behavioural pin of the "SwiftUI-scoped stays plain" contract.)
    func test_styledDescriptor_mapsToAttributedSubtitle() {
        var body = AttributedString("Body")
        body.uiKit.foregroundColor = .red
        let holder = UIKitModalRenderer.AlertHolder.make(
            for: AlertDialog(title: nil, subtitle: body, primary: "OK")
        ) { _ in }
        let resolved = GBAlertModal.resolve(
            properties: GeniePresets.standardProperties(), holder: holder, isLandscape: false
        )
        XCTAssertEqual(resolved.subtitle, .attributed)
    }

    func test_alertDialogResult_dismissedResultIsDismissed() {
        XCTAssertEqual(AlertDialog.dismissedResult, .dismissed)
    }

    func test_stringInit_liftsToAttributedString() {
        let d = AlertDialog(title: "Hi", subtitle: "There", primary: "OK")
        XCTAssertEqual(d.title.map { String($0.characters) }, "Hi")
        XCTAssertEqual(d.subtitle.map { String($0.characters) }, "There")
    }

    func test_bothInits_equivalentForPlainText() {
        let s = AlertDialog(title: "Hi", subtitle: "There", primary: "OK")
        let a = AlertDialog(title: AttributedString("Hi"), subtitle: AttributedString("There"), primary: "OK")
        XCTAssertEqual(s.title, a.title)
        XCTAssertEqual(s.subtitle, a.subtitle)
    }

    func test_bareInit_isUnambiguous_resolvesToStringPath() {
        // Compiles only because the AttributedString init does not default title/subtitle.
        let d = AlertDialog(primary: "OK")
        XCTAssertNil(d.title)
        XCTAssertNil(d.subtitle)
    }
}
