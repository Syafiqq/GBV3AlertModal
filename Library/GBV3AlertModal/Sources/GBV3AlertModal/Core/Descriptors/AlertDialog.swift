import Foundation

/// The general-purpose alert/confirm dialog: content, plus a `ModalStyle` token naming which
/// renderer-registered `Properties` preset to draw it with.
///
/// The token is how one content shape reaches MANY design-system presets. Register the preset once
/// per renderer (`register(style:properties:)`) and then ask for it per call site:
/// ```swift
/// renderer.register(style: .badge, properties: badgeProperties)
/// executor.present(AlertDialog(title: "Unlocked!", primary: "Nice", style: .badge))
/// ```
public struct AlertDialog: ModalDescriptor, StandardAlertContent {
    public enum Result: Sendable, Equatable { case primary, secondary, dismissed }
    public static var dismissedResult: Result { .dismissed }

    public var image: ModalImage?
    public var title: AttributedString?
    public var subtitle: AttributedString?
    public var primary: String
    public var secondary: String?
    public var closeOnTapOverlay: Bool
    public var showCloseButton: Bool
    /// Which registered style preset renders this dialog. Defaults to `.standard` in BOTH
    /// initializers, so every existing call site keeps its exact behaviour. An unregistered style
    /// falls back to `.standard` rather than failing — see the renderers' `properties(for:)`.
    public var style: ModalStyle

    /// Plain path — unchanged ergonomics for the ~114 existing String call sites.
    public init(
        image: ModalImage? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        primary: String,
        secondary: String? = nil,
        closeOnTapOverlay: Bool = false,
        showCloseButton: Bool = false,
        style: ModalStyle = .standard
    ) {
        self.init(
            image: image,
            title: title.map(AttributedString.init),
            subtitle: subtitle.map(AttributedString.init),
            primary: primary,
            secondary: secondary,
            closeOnTapOverlay: closeOnTapOverlay,
            showCloseButton: showCloseButton,
            style: style
        )
    }

    /// Rich path — title/subtitle are NOT defaulted, so `AlertDialog(primary:)` can only
    /// resolve to the String init above (kills the all-text-omitted overload ambiguity).
    /// `style` IS defaulted in both, and appended last, so no existing argument list changes.
    public init(
        image: ModalImage? = nil,
        title: AttributedString?,
        subtitle: AttributedString?,
        primary: String,
        secondary: String? = nil,
        closeOnTapOverlay: Bool = false,
        showCloseButton: Bool = false,
        style: ModalStyle = .standard
    ) {
        self.image = image
        self.title = title
        self.subtitle = subtitle
        self.primary = primary
        self.secondary = secondary
        self.closeOnTapOverlay = closeOnTapOverlay
        self.showCloseButton = showCloseButton
        self.style = style
    }
}
