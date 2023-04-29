import UIKit

extension GBAlertModal {
    public struct Properties {
        public let baseTint: UIColor?
        public let overlayColor: UIColor?
        public let contentBackgroundColor: UIColor?

        public let contentCornerRadius: CGFloat?
        public let contentFixedSize: CGFloat?
        public let margin: UIEdgeInsets?
        public let padding: UIMinMaxEdgeInsets?

        public let contentFitSize: Bool?
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
                contentBackgroundColor: UIColor? = nil,
                contentCornerRadius: CGFloat? = nil,
                contentFixedSize: CGFloat? = nil,
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
            self.contentBackgroundColor = contentBackgroundColor
            self.contentCornerRadius = contentCornerRadius
            self.contentFixedSize = contentFixedSize
            self.margin = margin
            self.padding = padding
            self.contentFitSize = contentFitSize
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
