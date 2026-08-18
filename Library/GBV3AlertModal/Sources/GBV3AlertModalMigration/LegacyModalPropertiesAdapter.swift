import GBV3AlertModalCore
import GBV3AlertModalSwiftUI
import GBV3AlertModalUIKit

import SwiftUI
import UIKit

public extension ModalProperties {
    /// Converts the legacy UIKit configuration into SwiftUI-native configuration values.
    ///
    /// `bannerRatio` is intentionally omitted because SwiftUI uses the image's intrinsic aspect
    /// ratio. `bannerFixedHeight` is also omitted because the legacy renderer does not apply it;
    /// `bannerMaxHeight` is the only legacy banner constraint represented by `ModalProperties`.
    init(adapting legacy: GBAlertModal.Properties) {
        self.init(
            baseTint: legacy.baseTint.map(Color.init(uiColor:)),
            overlayColor: legacy.overlayColor.map(Color.init(uiColor:)),
            contentProperty: legacy.contentProperty.map(Self.ContentProperty.init(adapting:)),
            margin: legacy.margin.map(EdgeInsets.init(adapting:)),
            padding: legacy.padding,
            banner: legacy.bannerMaxHeight.map { ModalBannerConfiguration(maximumHeight: $0) },
            titleFont: legacy.titleFont.map(ModalFont.init(adapting:)),
            titleColor: legacy.titleColor.map(Color.init(uiColor:)),
            subtitleFont: legacy.subtitleFont.map(ModalFont.init(adapting:)),
            subtitleColor: legacy.subtitleColor.map(Color.init(uiColor:)),
            buttonActionShouldMatchParent: legacy.buttonActionShouldMatchParent,
            buttonActionOrientation: legacy.buttonActionOrientation.map(Axis.init(adapting:)),
            primaryActionStyle: legacy.primaryActionStyle.map(Self.ActionStyle.init(adapting:)),
            secondaryActionStyle: legacy.secondaryActionStyle.map(Self.ActionStyle.init(adapting:)),
            closeButtonTint: legacy.closeButtonTint.map(Color.init(uiColor:)),
            space: legacy.space.map(Self.ComponentSpace.init(adapting:))
        )
    }
}

private extension ModalProperties.ContentProperty {
    init(adapting legacy: GBAlertModal.Properties.ContentProperty) {
        self.init(
            backgroundColor: legacy.backgroundColor.map(Color.init(uiColor:)),
            cornerRadius: legacy.cornerRadius,
            fixedWidthPortrait: legacy.fixedWidthPortrait,
            maxWidthPortrait: legacy.maxWidthPortrait,
            fixedWidthLandscape: legacy.fixedWidthLandscape,
            maxWidthLandscape: legacy.maxWidthLandscape,
            childShouldMatchParent: legacy.childShouldMatchParent
        )
    }
}

private extension ModalProperties.ComponentSpace {
    init(adapting legacy: GBAlertModal.Properties.ComponentSpace) {
        self.init(
            banner: legacy.banner,
            title: legacy.title,
            subtitle: legacy.subtitle,
            interButton: legacy.interButton
        )
    }
}

private extension EdgeInsets {
    init(adapting legacy: UIEdgeInsets) {
        self.init(top: legacy.top, leading: legacy.left, bottom: legacy.bottom, trailing: legacy.right)
    }
}

private extension Axis {
    init(adapting legacy: NSLayoutConstraint.Axis) {
        self = legacy == .horizontal ? .horizontal : .vertical
    }
}

extension ModalFont {
    init(adapting uiFont: UIFont) {
        let isSystem = uiFont.familyName == ".AppleSystemUIFont" || uiFont.fontName.hasPrefix(".SFUI")
        self.init(
            family: isSystem ? .system : .custom(uiFont.fontName),
            size: uiFont.pointSize,
            weight: Self.weight(adapting: uiFont),
            scalingPolicy: .fixed
        )
    }

    private static func weight(adapting font: UIFont) -> Weight {
        let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
        let value = traits?[.weight] as? CGFloat ?? 0
        switch value {
        case ..<(-0.7): return .ultraLight
        case ..<(-0.5): return .thin
        case ..<(-0.2): return .light
        case ..<0.115: return .regular
        case ..<0.265: return .medium
        case ..<0.35: return .semibold
        case ..<0.48: return .bold
        case ..<0.59: return .heavy
        default: return .black
        }
    }
}

private extension ModalProperties.ActionStyle {
    init(adapting legacy: GBAlertModal.ActionStyle) {
        switch legacy {
        case let .capsule(theme): self = .capsule(.init(adapting: theme))
        case let .capsuleOutlined(theme): self = .capsuleOutlined(.init(adapting: theme))
        case let .plain(theme): self = .plain(.init(adapting: theme))
        case let .obliqueBottomLeft(theme): self = .obliqueBottomLeft(.init(adapting: theme))
        }
    }
}

private extension ModalProperties.ActionStyle.CapsuleTheme {
    init(adapting value: GBAlertModal.ActionStyle.CapsuleTheme) {
        self.init(
            backgroundColor: value.backgroundColor.map(Color.init(uiColor:)),
            backgroundDisableColor: value.backgroundDisableColor.map(Color.init(uiColor:)),
            titleColor: value.titleColor.map(Color.init(uiColor:)),
            titleDisableColor: value.titleDisableColor.map(Color.init(uiColor:)),
            titleFont: value.titleFont.map(ModalFont.init(adapting:))
        )
    }
}

private extension ModalProperties.ActionStyle.CapsuleOutlineTheme {
    init(adapting value: GBAlertModal.ActionStyle.CapsuleOutlineTheme) {
        self.init(
            backgroundColor: value.backgroundColor.map(Color.init(uiColor:)),
            backgroundDisableColor: value.backgroundDisableColor.map(Color.init(uiColor:)),
            titleColor: value.titleColor.map(Color.init(uiColor:)),
            titleDisableColor: value.titleDisableColor.map(Color.init(uiColor:)),
            borderWidth: value.borderWidth,
            borderColor: value.borderColor.map(Color.init(cgColor:)),
            borderDisableColor: value.borderDisableColor.map(Color.init(cgColor:)),
            titleFont: value.titleFont.map(ModalFont.init(adapting:))
        )
    }
}

private extension ModalProperties.ActionStyle.PlainTheme {
    init(adapting value: GBAlertModal.ActionStyle.PlainTheme) {
        self.init(
            titleColor: value.titleColor.map(Color.init(uiColor:)),
            titleDisableColor: value.titleDisableColor.map(Color.init(uiColor:)),
            titleFont: value.titleFont.map(ModalFont.init(adapting:))
        )
    }
}

private extension ModalProperties.ActionStyle.ObliqueBottomLeftTheme {
    init(adapting value: GBAlertModal.ActionStyle.ObliqueBottomLeftTheme) {
        self.init(
            unPressedColor: value.unPressedColor.map(Color.init(uiColor:)),
            pressedColor: value.pressedColor.map(Color.init(uiColor:)),
            disabledColor: value.disabledColor.map(Color.init(uiColor:)),
            shadowColor: value.shadowColor.map(Color.init(cgColor:)),
            titleColor: value.titleColor.map(Color.init(uiColor:)),
            titleDisableColor: value.titleDisableColor.map(Color.init(uiColor:)),
            titleFont: value.titleFont.map(ModalFont.init(adapting:))
        )
    }
}
