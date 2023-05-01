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
            self.secondaryAction = secondaryAction
            self.secondaryActionStyle = secondaryActionStyle
            self.showCloseButton = showCloseButton
            self.closeImage = closeImage
            self.dismissOnAction = dismissOnAction
            self.completion = completion
        }

        public func copy(
                closeOnTapOverlay: Bool? = nil,
                banner: UIImage? = nil,
                title: String? = nil,
                titleAttributed: NSAttributedString? = nil,
                subtitle: String? = nil,
                subtitleAttributed: NSAttributedString? = nil,
                subtitleCustomView: UIView? = nil,
                primaryAction: String? = nil,
                secondaryAction: String? = nil,
                secondaryActionStyle: ActionStyle? = nil,
                showCloseButton: Bool? = nil,
                closeImage: UIImage? = nil,
                dismissOnAction: Bool? = nil,
                completion: ((GBAlertModal, GBAlertModal.ActionType) -> Void)? = nil
        ) -> Self {
            Self(
                    closeOnTapOverlay: closeOnTapOverlay ?? self.closeOnTapOverlay,
                    banner: banner ?? self.banner,
                    title: title ?? self.title,
                    titleAttributed: titleAttributed ?? self.titleAttributed,
                    subtitle: subtitle ?? self.subtitle,
                    subtitleAttributed: subtitleAttributed ?? self.subtitleAttributed,
                    subtitleCustomView: subtitleCustomView ?? self.subtitleCustomView,
                    primaryAction: primaryAction ?? self.primaryAction,
                    secondaryAction: secondaryAction ?? self.secondaryAction,
                    secondaryActionStyle: secondaryActionStyle ?? self.secondaryActionStyle,
                    showCloseButton: showCloseButton ?? self.showCloseButton,
                    closeImage: closeImage ?? self.closeImage,
                    dismissOnAction: dismissOnAction ?? self.dismissOnAction,
                    completion: completion ?? self.completion
            )
        }
    }
}
