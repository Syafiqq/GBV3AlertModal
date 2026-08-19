import GBV3AlertModalCore

import Foundation
import UIKit

public extension GBAlertModal {
    enum ActionStyle {
        case capsule(CapsuleTheme)
        case capsuleOutlined(CapsuleOutlineTheme)
        case plain(PlainTheme)
        case obliqueBottomLeft(ObliqueBottomLeftTheme)
    }
}

public extension GBAlertModal.ActionStyle {
    struct CapsuleTheme {
        public var backgroundColor: UIColor?
        public var backgroundDisableColor: UIColor?
        public var titleColor: UIColor?
        public var titleDisableColor: UIColor?
        public var titleFont: UIFont?

        public init(
                backgroundColor: UIColor? = nil,
                backgroundDisableColor: UIColor? = nil,
                titleColor: UIColor? = nil,
                titleDisableColor: UIColor? = nil,
                titleFont: UIFont? = nil
        ) {
            self.backgroundColor = backgroundColor
            self.backgroundDisableColor = backgroundDisableColor
            self.titleColor = titleColor
            self.titleDisableColor = titleDisableColor
            self.titleFont = titleFont
        }

        public func copy(
                backgroundColor: UIColor? = nil,
                backgroundDisableColor: UIColor? = nil,
                titleColor: UIColor? = nil,
                titleDisableColor: UIColor? = nil,
                titleFont: UIFont? = nil
        ) -> Self {
            Self(
                    backgroundColor: backgroundColor ?? self.backgroundColor,
                    backgroundDisableColor: backgroundDisableColor ?? self.backgroundDisableColor,
                    titleColor: titleColor ?? self.titleColor,
                    titleDisableColor: titleDisableColor ?? self.titleDisableColor,
                    titleFont: titleFont ?? self.titleFont
            )
        }
    }

    struct CapsuleOutlineTheme {
        public var backgroundColor: UIColor?
        public var backgroundDisableColor: UIColor?
        public var titleColor: UIColor?
        public var titleDisableColor: UIColor?
        public var borderWidth: CGFloat?
        public var borderColor: CGColor?
        public var borderDisableColor: CGColor?
        public var titleFont: UIFont?

        public init(
                backgroundColor: UIColor? = nil,
                backgroundDisableColor: UIColor? = nil,
                titleColor: UIColor? = nil,
                titleDisableColor: UIColor? = nil,
                borderWidth: CGFloat? = nil,
                borderColor: CGColor? = nil,
                borderDisableColor: CGColor? = nil,
                titleFont: UIFont? = nil
        ) {
            self.backgroundColor = backgroundColor
            self.backgroundDisableColor = backgroundDisableColor
            self.titleColor = titleColor
            self.titleDisableColor = titleDisableColor
            self.borderWidth = borderWidth
            self.borderColor = borderColor
            self.borderDisableColor = borderDisableColor
            self.titleFont = titleFont
        }

        public func copy(
                backgroundColor: UIColor? = nil,
                backgroundDisableColor: UIColor? = nil,
                titleColor: UIColor? = nil,
                titleDisableColor: UIColor? = nil,
                borderWidth: CGFloat? = nil,
                borderColor: CGColor? = nil,
                borderDisableColor: CGColor? = nil,
                titleFont: UIFont? = nil
        ) -> Self {
            Self(
                    backgroundColor: backgroundColor ?? self.backgroundColor,
                    backgroundDisableColor: backgroundDisableColor ?? self.backgroundDisableColor,
                    titleColor: titleColor ?? self.titleColor,
                    titleDisableColor: titleDisableColor ?? self.titleDisableColor,
                    borderWidth: borderWidth ?? self.borderWidth,
                    borderColor: borderColor ?? self.borderColor,
                    borderDisableColor: borderDisableColor ?? self.borderDisableColor,
                    titleFont: titleFont ?? self.titleFont
            )
        }
    }

    struct PlainTheme {
        public var titleColor: UIColor?
        public var titleDisableColor: UIColor?
        public var titleFont: UIFont?

        public init(
                titleColor: UIColor? = nil,
                titleDisableColor: UIColor? = nil,
                titleFont: UIFont? = nil
        ) {
            self.titleColor = titleColor
            self.titleDisableColor = titleDisableColor
            self.titleFont = titleFont
        }

        public func copy(
                titleColor: UIColor? = nil,
                titleDisableColor: UIColor? = nil,
                titleFont: UIFont? = nil
        ) -> Self {
            Self(
                    titleColor: titleColor ?? self.titleColor,
                    titleDisableColor: titleDisableColor ?? self.titleDisableColor,
                    titleFont: titleFont ?? self.titleFont
            )
        }
    }

    struct ObliqueBottomLeftTheme {
        public var unPressedColor: UIColor?
        public var pressedColor: UIColor?
        public var disabledColor: UIColor?
        public var shadowColor: CGColor?
        public var titleColor: UIColor?
        public var titleDisableColor: UIColor?
        public var titleFont: UIFont?

        public init(
                unPressedColor: UIColor? = nil,
                pressedColor: UIColor? = nil,
                disabledColor: UIColor? = nil,
                shadowColor: CGColor? = nil,
                titleColor: UIColor? = nil,
                titleDisableColor: UIColor? = nil,
                titleFont: UIFont? = nil
        ) {
            self.unPressedColor = unPressedColor
            self.pressedColor = pressedColor
            self.disabledColor = disabledColor
            self.shadowColor = shadowColor
            self.titleColor = titleColor
            self.titleDisableColor = titleDisableColor
            self.titleFont = titleFont
        }

        public func copy(
                unPressedColor: UIColor? = nil,
                pressedColor: UIColor? = nil,
                disabledColor: UIColor? = nil,
                shadowColor: CGColor? = nil,
                titleColor: UIColor? = nil,
                titleDisableColor: UIColor? = nil,
                titleFont: UIFont? = nil
        ) -> Self {
            Self(
                    unPressedColor: unPressedColor ?? self.unPressedColor,
                    pressedColor: pressedColor ?? self.pressedColor,
                    disabledColor: disabledColor ?? self.disabledColor,
                    shadowColor: shadowColor ?? self.shadowColor,
                    titleColor: titleColor ?? self.titleColor,
                    titleDisableColor: titleDisableColor ?? self.titleDisableColor,
                    titleFont: titleFont ?? self.titleFont
            )
        }
    }
}
