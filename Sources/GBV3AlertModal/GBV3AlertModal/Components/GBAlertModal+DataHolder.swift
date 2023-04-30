import UIKit

extension GBAlertModal {
    public struct DataHolder {
        public static var `default`: Self {
            Self()
        }

        public let closeOnTapOverlay: Bool

        public let banner: UIImage?

        public let title: String?
        public let titleAttributed: NSAttributedString?

        public let subtitle: String?
        public let subtitleAttributed: NSAttributedString?
        public weak var subtitleCustomView: UIView?

        public let primaryAction: String?
        public let primaryActionStyle: ActionStyle?

        public let secondaryAction: String?
        public let secondaryActionStyle: ActionStyle?

        public let showCloseButton: Bool
        public let closeImage: UIImage?

        public let dismissOnAction: Bool
        public let completion: ((GBAlertModal, GBAlertModal.ActionType) -> Void)?

        public init(
                closeOnTapOverlay: Bool = false,
                banner: UIImage? = nil,
                title: String? = nil,
                titleAttributed: NSAttributedString? = nil,
                subtitle: String? = nil,
                subtitleAttributed: NSAttributedString? = nil,
                subtitleCustomView: UIView? = nil,
                primaryAction: String? = nil,
                primaryActionStyle: ActionStyle? = nil,
                secondaryAction: String? = nil,
                secondaryActionStyle: ActionStyle? = nil,
                showCloseButton: Bool = false,
                closeImage: UIImage? = nil,
                dismissOnAction: Bool = false,
                completion: ((GBAlertModal, GBAlertModal.ActionType) -> Void)? = nil
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
            self.secondaryAction = secondaryAction
            self.secondaryActionStyle = secondaryActionStyle
            self.showCloseButton = showCloseButton
            self.closeImage = closeImage
            self.dismissOnAction = dismissOnAction
            self.completion = completion
        }
    }
}
