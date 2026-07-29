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
        // SwiftUI-scoped color/font keys are deliberately NOT checked: they DO bridge onto the
        // resulting NSAttributedString, but under `SwiftUI.*` keys that UIKit does not render
        // (ambient `.foregroundColor =`/`.font =` bind to this same SwiftUI scope, even in files
        // with no SwiftUI import). Treating such a run as "styled" would yield an attributed
        // string UILabel renders with NO styling at all, which the resolver renders as-is —
        // worse than plain, which at least receives the resolver's default styling.
        //
        // `SwiftUIAlertModal` DOES call `split` now (via `AlertHolder.make`), so it makes the
        // SAME none/plain/attributed/custom decision UIKit does. But it deliberately does NOT
        // render this function's plain `String` payload for the `.plain` case — that would
        // silently strip exactly the SwiftUI-scoped styling described above. It renders the
        // descriptor's `AttributedString` directly instead, and only reads this function's
        // `NSAttributedString` output for the `.attributed` case, where "render as-is" is the
        // UIKit behaviour actually being mirrored. See `SwiftUIAlertModal.subtitleView`.
        let isPlain = text.runs.allSatisfy { run in
            run[AttributeScopes.UIKitAttributes.ForegroundColorAttribute.self] == nil
                && run[AttributeScopes.UIKitAttributes.FontAttribute.self] == nil
                && run[AttributeScopes.FoundationAttributes.LinkAttribute.self] == nil
        }
        if isPlain { return (String(text.characters), nil) }
        return (nil, NSAttributedString(text))
    }
}
