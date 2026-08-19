import Foundation

/// The satisfaction-row dialog — the app's `SatisfactionLevelDialogView`: a row of pick-one options
/// with a VALIDATION GATE, i.e. the primary button stays disabled until something is selected.
///
/// It is the exemplar for the whole custom-content seam, because its result
/// (`.submitted(index:)`) is a value the VIEW owns and no `(ActionType) -> Result` route registered
/// before presentation could ever produce — the same gap `TextInputDialog.submitted(String)` closed
/// for text. See `SwiftUIModalRenderer.register(_:view:)`.
///
/// Descriptor stays pure (D1): it carries option LABELS and SF Symbol NAMES; the row, the selection
/// state and the enable/disable gate all live in `SatisfactionModalView` on the renderer.
public struct SatisfactionDialog: ModalDescriptor {

    /// One selectable option. `symbolName` is an SF Symbol name — a NAME, like `ModalImage`, so the
    /// descriptor never carries an image.
    public struct Option: Sendable, Equatable, Identifiable {
        public let id: String
        public let symbolName: String
        public let label: String

        public init(id: String, symbolName: String, label: String) {
            self.id = id
            self.symbolName = symbolName
            self.label = label
        }
    }

    /// `index` into `options` — the value the view holds and hands to the gate at tap time.
    public enum Result: Sendable, Equatable {
        case submitted(index: Int)
        case dismissed
    }
    public static var dismissedResult: Result { .dismissed }

    public var title: AttributedString?
    public var options: [Option]
    public var primary: String
    public var closeOnTapOverlay: Bool
    public var style: ModalStyle

    public init(
        title: AttributedString? = nil,
        options: [Option],
        primary: String,
        closeOnTapOverlay: Bool = true,
        style: ModalStyle = .standard
    ) {
        self.title = title
        self.options = options
        self.primary = primary
        self.closeOnTapOverlay = closeOnTapOverlay
        self.style = style
    }
}
