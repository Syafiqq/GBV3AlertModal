import UIKit

/// `ModalImage.pointSize` lives HERE rather than alongside the type in `Core/ModalDescriptor.swift`
/// on purpose: `Core/` is the framework-neutral executor contract — descriptors, executor, token,
/// coordinator, renderer protocol — and `CorePurityTests.testCoreRegionImportsNoUIFramework` enforces
/// that nothing in it imports UIKit or SwiftUI, so a future module split stays a manifest edit rather
/// than a refactor. `ModalImage` itself is defined in `Core/` and stays `Sendable`/UIKit-free there;
/// this extension adds a UIKit-backed computed property from OUTSIDE that region, the same way
/// `Extensions/UIButton+Rounded.swift` and friends extend other types without pulling UIKit into
/// `Core/`.
public extension ModalImage {
    /// **The artwork's POINT size — the operand `.resizable()` discards.**
    ///
    /// UIKit's banner slot is sized by `ivBanner`'s intrinsic content size, which is this. SwiftUI's
    /// `Image(_:bundle:).resizable()` throws it away before layout sees it, so the SwiftUI backend
    /// has to look it up to reach the same answer (`ModalTokens.bannerGeometry`).
    ///
    /// POINTS, not pixels: a 960x681 pixel asset at 3x is 320x227 points, and it is the point size
    /// the constraint sees. `UIImage` reports points, so this is already correct — but note that a
    /// preset ratio spelled `960.0/681.0` is the PIXEL ratio of that same asset.
    ///
    /// `.zero` when the asset does not resolve, which collapses the slot exactly as a zero-size
    /// `UIImage` does on the UIKit side.
    var pointSize: CGSize {
        UIImage(named: assetName, in: bundle, compatibleWith: nil)?.size ?? .zero
    }
}
