import Foundation

/// The general-purpose alert/confirm dialog: content only. Style is fixed by the renderer.
public struct AlertDialog: ModalDescriptor {
    public enum Result: Sendable, Equatable { case primary, secondary, dismissed }
    public static var dismissedResult: Result { .dismissed }

    public var image: ModalImage?
    public var title: String?
    public var subtitle: String?
    public var primary: String
    public var secondary: String?
    public var closeOnTapOverlay: Bool
    public var showCloseButton: Bool

    public init(
        image: ModalImage? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        primary: String,
        secondary: String? = nil,
        closeOnTapOverlay: Bool = false,
        showCloseButton: Bool = false
    ) {
        self.image = image
        self.title = title
        self.subtitle = subtitle
        self.primary = primary
        self.secondary = secondary
        self.closeOnTapOverlay = closeOnTapOverlay
        self.showCloseButton = showCloseButton
    }
}
