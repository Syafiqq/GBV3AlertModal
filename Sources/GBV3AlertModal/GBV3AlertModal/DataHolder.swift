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
            title: String?,
            attributedTitle: NSAttributedString?,
            subtitle: NSAttributedString?,
            attributedSubtitle: NSAttributedString?,
            subtitleCustomView: UIView?,
            primaryAction: String?,
            primaryActionStyle: ActionStyle?,
            secondaryAction: String?,
            secondaryActionStyle: String?,
            closeOnTapOverlay: Bool,
            showCloseButton: Bool,
            dismissOnAction: Bool,
            completion: ((AlertModal, ActionType) -> Void)?
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
