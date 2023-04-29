//
// Created by engineering on 29/4/23.
//

import Foundation

struct UIMinMaxEdgeInsets {
    static var zero: Self {
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

    func copy(
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
