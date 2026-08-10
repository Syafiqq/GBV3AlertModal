import SwiftUI
import UIKit

/// **A font a caller states in SwiftUI's vocabulary, that the library can also MEASURE.**
///
/// This is the answer to the open question §3b of the backend-independence spec left for Pass 3.
/// The problem, stated there: `Properties.titleFont` is a `UIFont`, and `ModalTokens.init(from:)`
/// derives both a `Font` to draw with and keeps the `UIFont` to measure with. A SwiftUI-native
/// configuration hands the library a `Font`, which is opaque — there is no `Font -> UIFont`
/// direction, the bridge runs `UIFont -> Font` only — so the library could render the caller's font
/// and not measure it. Keeping a "twin" does not help; there is nothing to keep a twin *of*.
///
/// **The resolution is to make the UIFont the stored value and the `Font` the derived one**, through
/// the bridge that already exists and is already pinned (`Font(_: UIFont)`). Then "the font that is
/// drawn" and "the font that is measured" are not two values that agree — they are one value, and
/// the class of bug where they drift cannot be written.
///
/// That bug is not hypothetical. `ModalTokens` used to carry `titleFont: Font` and
/// `titleUIFont: UIFont` as separate stored properties: `init(from: Properties)` set both from the
/// one `Properties.titleFont` and could not drift, but `ModalTokens.standard` stated the `Font`
/// and let the `UIFont` keep its default — two literals, typed twice, agreeing by hand.
/// `test_theStandardTitleFontAndItsMeasurementFallback_agree` existed to guard that coincidence.
/// There is no coincidence left to guard.
///
/// **Why measurement stays on `UIFont` at all** is §3b's other half, and it is measured rather than
/// assumed: CoreText was tried as the UIKit-free alternative and REJECTED. Single line heights are
/// bit-identical, but multi-line wrapping is not and cannot be — `boundingRect` runs TextKit's
/// line-fragment layout and `CTFramesetter` runs CoreText's own typesetter, and they break lines
/// differently (−2.16pt / +0.92pt against a 0.5pt tolerance, with CoreText *under*-measuring at
/// floor scale, the one direction that reintroduces clipping). Behaviour parity outranks import
/// count.
///
/// **The caller never names a UIKit type**, which is the actual §5 finish line: `.system(size:weight:)`
/// and `.custom(_:size:)` mirror `Font`'s own factories, so a call site reads the same either way.
/// `Sendable` because `ModalTokens` is, and `UIFont` — being immutable — already conforms.
public struct ModalFont: Equatable, Sendable {

    /// Our own enum rather than `Font.Weight` or `UIFont.Weight`, and both halves of that are forced.
    ///
    /// `Font.Weight` is a frozen struct of static members with no public accessor — it cannot be
    /// switched over, so there is no way to map it to anything. `UIFont.Weight` would make the caller
    /// name a UIKit type, which is exactly what this type exists to avoid. So: nine cases, mapped
    /// once, in one direction.
    public enum Weight: Equatable, Sendable, CaseIterable {
        case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black

        var uiWeight: UIFont.Weight {
            switch self {
            case .ultraLight: return .ultraLight
            case .thin: return .thin
            case .light: return .light
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            case .heavy: return .heavy
            case .black: return .black
            }
        }
    }

    /// **The stored value.** Internal: the library measures with it (`ModalLayout`), and no caller
    /// states or reads it — the same standing `ModalTokens.titleUIFont` had, for the same reason.
    let uiFont: UIFont

    /// What SwiftUI draws, derived — never stored alongside `uiFont`, so the two cannot be different
    /// fonts. `Font(_: UIFont)` is the platform's own bridge and the one `ModalTokens.init(from:)`
    /// has always used.
    public var font: Font { Font(uiFont) }

    /// The `Properties` path: a caller who already stated a `UIFont` keeps stating one, and it
    /// arrives here unchanged. Internal, because a SwiftUI caller has the two factories below.
    init(_ uiFont: UIFont) {
        self.uiFont = uiFont
    }

    /// The system font, as `Font.system(size:weight:)` spells it.
    public static func system(size: CGFloat, weight: Weight = .regular) -> ModalFont {
        ModalFont(.systemFont(ofSize: size, weight: weight.uiWeight))
    }

    /// A named font, as `Font.custom(_:size:)` spells it — fixed size, no Dynamic Type scaling,
    /// matching both `Font.custom(_:size:)` and `UIFont(name:size:)`.
    ///
    /// **The fallback is the point, not an afterthought.** `UIFont(name:size:)` returns `nil` for a
    /// font that is not installed, while `Font.custom` silently falls back to the system font and
    /// draws something. Falling back to the same system font here is what keeps the measurement
    /// honest in that case: a missing font must MEASURE whatever SwiftUI actually DRAWS, and the
    /// alternative — refusing to measure, or measuring the intended-but-absent face — reintroduces
    /// exactly the drawn-one-thing / measured-another bug this type exists to make unwritable.
    ///
    /// Weightless on purpose: a named face carries its own weight (`"SHSans-Bold"`), and applying a
    /// second weight on top is how a bold font gets asked to be bold twice.
    public static func custom(_ name: String, size: CGFloat) -> ModalFont {
        ModalFont(UIFont(name: name, size: size) ?? .systemFont(ofSize: size))
    }
}
