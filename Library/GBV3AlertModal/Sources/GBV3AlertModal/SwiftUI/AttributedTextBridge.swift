import CoreText
import SwiftUI
import UIKit

/// **Re-scopes UIKit-authored styling onto SwiftUI's scope, so a bridged `NSAttributedString`
/// actually renders.**
///
/// The mirror image of `ModalText.convertingSwiftUIColorScope`, and the same class of bug pointing
/// the other way. `AttributedString(someNSAttributedString)` preserves the run attributes under
/// UIKit's scope (`NSColor`, `UIFont`); SwiftUI's `Text` reads its OWN scope, so the styling is
/// carried all the way to the draw call and then ignored. The card renders the right words with none
/// of the emphasis the caller asked for.
///
/// This was a declared catalog divergence (`attributedRuns`: "the bold/colour RUNS are UIKit-scoped,
/// so SwiftUI draws them unstyled") — visible in the gallery, but a real loss of caller intent on the
/// one path where the descriptor API explicitly promises styled text.
///
/// **Both directions convert here, unlike in `ModalText`.** There the asymmetry was forced: SwiftUI
/// colour converts to UIKit but `Font -> UIFont` has no inverse. Going UIKit → SwiftUI both exist —
/// `Color(uiColor:)` and `Font(_: CTFont)`, with `UIFont` toll-free bridged to `CTFont` — so a
/// bold/colour run survives intact.
enum AttributedTextBridge {

    /// An `NSAttributedString` as SwiftUI will actually draw it.
    static func swiftUIRenderable(_ text: NSAttributedString) -> AttributedString {
        var converted = AttributedString(text)

        for run in converted.runs {
            let range = run.range

            // COLOUR — only when SwiftUI's own scope is empty, so a caller who set both is not
            // second-guessed.
            if converted[range].swiftUI.foregroundColor == nil,
               let uiColor = converted[range].uiKit.foregroundColor {
                converted[range].swiftUI.foregroundColor = Color(uiColor: uiColor)
            }

            // FONT — this is what carries BOLD. `UIFont` bridges to `CTFont`, which `Font` accepts,
            // so the concrete face and size survive rather than being approximated by a weight.
            if converted[range].swiftUI.font == nil,
               let uiFont = converted[range].uiKit.font {
                converted[range].swiftUI.font = Font(uiFont as CTFont)
            }
        }

        return converted
    }
}
