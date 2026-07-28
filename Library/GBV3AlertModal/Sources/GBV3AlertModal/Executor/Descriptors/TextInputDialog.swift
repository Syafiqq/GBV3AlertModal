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

    public init(
        title: String? = nil,
        placeholder: String = "",
        initialText: String = "",
        primary: String,
        secondary: String? = nil
    ) {
        self.title = title.map(AttributedString.init)
        self.placeholder = placeholder
        self.initialText = initialText
        self.primary = primary
        self.secondary = secondary
    }
}
