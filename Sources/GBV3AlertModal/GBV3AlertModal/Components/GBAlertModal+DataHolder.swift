import UIKit

extension GBAlertModal {
    public struct DataHolder {
        public let closeOnTapOverlay: Bool

        public let banner: UIImage?

        public let title: String?
        public let titleAttributed: NSAttributedString?

        public init(
                closeOnTapOverlay: Bool = false,
                banner: UIImage? = nil,
                title: String? = nil,
                titleAttributed: NSAttributedString? = nil
        ) {
            self.closeOnTapOverlay = closeOnTapOverlay
            self.banner = banner
            self.title = title
            self.titleAttributed = titleAttributed
        }
    }
}
