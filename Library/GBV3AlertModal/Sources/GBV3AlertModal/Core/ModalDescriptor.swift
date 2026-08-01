import Foundation

/// A pure, UIKit-free description of *what* to present. The renderer maps it to a UIKit view.
public protocol ModalDescriptor: Sendable {
    associatedtype Result: Sendable
    /// The result the renderer resolves with when the modal is torn down without a user action.
    static var dismissedResult: Result { get }
}

/// An asset-catalog image reference (a name, not a `UIImage`) so descriptors stay `Sendable`.
public struct ModalImage: Sendable, Equatable {
    public let assetName: String

    /// **Which bundle the asset lives in, by identifier — `nil` means the main bundle.**
    ///
    /// An identifier rather than a `Bundle`, because `Bundle` is not `Sendable` and this type must
    /// be: descriptors cross actor boundaries by design.
    ///
    /// Two things needed this. A modular app whose artwork lives in a framework or an SPM resource
    /// bundle could not name it at all — `UIImage(named:)` and `Image(_:)` both default to the main
    /// bundle. And it is what makes a banner COMPARABLE in the differential harness: the library test
    /// target owns no main-bundle assets, so `bannerIsUnresolvableInTheLibraryBundle` excluded every
    /// banner from the one gate that measures the two renderers against each other.
    public let bundleIdentifier: String?

    public init(_ assetName: String, bundleIdentifier: String? = nil) {
        self.assetName = assetName
        self.bundleIdentifier = bundleIdentifier
    }

    /// The bundle to load from — the named one when it resolves, else the main bundle. A wrong or
    /// missing identifier degrades to today's behaviour rather than to no image.
    public var bundle: Bundle? {
        guard let bundleIdentifier else { return nil }
        return Bundle(identifier: bundleIdentifier)
    }
}
