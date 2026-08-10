import Foundation

/// A confirm dialog whose primary button can enter a LOADING state — the app's
/// `worksheet-generating-abused` shape (`V1WorksheetViewController`, ~10 near-identical call sites):
/// "Generating Worksheet / … Continue?" with Continue + Cancel, where tapping Continue kicks off
/// generation and the button has to show progress until the request returns.
///
/// **Why this is not an `AlertDialog`.** `AlertDialog` has no way to say "the primary button is
/// busy". `AlertModalScaffold` already supports it (`isPrimaryLoading` swaps the label for a
/// `ProgressView` and disables the button), but nothing could REACH that parameter through a
/// descriptor — `SwiftUIAlertModal` hardcodes `isPrimaryLoading` to the caller's own view state,
/// which the executor path has no access to. This descriptor is that missing input.
///
/// The state is a FIELD, not a separate descriptor kind, so a caller flips it with the executor's
/// existing `update(_:to:)` — present with `isLoading: false`, then update to `isLoading: true` when
/// the tap fires. The presentation is rebuilt in place, which is exactly what `update` is for.
public struct LoadingDialog: ModalDescriptor {
    public enum Result: Sendable, Equatable {
        case confirmed
        case cancelled
        case dismissed
    }
    public static var dismissedResult: Result { .dismissed }

    public var title: AttributedString?
    public var subtitle: AttributedString?
    public var primary: String
    public var secondary: String?
    /// `true` → the primary button renders a spinner instead of its label and is disabled.
    public var isLoading: Bool
    public var closeOnTapOverlay: Bool
    public var showCloseButton: Bool
    public var style: ModalStyle

    public init(
        title: AttributedString? = nil,
        subtitle: AttributedString? = nil,
        primary: String,
        secondary: String? = nil,
        isLoading: Bool = false,
        closeOnTapOverlay: Bool = false,
        showCloseButton: Bool = false,
        style: ModalStyle = .standard
    ) {
        self.title = title
        self.subtitle = subtitle
        self.primary = primary
        self.secondary = secondary
        self.isLoading = isLoading
        self.closeOnTapOverlay = closeOnTapOverlay
        self.showCloseButton = showCloseButton
        self.style = style
    }
}
