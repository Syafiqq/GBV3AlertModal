import UIKit

public struct DataHolder {
    public var title: String?
    public var attributedTitle: NSAttributedString?
    public var subtitle: NSAttributedString?
    public var attributedSubtitle: NSAttributedString?
    public weak var subtitleCustomView: UIView?
    public var primaryAction: String?
    public var primaryActionStyle: ActionStyle?
    public var secondaryAction: String?
    public var secondaryActionStyle: String?
    public var closeOnTapOverlay: Bool
    public var showCloseButton: Bool
    public var dismissOnAction: Bool
    public var completion: ((AlertModal, ActionType) -> Void)?

    public init(title: String?, attributedTitle: NSAttributedString?, subtitle: NSAttributedString?, attributedSubtitle: NSAttributedString?, subtitleCustomView: UIView?, primaryAction: String?, primaryActionStyle: ActionStyle?, secondaryAction: String?, secondaryActionStyle: String?, closeOnTapOverlay: Bool, showCloseButton: Bool, dismissOnAction: Bool, completion: ((AlertModal, ActionType) -> ())?) {
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
