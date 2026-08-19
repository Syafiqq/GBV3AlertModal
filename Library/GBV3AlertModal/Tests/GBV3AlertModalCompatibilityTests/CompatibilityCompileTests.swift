import SwiftUI
import UIKit
import XCTest
import GBV3AlertModal

final class CompatibilityCompileTests: XCTestCase {
    @MainActor
    func testSingleImportExposesEveryBackend() {
        let descriptor = AlertDialog(title: "Title", primary: "OK")
        let native = ModalProperties(padding: MinMaxEdgeInsets(top: (8, 16)))
        let legacy = GBAlertModal.Properties()
        let migrated = ModalProperties(adapting: legacy)
        let swiftUIRenderer: any ModalRenderer = SwiftUIModalRenderer(alertProperties: native)
        let uiKitRenderer: any ModalRenderer = UIKitModalRenderer(alertProperties: legacy)

        XCTAssertEqual(descriptor.primary, "OK")
        XCTAssertEqual(native.padding?.topMax, 16)
        XCTAssertNil(migrated.padding)
        _ = swiftUIRenderer
        _ = uiKitRenderer
    }
}
