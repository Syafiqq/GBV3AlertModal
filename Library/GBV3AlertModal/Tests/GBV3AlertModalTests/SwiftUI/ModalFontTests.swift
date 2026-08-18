import SwiftUI
import Testing
import UIKit
@testable import GBV3AlertModal

struct ModalFontTests {
    @Test(arguments: ModalFont.Weight.allCases)
    func systemDescriptorPreservesEveryWeight(_ weight: ModalFont.Weight) {
        let font = ModalFont.system(size: 18, weight: weight)

        #expect(font.family == .system)
        #expect(font.size == 18)
        #expect(font.weight == weight)
        #expect(font.scalingPolicy == .fixed)
    }

    @Test
    func customDescriptorIsFixedByDefault() {
        let font = ModalFont.custom("SHSans-Bold", size: 24)

        #expect(font.family == .custom("SHSans-Bold"))
        #expect(font.size == 24)
        #expect(font.weight == .regular)
        #expect(font.scalingPolicy == .fixed)
    }

    @Test(arguments: ModalFont.TextStyle.allCases)
    func semanticScalingRecordsItsRelativeTextStyle(_ style: ModalFont.TextStyle) {
        let font = ModalFont.custom(
            "SHSans-Regular",
            size: 16,
            scalingPolicy: .relative(to: style)
        )

        #expect(font.scalingPolicy == .relative(to: style))
        _ = font.font
    }

    @Test
    func missingCustomFamilyRemainsRenderableThroughSwiftUIFallback() {
        let font = ModalFont.custom("Definitely-Not-An-Installed-Font", size: 17)

        #expect(font.family == .custom("Definitely-Not-An-Installed-Font"))
        _ = font.font
    }

    @Test
    func descriptorsAreEquatableAndSendable() {
        let lhs = ModalFont.system(size: 16, weight: .semibold)
        let rhs = ModalFont.system(size: 16, weight: .semibold)

        #expect(lhs == rhs)
        acceptSendable(lhs)
    }

    @Test
    func legacySystemAdapterPreservesEveryWeight() {
        let cases: [(UIFont.Weight, ModalFont.Weight)] = [
            (.ultraLight, .ultraLight), (.thin, .thin), (.light, .light),
            (.regular, .regular), (.medium, .medium), (.semibold, .semibold),
            (.bold, .bold), (.heavy, .heavy), (.black, .black)
        ]

        for (uiWeight, expected) in cases {
            let adapted = ModalFont(UIFont.systemFont(ofSize: 18, weight: uiWeight))
            #expect(adapted.weight == expected)
        }
    }

    private func acceptSendable<T: Sendable>(_: T) {}
}
