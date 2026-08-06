import Foundation

/// A pure, UIKit-free description of *what* to present. The renderer maps it to a UIKit view.
public protocol ModalDescriptor: Sendable {
    associatedtype Result: Sendable
    /// The result the renderer resolves with when the modal is torn down without a user action.
    static var dismissedResult: Result { get }
}

/// **A descriptor that carries PRESENTATION state, not just content and style.**
///
/// The gallery's two button-state shapes were `notRenderable` because the UIKit twins call
/// `changePrimaryActionEnableState` / `changeSecondaryActionEnableState` on the modal AFTER
/// `init(properties:holder:)` has built the view graph, and a descriptor had nowhere to say it.
///
/// **No new channel was needed.** `ModalRenderer.update(_:to:)` already rebuilds a live
/// presentation on both backends, so a flag ON the descriptor is a flag a caller can change
/// mid-presentation: `executor.update(token, to: dialog.disablingPrimary())`. That is exactly the
/// route `LoadingDialog.isLoading` already documents for its own presentation state — this
/// generalises the pattern rather than inventing one.
///
/// It does cost the claim that "a descriptor carries content and style, not presentation state."
/// That claim was already false when `LoadingDialog` shipped; it is now false on purpose.
public protocol ButtonEnablement {
    /// `false` → the primary button is drawn but not tappable. A descriptor with NO primary button
    /// (`primary == nil`) is a different thing entirely, and this flag says nothing about it.
    var primaryEnabled: Bool { get }
    var secondaryEnabled: Bool { get }
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
