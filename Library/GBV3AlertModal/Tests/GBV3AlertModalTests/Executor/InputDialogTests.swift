import XCTest
import UIKit
@testable import GBV3AlertModal

/// The custom-content mechanism: input descriptors carry `Sendable` config, the renderer materializes
/// the input view in the modal's `subtitleCustomView`, and the result carries the entered value.
@MainActor final class InputDialogTests: XCTestCase {

    private func makeRenderer(in window: UIWindow) -> UIKitModalRenderer {
        let renderer = UIKitModalRenderer(alertProperties: GeniePresets.standardProperties(),
                                          windowProvider: { window })
        renderer.register(TextInputDialog.self) { descriptor, resolve in
            (GeniePresets.standardProperties(),
             UIKitModalRenderer.TextInputHolder.make(for: descriptor, resolve: resolve))
        }
        renderer.register(DatePickerDialog.self) { descriptor, resolve in
            (GeniePresets.standardProperties(),
             UIKitModalRenderer.DatePickerHolder.make(for: descriptor, resolve: resolve))
        }
        return renderer
    }

    func test_textInputDialog_returns_entered_text() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.makeKeyAndVisible(); defer { window.isHidden = true }
        let renderer = makeRenderer(in: window)

        var result: TextInputDialog.Result?
        renderer.present(TextInputDialog(title: "Rename", placeholder: "Name",
                                         initialText: "Old", primary: "Save", secondary: "Cancel"),
                         id: ModalID()) { result = $0 }

        XCTAssertNotNil(firstDescendant(GBAlertModal.self, in: window), "should present")
        let field = firstDescendant(UITextField.self, in: window)
        XCTAssertEqual(field?.text, "Old", "field seeded with initialText")
        field?.text = "New name"
        firstDescendant(GBAlertModal.self, in: window)?.dismissAndEmit(event: .primary)
        XCTAssertEqual(result, .submitted("New name"))
    }

    func test_textInputDialog_secondary_returns_dismissed() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.makeKeyAndVisible(); defer { window.isHidden = true }
        let renderer = makeRenderer(in: window)

        var result: TextInputDialog.Result?
        renderer.present(TextInputDialog(placeholder: "Name", primary: "Save", secondary: "Cancel"),
                         id: ModalID()) { result = $0 }
        firstDescendant(GBAlertModal.self, in: window)?.dismissAndEmit(event: .secondary)
        XCTAssertEqual(result, .dismissed)
    }

    func test_datePickerDialog_returns_picked_date() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.makeKeyAndVisible(); defer { window.isHidden = true }
        let renderer = makeRenderer(in: window)

        var result: DatePickerDialog.Result?
        renderer.present(DatePickerDialog(title: "Pick a date",
                                          initialDate: Date(timeIntervalSince1970: 1_000_000),
                                          primary: "OK"),
                         id: ModalID()) { result = $0 }

        let picker = firstDescendant(UIDatePicker.self, in: window)
        XCTAssertNotNil(picker, "should present a date picker")
        picker?.date = Date(timeIntervalSince1970: 2_000_000)
        let expected = picker!.date // whatever the .date-mode picker normalized to
        firstDescendant(GBAlertModal.self, in: window)?.dismissAndEmit(event: .primary)
        XCTAssertEqual(result, .submitted(expected))
    }

    private func firstDescendant<T: UIView>(_ type: T.Type, in view: UIView) -> T? {
        for sub in view.subviews {
            if let hit = sub as? T { return hit }
            if let deep = firstDescendant(type, in: sub) { return deep }
        }
        return nil
    }
}
