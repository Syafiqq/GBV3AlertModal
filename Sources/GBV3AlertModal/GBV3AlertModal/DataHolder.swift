import UIKit

public struct DataHolder {
    public let title: String?
    public let attributedTitle: NSAttributedString?
    public let subtitle: NSAttributedString?
    public let attributedSubtitle: NSAttributedString?
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
            title: String? = nil,
            attributedTitle: NSAttributedString? = nil,
            subtitle: NSAttributedString? = nil,
            attributedSubtitle: NSAttributedString? = nil,
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
        self.title = title
        self.attributedTitle = attributedTitle
        self.subtitle = subtitle
        self.attributedSubtitle = attributedSubtitle
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
