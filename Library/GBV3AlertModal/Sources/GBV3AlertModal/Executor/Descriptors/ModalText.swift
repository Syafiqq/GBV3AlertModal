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
        let scoped = convertingSwiftUIColorScope(text)
        // "Plain" means carrying none of the whitelisted CONCRETE styling attributes
        // (foreground color, font, link). Presentation-intent attributes (e.g. from
        // `AttributedString(markdown:)` parsing unmarked text) are out of the whitelisted
        // subgrammar and don't bridge reliably to UIKit, so intent-only runs stay plain.
        //
        // SwiftUI-scoped COLOR is converted above rather than ignored, so it reaches this check as a
        // UIKit-scoped attribute and renders. SwiftUI-scoped FONT still cannot be — see the note on
        // `convertingSwiftUIColorScope` — so a run styled only with a SwiftUI font still reads as
        // plain here and receives the resolver's default styling, which beats an attributed string
        // UIKit would draw with no styling at all.
        //
        // `SwiftUIAlertModal` DOES call `split` now (via `AlertHolder.make`), so it makes the
        // SAME none/plain/attributed/custom decision UIKit does. But it deliberately does NOT
        // render this function's plain `String` payload for the `.plain` case — that would
        // silently strip exactly the SwiftUI-scoped font described above. It renders the
        // descriptor's `AttributedString` directly instead, and only reads this function's
        // `NSAttributedString` output for the `.attributed` case, where "render as-is" is the
        // UIKit behaviour actually being mirrored. See `SwiftUIAlertModal.subtitleView`.
        let isPlain = scoped.runs.allSatisfy { run in
            let colour = run[AttributeScopes.UIKitAttributes.ForegroundColorAttribute.self]
            let font = run[AttributeScopes.UIKitAttributes.FontAttribute.self]
            let link = run[AttributeScopes.FoundationAttributes.LinkAttribute.self]
            return colour == nil && font == nil && link == nil
        }
        if isPlain {
            return (String(scoped.characters), nil)
        }
        return (nil, NSAttributedString(scoped))
    }

    /// **Re-scopes SwiftUI-authored colour onto UIKit's scope, so caller intent actually renders.**
    ///
    /// The trap this exists for: `a.foregroundColor = .red` — the natural way to write it, and the
    /// AMBIENT form, with no SwiftUI import anywhere in sight — binds to SwiftUI's attribute scope.
    /// Bridged to `NSAttributedString` it survives under a `SwiftUI.ForegroundColor` key that
    /// `UILabel` does not read, so the text draws completely unstyled. Established empirically, and
    /// it had already pinned itself into a test that asserted `.attributed` while the render was
    /// plain.
    ///
    /// The previous behaviour was to ignore SwiftUI-scoped attributes entirely, which classified
    /// such a run as plain so the resolver's default styling applied — better than unstyled, but it
    /// silently discarded what the caller asked for. Converting is what they actually meant.
    ///
    /// **COLOUR ONLY, and the asymmetry is not an oversight.** `UIColor(_: Color)` exists (iOS 14+),
    /// so SwiftUI colour converts exactly. There is no `Font -> UIFont` direction — the bridge runs
    /// `UIFont -> Font` via `CTFont` and not back — which is the same wall that makes
    /// `ModalTokens.titleUIFont` a hand-carried measurement twin. A SwiftUI-scoped FONT therefore
    /// still degrades to plain, and that is the honest outcome rather than a guess at a point size.
    ///
    /// Runs already carrying a UIKit-scoped colour are left alone: an explicit `.uiKit.` scope is a
    /// stronger statement than the ambient one and must not be overwritten by it.
    private static func convertingSwiftUIColorScope(_ text: AttributedString) -> AttributedString {
        var converted = text
        var didConvert = false
        for run in text.runs {
            guard let swiftUIColor = run[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self],
                  run[AttributeScopes.UIKitAttributes.ForegroundColorAttribute.self] == nil else {
                continue
            }
            converted[run.range].uiKit.foregroundColor = UIColor(swiftUIColor)
            didConvert = true
        }
        // Untouched strings return the ORIGINAL value, not a rebuilt copy — the overwhelmingly
        // common case is a run with no SwiftUI scope at all, and it should cost nothing.
        return didConvert ? converted : text
    }
}
