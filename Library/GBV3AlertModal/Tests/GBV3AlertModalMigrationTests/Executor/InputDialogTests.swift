@testable import GBV3AlertModalCore
@testable import GBV3AlertModalSwiftUI
@testable import GBV3AlertModalUIKit
import XCTest
import UIKit

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

// MARK: - The selectable date range, on both renderers

/// **`datePickerRange` — closing a BEHAVIOURAL divergence, not a cosmetic one.**
///
/// The app's date-picker worksheet pins `minimumDate = tomorrow` / `maximumDate = +2 years` on the
/// `UIDatePicker` it builds at the call site. `DatePickerDialog` could not express that, so BOTH
/// renderers drew an unbounded wheel — and a SwiftUI adoption would have returned dates the UIKit
/// dialog forbids, surfacing as a backend rejection rather than as a wrong-looking card.
@MainActor
final class DatePickerRangeTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func dialog(minimum: Date?, maximum: Date?) -> DatePickerDialog {
        DatePickerDialog(
            title: "Select date",
            initialDate: start,
            minimumDate: minimum,
            maximumDate: maximum,
            primary: "Done",
            secondary: "Cancel"
        )
    }

    /// UIKit: the bounds reach the live `UIDatePicker` the holder puts in the custom-content slot.
    func test_uiKitPicker_carriesTheDescriptorsRange() throws {
        let minimum = start.addingTimeInterval(86_400)
        let maximum = start.addingTimeInterval(86_400 * 730)
        let holder = UIKitModalRenderer.DatePickerHolder.make(
            for: dialog(minimum: minimum, maximum: maximum), resolve: { _ in }
        )
        let picker = try XCTUnwrap(holder.subtitleCustomView as? UIDatePicker)

        XCTAssertEqual(picker.minimumDate, minimum)
        XCTAssertEqual(picker.maximumDate, maximum)
    }

    /// An unset range stays unbounded — `UIDatePicker`'s own default, so existing callers that pass
    /// neither bound are unaffected by the descriptor gaining the fields.
    func test_anUnsetRange_leavesThePickerUnbounded() throws {
        let holder = UIKitModalRenderer.DatePickerHolder.make(
            for: dialog(minimum: nil, maximum: nil), resolve: { _ in }
        )
        let picker = try XCTUnwrap(holder.subtitleCustomView as? UIDatePicker)

        XCTAssertNil(picker.minimumDate)
        XCTAssertNil(picker.maximumDate)
    }

    /// The descriptor is the SHARED source both renderers read, so parity is a statement about it
    /// reaching each side rather than about two independently-configured pickers agreeing.
    func test_theDescriptorCarriesTheRange_forBothRenderers() {
        let minimum = start.addingTimeInterval(86_400)
        let maximum = start.addingTimeInterval(86_400 * 730)
        let descriptor = dialog(minimum: minimum, maximum: maximum)

        XCTAssertEqual(descriptor.minimumDate, minimum)
        XCTAssertEqual(descriptor.maximumDate, maximum)
        // And the SwiftUI view builds from that same descriptor without discarding it.
        let view = DatePickerModalView(
            descriptor: descriptor, tokens: .standard, resolve: { _ in }
        )
        XCTAssertEqual(view.descriptor.minimumDate, minimum)
        XCTAssertEqual(view.descriptor.maximumDate, maximum)
    }
}

