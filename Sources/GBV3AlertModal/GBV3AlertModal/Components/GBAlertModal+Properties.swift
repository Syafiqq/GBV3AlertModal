import UIKit

extension GBAlertModal {
    public struct Properties {
        public static var `default`: Self {
            Self()
        }

        public let baseTint: UIColor?
        public let overlayColor: UIColor?
        public let contentProperty: ContentProperty?

        public let margin: UIEdgeInsets?
        public let padding: UIMinMaxEdgeInsets?

        public let bannerRatio: CGFloat?
        public let bannerMaxHeight: CGFloat?
        public let bannerFixedHeight: CGFloat?
        public let titleFont: UIFont?
        public let titleColor: UIColor?
        public let subtitleFont: UIFont?
        public let subtitleColor: UIColor?
        public let buttonActionShouldMatchParent: Bool?
        public let buttonActionOrientation: NSLayoutConstraint.Axis?
        public let primaryActionStyle: ActionStyle?
        public let secondaryActionStyle: ActionStyle?

        public let closeButtonTint: UIColor?

        public let space: ComponentSpace?

        public init(
                baseTint: UIColor? = nil,
                overlayColor: UIColor? = nil,
                contentProperty: ContentProperty? = nil,
                margin: UIEdgeInsets? = nil,
                padding: UIMinMaxEdgeInsets? = nil,
                bannerRatio: CGFloat? = nil,
                bannerMaxHeight: CGFloat? = nil,
                bannerFixedHeight: CGFloat? = nil,
                titleFont: UIFont? = nil,
                titleColor: UIColor? = nil,
                subtitleFont: UIFont? = nil,
                subtitleColor: UIColor? = nil,
                buttonActionShouldMatchParent: Bool? = false,
                buttonActionOrientation: NSLayoutConstraint.Axis? = nil,
                primaryActionStyle: ActionStyle? = nil,
                secondaryActionStyle: ActionStyle? = nil,
                closeButtonTint: UIColor? = nil,
                space: ComponentSpace? = nil
        ) {
            self.baseTint = baseTint
            self.overlayColor = overlayColor
            self.contentProperty = contentProperty
            self.margin = margin
            self.padding = padding
            self.bannerRatio = bannerRatio
            self.bannerMaxHeight = bannerMaxHeight
            self.bannerFixedHeight = bannerFixedHeight
            self.titleFont = titleFont
            self.titleColor = titleColor
            self.subtitleFont = subtitleFont
            self.subtitleColor = subtitleColor
            self.buttonActionShouldMatchParent = buttonActionShouldMatchParent
            self.buttonActionOrientation = buttonActionOrientation
            self.primaryActionStyle = primaryActionStyle
            self.secondaryActionStyle = secondaryActionStyle
            self.closeButtonTint = closeButtonTint
            self.space = space
        }

        public func copy(
                baseTint: UIColor? = nil,
                overlayColor: UIColor? = nil,
                contentProperty: ContentProperty? = nil,
                margin: UIEdgeInsets? = nil,
                padding: UIMinMaxEdgeInsets? = nil,
                bannerRatio: CGFloat? = nil,
                bannerMaxHeight: CGFloat? = nil,
                bannerFixedHeight: CGFloat? = nil,
                titleFont: UIFont? = nil,
                titleColor: UIColor? = nil,
                subtitleFont: UIFont? = nil,
                subtitleColor: UIColor? = nil,
                buttonActionShouldMatchParent: Bool? = nil,
                buttonActionOrientation: NSLayoutConstraint.Axis? = nil,
                primaryActionStyle: ActionStyle? = nil,
                secondaryActionStyle: ActionStyle? = nil,
                closeButtonTint: UIColor? = nil,
                space: ComponentSpace? = nil
        ) -> Self {
            Self(
                    baseTint: baseTint ?? self.baseTint,
                    overlayColor: overlayColor ?? self.overlayColor,
                    contentProperty: contentProperty ?? self.contentProperty,
                    margin: margin ?? self.margin,
                    padding: padding ?? self.padding,
                    bannerRatio: bannerRatio ?? self.bannerRatio,
                    bannerMaxHeight: bannerMaxHeight ?? self.bannerMaxHeight,
                    bannerFixedHeight: bannerFixedHeight ?? self.bannerFixedHeight,
                    titleFont: titleFont ?? self.titleFont,
                    titleColor: titleColor ?? self.titleColor,
                    subtitleFont: subtitleFont ?? self.subtitleFont,
                    subtitleColor: subtitleColor ?? self.subtitleColor,
                    buttonActionShouldMatchParent: buttonActionShouldMatchParent ?? self.buttonActionShouldMatchParent,
                    buttonActionOrientation: buttonActionOrientation ?? self.buttonActionOrientation,
                    primaryActionStyle: primaryActionStyle ?? self.primaryActionStyle,
                    secondaryActionStyle: secondaryActionStyle ?? self.secondaryActionStyle,
                    closeButtonTint: closeButtonTint ?? self.closeButtonTint,
                    space: space ?? self.space
            )
        }
    }
}

