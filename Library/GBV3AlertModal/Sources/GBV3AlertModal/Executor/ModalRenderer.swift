import UIKit

@MainActor
public protocol ModalRenderer: AnyObject {
    func present<D: ModalDescriptor>(_ descriptor: D, id: ModalID, resolve: @escaping (D.Result) -> Void)
    func update<D: ModalDescriptor>(_ id: ModalID, to descriptor: D)
    func dismiss(_ id: ModalID)
}
