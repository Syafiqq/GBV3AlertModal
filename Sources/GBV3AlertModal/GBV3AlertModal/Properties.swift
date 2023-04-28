import UIKit

public struct DialogProperties {
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

    public let bannerToBelowSpace: CGFloat?
    public let titleToBelowSpace: CGFloat?
    public let subtitleToBelowSpace: CGFloat?
    public let buttonActionSpace: CGFloat?

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
            bannerToBelowSpace: CGFloat? = nil,
            titleToBelowSpace: CGFloat? = nil,
            subtitleToBelowSpace: CGFloat? = nil,
            buttonActionSpace: CGFloat? = nil
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
        self.bannerToBelowSpace = bannerToBelowSpace
        self.titleToBelowSpace = titleToBelowSpace
        self.subtitleToBelowSpace = subtitleToBelowSpace
        self.buttonActionSpace = buttonActionSpace
    }
}
