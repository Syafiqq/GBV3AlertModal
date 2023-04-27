import UIKit

public struct DialogProperties {
    public let baseTint: UIColor?
    public let overlayColor: UIColor?
    public let contentBackgroundColor: UIColor?

    public let contentCornerRadius: CGFloat?
    public let contentVerticalMargin: CGFloat?
    public let contentHorizontalMargin: CGFloat?
    public let contentTopPadding: (CGFloat, CGFloat)?
    public let contentBottomPadding: (CGFloat, CGFloat)?
    public let contentHorizontalPadding: (CGFloat, CGFloat)?

    public let titleFont: UIFont?
    public let titleColor: UIColor?
    public let subtitleFont: UIFont?
    public let subtitleColor: UIColor?

    public let titleToSubtitleSpace: CGFloat?

    public init(
            baseTint: UIColor? = nil,
            overlayColor: UIColor? = nil,
            contentBackgroundColor: UIColor? = nil,
            contentCornerRadius: CGFloat? = nil,
            contentVerticalMargin: CGFloat? = nil,
            contentHorizontalMargin: CGFloat? = nil,
            contentTopPadding: (CGFloat, CGFloat)? = nil,
            contentBottomPadding: (CGFloat, CGFloat)? = nil,
            contentHorizontalPadding: (CGFloat, CGFloat)? = nil,
            titleFont: UIFont? = nil,
            titleColor: UIColor? = nil,
            subtitleFont: UIFont? = nil,
            subtitleColor: UIColor? = nil,
            titleToSubtitleSpace: CGFloat? = nil
    ) {
        self.baseTint = baseTint
        self.overlayColor = overlayColor
        self.contentBackgroundColor = contentBackgroundColor
        self.contentCornerRadius = contentCornerRadius
        self.contentVerticalMargin = contentVerticalMargin
        self.contentHorizontalMargin = contentHorizontalMargin
        self.contentTopPadding = contentTopPadding
        self.contentBottomPadding = contentBottomPadding
        self.contentHorizontalPadding = contentHorizontalPadding
        self.titleFont = titleFont
        self.titleColor = titleColor
        self.subtitleFont = subtitleFont
        self.subtitleColor = subtitleColor
        self.titleToSubtitleSpace = titleToSubtitleSpace
    }
}
