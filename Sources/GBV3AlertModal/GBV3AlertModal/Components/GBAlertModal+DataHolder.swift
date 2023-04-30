import UIKit

extension GBAlertModal {
    public struct DataHolder {
        public let closeOnTapOverlay: Bool

        public init(
                closeOnTapOverlay: Bool = false
        ) {
            self.closeOnTapOverlay = closeOnTapOverlay
        }
    }
}
