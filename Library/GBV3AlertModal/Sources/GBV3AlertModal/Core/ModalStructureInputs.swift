import Foundation

/// **Everything `GBAlertModal.resolve` reads from a configuration — all of it, and nothing else.**
///
/// The spec's §5 assumed a SwiftUI-native config forces a SECOND resolver, and accepted the cost:
/// "this is where 'by construction' stops being true and the gate becomes the only thing holding
/// the two together." That cost turned out to be avoidable, and the measurement is this protocol's
/// whole reason for existing — `resolve` is 70 lines and reads exactly FIVE things from
/// `Properties`:
///
/// | what | how |
/// |---|---|
/// | `primaryActionStyle` | **nil-ness only** |
/// | `secondaryActionStyle` | **nil-ness only** |
/// | `buttonActionOrientation` | the one genuinely UIKit-typed value |
/// | `buttonActionShouldMatchParent` | `Bool?` |
/// | `contentProperty` | four `CGFloat?` |
///
/// Everything else `resolve` decides comes from the `DataHolder`. So both vocabularies can feed ONE
/// resolver, both backends keep deciding identically, and the "by construction" guarantee survives
/// Pass 3 intact.
///
/// **That matters more than it looks.** §6 measured the differential gate to be COMMON-MODE BLIND
/// and already at its structural ceiling: flipping a shared constant passed 517 of 518 tests. Trading
/// a provable guarantee for a net that is known not to catch this class would have been a bad trade
/// at any price, and the price here was five fields.
///
/// **Deliberately not `NSLayoutConstraint.Axis`.** `buttonsAreHorizontal` is a `Bool` because the
/// UIKit enum has exactly two cases and `orientation ?? .vertical` is therefore lossless as
/// "is it horizontal" — and because a UIKit-typed requirement would drag `import UIKit` into
/// `ModalProperties`, the one file whose entire job is not to need it. `resolve` maps the `Bool`
/// back to the axis it must return, since `UIStackView.axis` takes exactly that type.
///
/// **Not a caller-facing type.** Nobody writes a conformance but the two configurations; it exists
/// so `resolve` can take either without either knowing about the other.
public protocol ModalStructureInputs {
    /// Whether a PRIMARY action style is present at all. The resolver requires both this and the
    /// action string before it reports `showsPrimary` — the style's contents are never read here.
    var hasPrimaryActionStyle: Bool { get }
    var hasSecondaryActionStyle: Bool { get }
    /// `false` when no orientation is stated, matching the main-action stack's generated default.
    var buttonsAreHorizontal: Bool { get }
    var buttonsMatchParent: Bool { get }
    var fixedWidthPortrait: CGFloat? { get }
    var maxWidthPortrait: CGFloat? { get }
    var fixedWidthLandscape: CGFloat? { get }
    var maxWidthLandscape: CGFloat? { get }
}
