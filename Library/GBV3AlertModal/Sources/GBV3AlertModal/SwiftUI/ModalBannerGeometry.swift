import SwiftUI

/// Applies the UIKit banner SLOT geometry (`Properties.bannerRatio` / `bannerFixedHeight` /
/// `bannerMaxHeight`, resolved by `ModalTokens.bannerLayout`) to a SwiftUI banner image.
///
/// Before this existed the SwiftUI banner was `scaledToFit()` capped at `bannerMaxHeight` and
/// nothing else: `bannerRatio` and `bannerFixedHeight` were carried in `Properties`, read by the
/// UIKit view graph, and silently ignored on this side — a divergence on the 13 catalog shapes that
/// set them, invisible only because no test could see it.
///
/// Each constraint is applied ONLY when `Properties` supplies it, so a nil field adds no frame at
/// all — mirroring UIKit, which installs no constraint. (Relying on `.frame(height: nil)` /
/// `.frame(maxHeight: nil)` being a no-op would be an assumption about SwiftUI's flexible-frame
/// behaviour; branching states the intent instead.)
///
/// Ordering matches the UIKit constraint set: the ratio shapes the slot, the fixed height pins it,
/// the cap trims it — so the cap wins over the pin exactly as priority 751 wins over 251.
///
/// Internal, and a `ViewModifier` rather than a `View` extension on purpose: an extension on
/// `SwiftUI.View` is an extension on a type this library does not own, and the same
/// namespace-pollution argument that keeps `Color(hex:)` internal applies to it.
struct ModalBannerGeometry: ViewModifier {
    let layout: ModalTokens.BannerLayout

    func body(content: Content) -> some View {
        cap(pin(shape(content)))
    }

    /// UIKit: `ivBanner.width == ivBanner.height * bannerRatio` with `contentMode = .scaleAspectFit`
    /// — a ratio-shaped slot with the picture letterboxed inside it. `.aspectRatio(_:contentMode:)`
    /// takes width/height, the same convention `bannerRatio` uses, and `.fit` is `scaleAspectFit`.
    @ViewBuilder
    private func shape<V: View>(_ view: V) -> some View {
        if let aspectRatio = layout.aspectRatio {
            view.aspectRatio(aspectRatio, contentMode: .fit)
        } else {
            view
        }
    }

    @ViewBuilder
    private func pin<V: View>(_ view: V) -> some View {
        if let height = layout.height {
            view.frame(height: height)
        } else {
            view
        }
    }

    @ViewBuilder
    private func cap<V: View>(_ view: V) -> some View {
        if let maxHeight = layout.maxHeight {
            view.frame(maxHeight: maxHeight)
        } else {
            view
        }
    }
}
