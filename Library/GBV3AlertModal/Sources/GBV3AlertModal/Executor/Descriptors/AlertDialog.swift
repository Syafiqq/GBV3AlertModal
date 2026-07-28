import Foundation

/// The general-purpose alert/confirm dialog: content only. Style is fixed by the renderer.
public struct AlertDialog: ModalDescriptor {
    public enum Result: Sendable, Equatable { case primary, secondary, dismissed }
    public static var dismissedResult: Result { .dismissed }

    public var image: ModalImage?
    public var title: AttributedString?
    public var subtitle: AttributedString?
    public var primary: String
    public var secondary: String?
    public var closeOnTapOverlay: Bool
    public var showCloseButton: Bool

    /// Plain path — unchanged ergonomics for the ~114 existing String call sites.
    public init(
        image: ModalImage? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        primary: String,
        secondary: String? = nil,
        closeOnTapOverlay: Bool = false,
        showCloseButton: Bool = false
    ) {
        self.init(
            image: image,
            title: title.map(AttributedString.init),
            subtitle: subtitle.map(AttributedString.init),
            primary: primary,
            secondary: secondary,
            closeOnTapOverlay: closeOnTapOverlay,
            showCloseButton: showCloseButton
        )
    }

    /// Rich path — title/subtitle are NOT defaulted, so `AlertDialog(primary:)` can only
    /// resolve to the String init above (kills the all-text-omitted overload ambiguity).
    public init(
        image: ModalImage? = nil,
        title: AttributedString?,
        subtitle: AttributedString?,
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
