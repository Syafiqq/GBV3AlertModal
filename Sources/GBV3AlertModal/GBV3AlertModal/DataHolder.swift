import UIKit

public struct DataHolder {
    public let banner: UIImage?
    public let title: String?
    public let titleAttributed: NSAttributedString?
    public let subtitle: String?
    public let subtitleAttributed: NSAttributedString?
    public weak var subtitleCustomView: UIView?
    public let primaryAction: String?
    public let primaryActionStyle: ActionStyle?
    public let secondaryAction: String?
    public let secondaryActionStyle: String?
    public let closeOnTapOverlay: Bool
    public let showCloseButton: Bool
    public let dismissOnAction: Bool
    public let completion: ((AlertModal, ActionType) -> Void)?

    public init(
            banner: UIImage? = nil,
            title: String? = nil,
            titleAttributed: NSAttributedString? = nil,
            subtitle: String? = nil,
            subtitleAttributed: NSAttributedString? = nil,
            subtitleCustomView: UIView? = nil,
            primaryAction: String? = nil,
            primaryActionStyle: ActionStyle? = nil,
            secondaryAction: String? = nil,
            secondaryActionStyle: String? = nil,
            closeOnTapOverlay: Bool = false,
            showCloseButton: Bool = false,
            dismissOnAction: Bool = false,
            completion: ((AlertModal, ActionType) -> Void)? = nil
    ) {
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
        self.closeOnTapOverlay = closeOnTapOverlay
        self.showCloseButton = showCloseButton
        self.dismissOnAction = dismissOnAction
        self.completion = completion
    }
}
