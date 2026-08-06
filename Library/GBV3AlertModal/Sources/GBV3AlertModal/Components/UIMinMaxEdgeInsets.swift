//
// Created by engineering on 29/4/23.
//

import Foundation

/// `Sendable`: eight `let CGFloat`s and nothing else, so the conformance is trivially safe. It is
/// declared because `ModalTokens` (a `Sendable` value carried across isolation boundaries) now
/// stores one of these VERBATIM rather than collapsing it into two numbers — see
/// `ModalTokens.contentPadding`.
///
/// **NOTHING HERE ENFORCES `max >= min`, on any of the four edges, and that is left alone on
/// purpose.** A caller can construct `left: (32, 16)` and every consumer will believe it. What
/// happens then is not a crash but a quietly inverted layout: UIKit installs the min as a
/// `.required` inequality and the max as a `.low` equality, so an inverted pair makes the `.low`
/// equality unsatisfiable and the padding pins to the min; `ModalTokens.bannerGeometry`'s ceiling
/// would meanwhile be computed from the LARGER min and come out too small.
///
/// It is pre-existing, it is shared with the same absence of a guard on `ContentProperty`'s
/// `fixedWidth`/`maxWidth` pair (`ModalTokens.init(from:)` resolves that one with `min(fixed, max)`
/// rather than rejecting it), and no preset in the app is inverted. A guard is deliberately NOT
/// added: this is a `public` type in a shipping library, so a precondition would turn a latent
/// layout oddity into a crash in a consumer app, and a clamp would silently rewrite a caller's
/// stated intent. Recorded so the next reader knows it was considered rather than missed.
public struct UIMinMaxEdgeInsets: Sendable, Equatable {
    public static var zero: Self {
        Self()
    }

    public let topMin: CGFloat
    public let topMax: CGFloat
    public let leftMin: CGFloat
    public let leftMax: CGFloat
    public let bottomMin: CGFloat
    public let bottomMax: CGFloat
    public let rightMin: CGFloat
    public let rightMax: CGFloat

    public init(
            top: (CGFloat, CGFloat) = (.zero, .zero),
            left: (CGFloat, CGFloat) = (.zero, .zero),
            bottom: (CGFloat, CGFloat) = (.zero, .zero),
            right: (CGFloat, CGFloat) = (.zero, .zero)
    ) {
        topMin = top.0
        topMax = top.1
        leftMin = left.0
        leftMax = left.1
        bottomMin = bottom.0
        bottomMax = bottom.1
        rightMin = right.0
        rightMax = right.1
    }

    public func copy(
            top: (CGFloat, CGFloat)? = nil,
            left: (CGFloat, CGFloat)? = nil,
            bottom: (CGFloat, CGFloat)? = nil,
            right: (CGFloat, CGFloat)? = nil
    ) -> Self {
        Self(
                top: top ?? (topMin, topMax),
                left: left ?? (leftMin, leftMax),
                bottom: bottom ?? (bottomMin, bottomMax),
                right: right ?? (rightMin, rightMax)
        )
    }
}
