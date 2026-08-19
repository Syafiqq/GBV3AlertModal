import CoreGraphics
import Foundation
import GBV3AlertModalCore
@testable import GBV3AlertModalSwiftUI
import SwiftUI
import Testing

@MainActor
struct BannerVisibilityTests {
    @Test
    @available(iOS 16.0, *)
    func bannerWithoutTextRendersWithNonzeroArea() throws {
        let image = ModalImage(
            "banner_regression",
            bundleIdentifier: Bundle.module.bundleIdentifier
        )
        let modal = SwiftUIAlertModal(
            config: AlertDialog(
                image: image,
                title: String?.none,
                subtitle: String?.none,
                primary: nil
            ),
            onAction: { _ in }
        )
        let renderer = ImageRenderer(
            content: modal.frame(width: 390, height: 844)
        )
        renderer.scale = 1

        let rendered = try #require(renderer.cgImage)
        try #require(rendered.bitsPerPixel == 32)
        let pixels = try #require(rendered.dataProvider?.data)
        let bytes = try #require(CFDataGetBytePtr(pixels))
        let redPixelCount = stride(from: 0, to: CFDataGetLength(pixels), by: 4).reduce(into: 0) {
            count, offset in
            let firstChannelIsRed = bytes[offset] > 240 && bytes[offset + 2] < 15
            let thirdChannelIsRed = bytes[offset] < 15 && bytes[offset + 2] > 240
            if bytes[offset + 1] < 15, firstChannelIsRed || thirdChannelIsRed {
                count += 1
            }
        }

        #expect(redPixelCount > 0, "The banner must retain visible area when no text rows exist.")
    }
}
