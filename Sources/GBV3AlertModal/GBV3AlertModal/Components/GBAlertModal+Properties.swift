import UIKit

extension GBAlertModal {
    public struct Properties {
        public let baseTint: UIColor?
        public let overlayColor: UIColor?

        public init(
                baseTint: UIColor? = nil,
                overlayColor: UIColor? = nil
        ) {
            self.baseTint = baseTint
            self.overlayColor = overlayColor
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
        public let maxWidth: CGFloat?

        public init(
                backgroundColor: UIColor? = nil,
                cornerRadius: CGFloat = .zero,
                fixedWidth: CGFloat? = nil,
                maxWidth: CGFloat? = nil
        ) {
            self.backgroundColor = backgroundColor
            self.cornerRadius = cornerRadius
            self.fixedWidth = fixedWidth
            self.maxWidth = maxWidth
        }

        public func copy(
                backgroundColor: UIColor? = nil,
                cornerRadius: CGFloat? = nil,
                fixedWidth: CGFloat? = nil,
                maxWidth: CGFloat? = nil
        ) -> Self {
            Self(
                    backgroundColor: backgroundColor ?? self.backgroundColor,
                    cornerRadius: cornerRadius ?? self.cornerRadius,
                    fixedWidth: fixedWidth ?? self.fixedWidth,
                    maxWidth: maxWidth ?? self.maxWidth
            )
        }
    }
}
