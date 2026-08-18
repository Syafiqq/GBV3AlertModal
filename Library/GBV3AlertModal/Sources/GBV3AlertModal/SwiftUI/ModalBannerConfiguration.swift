import Foundation

/// SwiftUI-native layout options for modal banner artwork.
///
/// The image's intrinsic aspect ratio always drives its shape. SwiftUI proposes the available
/// width and the image scales to fit; `maximumHeight` is an optional safety cap for unusually tall
/// artwork. Callers do not need to repeat pixel dimensions or an aspect ratio already carried by
/// the image.
public struct ModalBannerConfiguration: Sendable, Equatable {
    public var maximumHeight: CGFloat?

    public init(maximumHeight: CGFloat? = nil) {
        self.maximumHeight = maximumHeight
    }
}
