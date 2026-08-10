import Foundation

/// An input dialog with a single text field (e.g. the app's "rename worksheet"). Stays `Sendable`:
/// the descriptor carries only value config; the renderer's `@MainActor` factory materializes the
/// `UITextField` as the modal's `subtitleCustomView` and reads its text on resolve. The result
/// carries the entered text — the executor equivalent of the UIKit `subtitleCustomView`.
public struct TextInputDialog: ModalDescriptor {
    public enum Result: Sendable, Equatable {
        case submitted(String)
        case dismissed
    }
    public static var dismissedResult: Result { .dismissed }

    public var title: AttributedString?
    public var placeholder: String
    public var initialText: String
    public var primary: String
    public var secondary: String?
    /// Tapping the scrim dismisses. The app's `rename-worksheet` shape sets this (its holder is
    /// built with `closeOnTapOverlay: true`), and without it here the descriptor could not express
    /// that shape. Appended LAST and defaulted, so every existing call site is unchanged.
    public var closeOnTapOverlay: Bool

    public init(
        title: String? = nil,
        placeholder: String = "",
        initialText: String = "",
        primary: String,
        secondary: String? = nil,
        closeOnTapOverlay: Bool = false
    ) {
        self.title = title.map(AttributedString.init)
        self.placeholder = placeholder
        self.initialText = initialText
        self.primary = primary
        self.secondary = secondary
        self.closeOnTapOverlay = closeOnTapOverlay
    }
}
