import Foundation

/// Same content shape as `AlertDialog`; the distinct type IS the popup STYLE identity (spec D8 —
/// the renderer registers it with the popup `Properties`: heavier fonts, navy title, wider padding).
/// Reuses `AlertDialog.Result` so callers get one result vocabulary across the standard family.
///
/// **RETAINED FOR SOURCE COMPATIBILITY — `ModalStyle` is now the extensible path.** Type-per-style
/// does not scale: the app has five presets plus per-entry overrides, so it would need
/// `BadgeDialog`, `PermissionDialog`, `StreakDialog`, `ObliqueRedDialog`… and the type count would
/// track the DESIGN SYSTEM rather than the content shape. `AlertDialog(…, style: .popup)` is the
/// equivalent of this type and reaches every OTHER preset the same way. Nothing here is deprecated
/// or removed — every existing `PopupDialog` call site keeps working unchanged, and its `style` is
/// pinned to `.popup`, so both spellings resolve through the SAME style→`Properties` map.
public struct PopupDialog: ModalDescriptor, StandardAlertContent {
    public typealias Result = AlertDialog.Result
    public static var dismissedResult: Result { .dismissed }

    /// Fixed, not an init parameter: this type's whole purpose IS the popup style. Restyling is
    /// what `AlertDialog.style` is for.
    public let style = ModalStyle.popup

    public var image: ModalImage?
    public var title: AttributedString?
    public var subtitle: AttributedString?
    public var primary: String
    public var secondary: String?
    public var closeOnTapOverlay: Bool
    public var showCloseButton: Bool

    /// Plain path — String ergonomics (lifts to AttributedString).
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

    /// Rich path — title/subtitle NOT defaulted (the overload disambiguator, as in AlertDialog).
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
