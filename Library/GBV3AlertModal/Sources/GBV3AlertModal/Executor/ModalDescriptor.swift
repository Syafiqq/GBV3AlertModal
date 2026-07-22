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
    public init(_ assetName: String) { self.assetName = assetName }
}
