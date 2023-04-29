//
// Created by engineering on 29/4/23.
//

import Foundation

public extension UIEdgeInsets {
    func copy(
            top: CGFloat? = nil,
            left: CGFloat? = nil,
            bottom: CGFloat? = nil,
            right: CGFloat? = nil
    ) -> Self {
        Self(
                top: top ?? self.top,
                left: left ?? self.left,
                bottom: bottom ?? self.bottom,
                right: right ?? self.right
        )
    }
}
