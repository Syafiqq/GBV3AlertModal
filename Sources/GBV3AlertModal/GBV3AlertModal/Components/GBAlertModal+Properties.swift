import UIKit

extension GBAlertModal {
    public struct Properties {
        public let baseTint: UIColor?
        public let overlayColor: UIColor?
        public let contentProperty: ContentProperty?

        public let margin: UIEdgeInsets?
        public let padding: UIMinMaxEdgeInsets?

        public let bannerRatio: CGFloat?
        public let titleFont: UIFont?
        public let titleColor: UIColor?
        public let subtitleFont: UIFont?
        public let subtitleColor: UIColor?
        public let buttonActionFitSize: Bool?

        public let space: ComponentSpace?

        public init(
                baseTint: UIColor? = nil,
                overlayColor: UIColor? = nil,
                contentProperty: ContentProperty? = nil,
                margin: UIEdgeInsets? = nil,
                padding: UIMinMaxEdgeInsets? = nil,
                contentFitSize: Bool? = false,
                bannerRatio: CGFloat? = nil,
                titleFont: UIFont? = nil,
                titleColor: UIColor? = nil,
                subtitleFont: UIFont? = nil,
                subtitleColor: UIColor? = nil,
                buttonActionFitSize: Bool? = false,
                space: ComponentSpace? = nil
        ) {
            self.baseTint = baseTint
            self.overlayColor = overlayColor
            self.contentProperty = contentProperty
            self.margin = margin
            self.padding = padding
            self.bannerRatio = bannerRatio
            self.titleFont = titleFont
            self.titleColor = titleColor
            self.subtitleFont = subtitleFont
            self.subtitleColor = subtitleColor
            self.buttonActionFitSize = buttonActionFitSize
            self.space = space
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

        func copy(
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

public extension GBAlertModal.Properties {
    struct ContentProperty {
        public static var `default`: Self {
            Self()
        }

        public let backgroundColor: UIColor?
        public let cornerRadius: CGFloat
        public let fixedWidth: CGFloat?
        public let childShouldMatchParent: Bool

        public init(
                backgroundColor: UIColor? = nil,
                cornerRadius: CGFloat = .zero,
                fixedWidth: CGFloat? = nil,
                childShouldMatchParent: Bool = false
        ) {
            self.backgroundColor = backgroundColor
            self.cornerRadius = cornerRadius
            self.fixedWidth = fixedWidth
            self.childShouldMatchParent = childShouldMatchParent
        }

        func copy(
                backgroundColor: UIColor? = nil,
                cornerRadius: CGFloat? = nil,
                fixedWidth: CGFloat? = nil,
                childShouldMatchParent: Bool? = nil
        ) -> Self {
            Self(
                    backgroundColor: backgroundColor ?? self.backgroundColor,
                    cornerRadius: cornerRadius ?? self.cornerRadius,
                    fixedWidth: fixedWidth ?? self.fixedWidth,
                    childShouldMatchParent: childShouldMatchParent ?? self.childShouldMatchParent
            )
        }
    }
}
