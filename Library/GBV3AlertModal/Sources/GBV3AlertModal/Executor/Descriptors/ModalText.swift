import Foundation
import SwiftUI
import UIKit

/// Bridges a descriptor `AttributedString` into the legacy `DataHolder`'s plain/attributed
/// split. Styling is contractually limited to bold/color/link (Foundation-bridgeable keys);
/// see the plan's Global Constraints.
public enum ModalText {
    /// `nil` → nothing. Unstyled → plain `String` (resolver applies default styling).
    /// Styled → `NSAttributedString` (resolver renders as-is).
    public static func split(_ text: AttributedString?) -> (plain: String?, attributed: NSAttributedString?) {
        guard let text else { return (nil, nil) }
        // "Plain" means carrying none of the whitelisted CONCRETE styling attributes
        // (foreground color, font, link). Presentation-intent attributes (e.g. from
        // `AttributedString(markdown:)` parsing unmarked text) are out of the whitelisted
        // subgrammar and don't bridge reliably to UIKit, so intent-only runs stay plain.
        // The concrete UIKit- and SwiftUI-scoped color/font keys are distinct
        // `AttributedStringKey` types; call sites may bind `.foregroundColor`/`.font` to
        // either depending on ambient overload resolution, so both are checked.
        let isPlain = text.runs.allSatisfy { run in
            run[AttributeScopes.UIKitAttributes.ForegroundColorAttribute.self] == nil
                && run[AttributeScopes.UIKitAttributes.FontAttribute.self] == nil
                && run[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] == nil
                && run[AttributeScopes.SwiftUIAttributes.FontAttribute.self] == nil
                && run[AttributeScopes.FoundationAttributes.LinkAttribute.self] == nil
        }
        if isPlain { return (String(text.characters), nil) }
        return (nil, NSAttributedString(text))
    }
}
