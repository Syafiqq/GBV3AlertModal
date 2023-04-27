import UIKit

public struct DialogProperties {
    public var baseTint: UIColor?
    public var overlayColor: UIColor?
    public var contentBackgroundColor: UIColor?

    public var contentCornerRadius: CGFloat?
    public var contentVerticalMargin: CGFloat?
    public var contentHorizontalMargin: CGFloat?
    public var contentTopPadding: (CGFloat, CGFloat)?
    public var contentBottomPadding: (CGFloat, CGFloat)?
    public var contentHorizontalPadding: (CGFloat, CGFloat)?

    public var titleFont: UIFont?
    public var titleColor: UIColor?
    public var subtitleFont: UIFont
    public var subtitleColor: UIColor?

    public var titleToSubtitleSpace: CGFloat?
}
