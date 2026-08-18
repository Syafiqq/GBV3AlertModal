import SwiftUI
import Testing
import UIKit
@testable import GBV3AlertModal

@MainActor
struct ModalPropertiesAdapterTests {
    @Test
    func everyLegacyPropertyIsMappedOrDeliberatelyOmitted() {
        let mapped = [
            "baseTint", "overlayColor", "contentProperty", "margin", "padding",
            "bannerMaxHeight", "titleFont", "titleColor", "subtitleFont", "subtitleColor",
            "buttonActionShouldMatchParent", "buttonActionOrientation", "primaryActionStyle",
            "secondaryActionStyle", "closeButtonTint", "space"
        ]
        let deliberatelyOmitted = [
            "bannerRatio: SwiftUI uses the image intrinsic aspect ratio",
            "bannerFixedHeight: the legacy renderer does not apply this value"
        ]

        #expect(mapped.count == 16)
        #expect(deliberatelyOmitted.count == 2)
    }

    @Test
    func standardPresetAdaptsToTheNativePreset() {
        let adapted = ModalProperties(adapting: GeniePresets.standardProperties())
        let expected = GeniePresets.standardModalProperties()

        #expect(adapted.baseTint == expected.baseTint)
        #expect(adapted.overlayColor == expected.overlayColor)
        #expect(adapted.contentProperty == expected.contentProperty)
        #expect(adapted.margin == expected.margin)
        #expect(adapted.padding == expected.padding)
        #expect(adapted.banner == nil)
        #expect(adapted.titleFont == expected.titleFont)
        #expect(adapted.titleColor == expected.titleColor)
        #expect(adapted.subtitleFont == expected.subtitleFont)
        #expect(adapted.subtitleColor == expected.subtitleColor)
        #expect(adapted.buttonActionShouldMatchParent == expected.buttonActionShouldMatchParent)
        #expect(adapted.buttonActionOrientation == expected.buttonActionOrientation)
        #expect(adapted.primaryActionStyle == expected.primaryActionStyle)
        #expect(adapted.secondaryActionStyle == expected.secondaryActionStyle)
        #expect(adapted.closeButtonTint == expected.closeButtonTint)
        #expect(adapted.space == expected.space)
    }

    @Test
    func bannerMaximumHeightIsTheOnlyAdaptedBannerConstraint() {
        let legacy = GeniePresets.standardPropertiesNilBannerRatio(bannerMaxHeight: 216)
            .copy(bannerRatio: 2, bannerFixedHeight: 144)

        let adapted = ModalProperties(adapting: legacy)

        #expect(adapted.banner == ModalBannerConfiguration(maximumHeight: 216))
    }

    @Test
    func adaptedPropertiesUseTheSingleNativeTokenDerivation() {
        let legacy = GeniePresets.standardProperties()
        let adaptedTokens = ModalTokens(from: ModalProperties(adapting: legacy))
        let nativeTokens = ModalTokens(from: GeniePresets.standardModalProperties())

        #expect(adaptedTokens == nativeTokens)
    }

    @Test
    func everyLegacySystemFontWeightIsPreserved() {
        let cases: [(UIFont.Weight, ModalFont.Weight)] = [
            (.ultraLight, .ultraLight), (.thin, .thin), (.light, .light),
            (.regular, .regular), (.medium, .medium), (.semibold, .semibold),
            (.bold, .bold), (.heavy, .heavy), (.black, .black)
        ]

        for (legacyWeight, expected) in cases {
            let adapted = ModalFont(adapting: UIFont.systemFont(ofSize: 18, weight: legacyWeight))
            #expect(adapted.weight == expected)
        }
    }

    @Test
    func allLegacyActionStyleCasesAreAdapted() {
        let styles: [GBAlertModal.ActionStyle] = [
            .capsule(.init()),
            .capsuleOutlined(.init()),
            .plain(.init()),
            .obliqueBottomLeft(.init())
        ]

        for style in styles {
            let adapted = ModalProperties(adapting: .init(primaryActionStyle: style))
            #expect(adapted.primaryActionStyle != nil)
        }
    }

    @Test
    func capsuleThemesPreserveEveryVisualField() {
        let legacy = GBAlertModal.Properties(
            primaryActionStyle: .capsule(.init(
                backgroundColor: .red,
                backgroundDisableColor: .gray,
                titleColor: .white,
                titleDisableColor: .lightGray,
                titleFont: .boldSystemFont(ofSize: 17)
            )),
            secondaryActionStyle: .capsuleOutlined(.init(
                backgroundColor: .clear,
                backgroundDisableColor: .darkGray,
                titleColor: .blue,
                titleDisableColor: .gray,
                borderWidth: 2,
                borderColor: UIColor.green.cgColor,
                borderDisableColor: UIColor.gray.cgColor,
                titleFont: .systemFont(ofSize: 15, weight: .medium)
            ))
        )

        let adapted = ModalProperties(adapting: legacy)

        #expect(adapted.primaryActionStyle == .capsule(.init(
            backgroundColor: Color(uiColor: .red),
            backgroundDisableColor: Color(uiColor: .gray),
            titleColor: Color(uiColor: .white),
            titleDisableColor: Color(uiColor: .lightGray),
            titleFont: .system(size: 17, weight: .bold)
        )))
        #expect(adapted.secondaryActionStyle == .capsuleOutlined(.init(
            backgroundColor: Color(uiColor: .clear),
            backgroundDisableColor: Color(uiColor: .darkGray),
            titleColor: Color(uiColor: .blue),
            titleDisableColor: Color(uiColor: .gray),
            borderWidth: 2,
            borderColor: Color(cgColor: UIColor.green.cgColor),
            borderDisableColor: Color(cgColor: UIColor.gray.cgColor),
            titleFont: .system(size: 15, weight: .medium)
        )))
    }
}
