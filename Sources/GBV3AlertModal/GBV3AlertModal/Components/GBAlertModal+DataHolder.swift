import UIKit

extension GBAlertModal {
    public struct DataHolder {
        public let closeOnTapOverlay: Bool

        public let banner: UIImage?

        public init(
                closeOnTapOverlay: Bool = false,
                banner: UIImage? = nil
        ) {
            self.closeOnTapOverlay = closeOnTapOverlay
            self.banner = banner
        }
    }
}
