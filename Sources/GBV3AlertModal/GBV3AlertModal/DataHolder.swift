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
}
