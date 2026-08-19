import GBV3AlertModalCore
@testable import GBV3AlertModalUIKit
import Testing
import UIKit

@MainActor
struct ModalButtonConfigurationTests {
    @Test
    func descriptorOverridesButtonStyleAndOrientation() throws {
        let renderer = UIKitModalRenderer(
            alertProperties: GBAlertModal.Properties(
                buttonActionOrientation: .vertical,
                primaryActionStyle: .obliqueBottomLeft(.init())
            )
        )
        let capsule = GBAlertModal.ActionStyle.CapsuleTheme(backgroundColor: .orange)
        renderer.register(buttonStyle: .capsule, actionStyle: .capsule(capsule))

        let properties = try #require(
            renderer.resolvedProperties(
                for: AlertDialog(
                    primary: "Continue",
                    primaryButtonStyle: .capsule,
                    buttonOrientation: .horizontal
                )
            )
        )

        #expect(properties.buttonActionOrientation == .horizontal)
        guard case .capsule(let selected)? = properties.primaryActionStyle else {
            Issue.record("Expected the registered capsule style")
            return
        }
        #expect(selected.backgroundColor == capsule.backgroundColor)
    }
}
