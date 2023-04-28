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

    public let contentMatchParent: Bool?
    public let bannerRatio: CGFloat?
    public let titleFont: UIFont?
    public let titleColor: UIColor?
    public let subtitleFont: UIFont?
    public let subtitleColor: UIColor?

    public let bannerToTitleSpace: CGFloat?
    public let titleToSubtitleSpace: CGFloat?

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
            contentMatchParent: Bool? = false,
            bannerRatio: CGFloat? = nil,
            titleFont: UIFont? = nil,
            titleColor: UIColor? = nil,
            subtitleFont: UIFont? = nil,
            subtitleColor: UIColor? = nil,
            bannerToTitleSpace: CGFloat? = nil,
            titleToSubtitleSpace: CGFloat? = nil
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
        self.contentMatchParent = contentMatchParent
        self.bannerRatio = bannerRatio
        self.titleFont = titleFont
        self.titleColor = titleColor
        self.subtitleFont = subtitleFont
        self.subtitleColor = subtitleColor
        self.bannerToTitleSpace = bannerToTitleSpace
        self.titleToSubtitleSpace = titleToSubtitleSpace
    }
}
