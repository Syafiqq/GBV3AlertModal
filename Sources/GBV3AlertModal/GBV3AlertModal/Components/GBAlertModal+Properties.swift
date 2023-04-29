import UIKit

extension GBAlertModal {
    public struct Properties {
        public let baseTint: UIColor?
        public let overlayColor: UIColor?
        public let contentBackgroundColor: UIColor?

        public let contentCornerRadius: CGFloat?
        public let contentFixedSize: CGFloat?
        public let contentVerticalMargin: CGFloat?
        public let contentHorizontalMargin: CGFloat?
        public let contentTopPadding: (CGFloat, CGFloat)?
        public let contentBottomPadding: (CGFloat, CGFloat)?
        public let contentHorizontalPadding: (CGFloat, CGFloat)?

        public let contentFitSize: Bool?
        public let bannerRatio: CGFloat?
        public let titleFont: UIFont?
        public let titleColor: UIColor?
        public let subtitleFont: UIFont?
        public let subtitleColor: UIColor?
        public let buttonActionFitSize: Bool?

        public let componentSpace: ComponentSpace?

        public init(
                baseTint: UIColor? = nil,
                overlayColor: UIColor? = nil,
                contentBackgroundColor: UIColor? = nil,
                contentCornerRadius: CGFloat? = nil,
                contentFixedSize: CGFloat? = nil,
                contentVerticalMargin: CGFloat? = nil,
                contentHorizontalMargin: CGFloat? = nil,
                contentTopPadding: (CGFloat, CGFloat)? = nil,
                contentBottomPadding: (CGFloat, CGFloat)? = nil,
                contentHorizontalPadding: (CGFloat, CGFloat)? = nil,
                contentFitSize: Bool? = false,
                bannerRatio: CGFloat? = nil,
                titleFont: UIFont? = nil,
                titleColor: UIColor? = nil,
                subtitleFont: UIFont? = nil,
                subtitleColor: UIColor? = nil,
                buttonActionFitSize: Bool? = false,
                componentSpace: ComponentSpace? = nil
        ) {
            self.baseTint = baseTint
            self.overlayColor = overlayColor
            self.contentBackgroundColor = contentBackgroundColor
            self.contentCornerRadius = contentCornerRadius
            self.contentFixedSize = contentFixedSize
            self.contentVerticalMargin = contentVerticalMargin
            self.contentHorizontalMargin = contentHorizontalMargin
            self.contentTopPadding = contentTopPadding
            self.contentBottomPadding = contentBottomPadding
            self.contentHorizontalPadding = contentHorizontalPadding
            self.contentFitSize = contentFitSize
            self.bannerRatio = bannerRatio
            self.titleFont = titleFont
            self.titleColor = titleColor
            self.subtitleFont = subtitleFont
            self.subtitleColor = subtitleColor
            self.buttonActionFitSize = buttonActionFitSize
            self.componentSpace = componentSpace
        }
    }
}

public extension GBAlertModal.Properties {
    struct ComponentSpace {
        static var zero: Self {
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
    struct ComponentMargin {
        static var zero: Self {
            Self()
        }

        public let vertical: CGFloat
        public let horizontal: CGFloat

        public init(
                vertical: CGFloat = .zero,
                horizontal: CGFloat = .zero
        ) {
            self.vertical = vertical
            self.horizontal = horizontal
        }

        func copy(
                vertical: CGFloat? = nil,
                horizontal: CGFloat? = nil
        ) -> Self {
            Self(
                    vertical: vertical ?? self.vertical,
                    horizontal: horizontal ?? self.horizontal
            )
        }
    }
}
