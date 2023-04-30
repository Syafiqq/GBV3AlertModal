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
