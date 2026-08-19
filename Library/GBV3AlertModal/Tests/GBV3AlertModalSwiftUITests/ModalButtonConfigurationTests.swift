import GBV3AlertModalCore
@testable import GBV3AlertModalSwiftUI
import SwiftUI
import Testing

@MainActor
struct ModalButtonConfigurationTests {
    @Test
    func descriptorOverridesButtonStyleAndOrientation() throws {
        let renderer = SwiftUIModalRenderer(
            alertProperties: ModalProperties(
                buttonActionOrientation: .vertical,
                primaryActionStyle: .obliqueBottomLeft(.init())
            )
        )
        let capsule = ModalProperties.ActionStyle.CapsuleTheme(backgroundColor: .orange)
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
        #expect(properties.primaryActionStyle == .capsule(capsule))
    }
}
