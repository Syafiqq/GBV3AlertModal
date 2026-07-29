import Foundation
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
        //
        // SwiftUI-scoped color/font keys are deliberately NOT checked: they do not bridge to
        // NSAttributedString at all, so treating them as "styled" would yield an attributed
        // string stripped of styling, which the resolver renders as-is — worse than plain,
        // which at least receives the resolver's default styling. The SwiftUI renderer never
        // calls `split`; it consumes the descriptor's `AttributedString` directly.
        let isPlain = text.runs.allSatisfy { run in
            run[AttributeScopes.UIKitAttributes.ForegroundColorAttribute.self] == nil
                && run[AttributeScopes.UIKitAttributes.FontAttribute.self] == nil
                && run[AttributeScopes.FoundationAttributes.LinkAttribute.self] == nil
        }
        if isPlain { return (String(text.characters), nil) }
        return (nil, NSAttributedString(text))
    }
}
