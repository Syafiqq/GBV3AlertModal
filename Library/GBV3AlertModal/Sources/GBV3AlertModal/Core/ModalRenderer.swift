import Foundation

@MainActor
public protocol ModalRenderer: AnyObject {
    func present<D: ModalDescriptor>(_ descriptor: D, id: ModalID, resolve: @escaping (D.Result) -> Void)
    func update<D: ModalDescriptor>(_ id: ModalID, to descriptor: D)
    func dismiss(_ id: ModalID)
    /// Toggle a live presentation's visibility WITHOUT tearing it down or resolving its token — used
    /// by a coordinator to hide the modal while its owning screen is covered, and restore it on return.
    func setHidden(_ id: ModalID, _ isHidden: Bool)
}
