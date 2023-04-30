import Foundation
import UIKit

extension CALayer {
    /// https://stackoverflow.com/questions/34269399/how-to-control-shadow-spread-and-blur
    func applySketchShadow(
            color: CGColor? = UIColor.black.cgColor,
            alpha: Float = 0.5,
            x: CGFloat = 0,
            y: CGFloat = 2,
            blur: CGFloat = 4,
            spread: CGFloat = 0
    ) {
        shadowColor = color
        shadowOpacity = alpha
        shadowOffset = CGSize(width: x, height: y)
        shadowRadius = blur / 2.0
        if spread == 0 {
            shadowPath = nil
        } else {
            let dx = -spread // swiftlint:disable:this variable_name
            let rect = bounds.insetBy(dx: dx, dy: dx)
            shadowPath = UIBezierPath(rect: rect).cgPath
        }
    }

    func removeSketchShadow() {
        shadowColor = nil
        shadowOpacity = .zero
        shadowOffset = .zero
        shadowRadius = .zero
        shadowPath = nil
    }
}
