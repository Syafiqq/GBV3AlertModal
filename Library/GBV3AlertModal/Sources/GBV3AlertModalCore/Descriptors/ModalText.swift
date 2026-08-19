import Foundation

/// Platform-neutral operations on descriptor text payloads.
public enum ModalText {
    /// Preserves the descriptor's characters for structural resolution without interpreting any
    /// renderer-specific attribute scope.
    public static func plainText(_ text: AttributedString?) -> String? {
        text.map { String($0.characters) }
    }
}
