import UIKit

extension GBAlertModal {
    public struct DataHolder {
        public let closeOnTapOverlay: Bool

        public let banner: UIImage?

        public let title: String?
        public let titleAttributed: NSAttributedString?

        public let subtitle: String?
        public let subtitleAttributed: NSAttributedString?
        public weak var subtitleCustomView: UIView?

        public let primaryAction: String?
        public let primaryActionStyle: ActionStyle?

        public init(
                closeOnTapOverlay: Bool = false,
                banner: UIImage? = nil,
                title: String? = nil,
                titleAttributed: NSAttributedString? = nil,
                subtitle: String? = nil,
                subtitleAttributed: NSAttributedString? = nil,
                subtitleCustomView: UIView? = nil,
                primaryAction: String? = nil,
                primaryActionStyle: ActionStyle? = nil
        ) {
            self.closeOnTapOverlay = closeOnTapOverlay
            self.banner = banner
            self.title = title
            self.titleAttributed = titleAttributed
            self.subtitle = subtitle
            self.subtitleAttributed = subtitleAttributed
            self.subtitleCustomView = subtitleCustomView
            self.primaryAction = primaryAction
            self.primaryActionStyle = primaryActionStyle
        }
    }
}