public extension GBAlertModal.Properties {
    struct ContentProperty {
        public static var `default`: Self {
            Self()
        }

        public let backgroundColor: UIColor?
        public let cornerRadius: CGFloat
        public let fixedWidthPortrait: CGFloat?
        public let maxWidthPortrait: CGFloat?
        public let fixedWidthLandscape: CGFloat?
        public let maxWidthLandscape: CGFloat?
        public let childShouldMatchParent: Bool

        public init(
                backgroundColor: UIColor? = nil,
                cornerRadius: CGFloat = .zero,
                fixedWidthPortrait: CGFloat? = nil,
                maxWidthPortrait: CGFloat? = nil,
                fixedWidthLandscape: CGFloat? = nil,
                maxWidthLandscape: CGFloat? = nil,
                childShouldMatchParent: Bool = false
        ) {
            self.backgroundColor = backgroundColor
            self.cornerRadius = cornerRadius
            self.fixedWidthPortrait = fixedWidthPortrait
            self.maxWidthPortrait = maxWidthPortrait
            self.fixedWidthLandscape = fixedWidthLandscape
            self.maxWidthLandscape = maxWidthLandscape
            self.childShouldMatchParent = childShouldMatchParent
        }

        public func copy(
                backgroundColor: UIColor? = nil,
                cornerRadius: CGFloat? = nil,
                fixedWidthPortrait: CGFloat? = nil,
                maxWidthPortrait: CGFloat? = nil,
                fixedWidthLandscape: CGFloat? = nil,
                maxWidthLandscape: CGFloat? = nil,
                childShouldMatchParent: Bool? = nil
        ) -> Self {
            Self(
                    backgroundColor: backgroundColor ?? self.backgroundColor,
                    cornerRadius: cornerRadius ?? self.cornerRadius,
                    fixedWidthPortrait: fixedWidthPortrait ?? self.fixedWidthPortrait,
                    maxWidthPortrait: maxWidthPortrait ?? self.maxWidthPortrait,
                    fixedWidthLandscape: fixedWidthLandscape ?? self.fixedWidthLandscape,
                    maxWidthLandscape: maxWidthLandscape ?? self.maxWidthLandscape,
                    childShouldMatchParent: childShouldMatchParent ?? self.childShouldMatchParent
            )
        }
    }
}

public extension GBAlertModal.Properties {
    struct ComponentSpace {
        public static var zero: Self {
            Self()
        }

        public let banner: CGFloat
        public let title: CGFloat
        public let subtitle: CGFloat
        public let interButton: CGFloat

        public init(
                banner: CGFloat = .zero,
                title: CGFloat = .zero,
                subtitle: CGFloat = .zero,
                interButton: CGFloat = .zero
        ) {
            self.banner = banner
            self.title = title
            self.subtitle = subtitle
            self.interButton = interButton
        }

        public func copy(
                banner: CGFloat? = nil,
                title: CGFloat? = nil,
                subtitle: CGFloat? = nil,
                interButton: CGFloat? = nil
        ) -> Self {
            Self(
                    banner: banner ?? self.banner,
                    title: title ?? self.title,
                    subtitle: subtitle ?? self.subtitle,
                    interButton: interButton ?? self.interButton
            )
        }
    }
}
