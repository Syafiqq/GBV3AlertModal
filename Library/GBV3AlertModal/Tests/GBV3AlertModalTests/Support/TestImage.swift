import UIKit

/// Test-only image fixtures. Kept separate from `GeniePresets` so both the resolver unit
/// tests (Layer A) and the snapshot fixtures (Layer C) can share a single, deterministic,
/// non-zero-size image without duplicating the drawing code.
extension UIImage {
    /// A solid-color, non-zero-size image for tests that need a "real" banner — as opposed
    /// to `UIImage()` (a zero-size, degenerate image used to characterize the "no banner"
    /// collapse behavior).
    static func gbv3TestSolid(
        width: CGFloat,
        height: CGFloat,
        color: UIColor = .systemTeal
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
