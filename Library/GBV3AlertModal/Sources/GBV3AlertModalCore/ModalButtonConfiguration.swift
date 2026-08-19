/// Renderer-neutral selectors for a modal action's visual treatment.
///
/// Each renderer registers its platform-native implementation for these cases. Descriptors and
/// view models therefore select a look without importing SwiftUI or UIKit.
public enum ModalButtonStyle: Sendable, Hashable {
    case capsule
    case capsuleOutlined
    case plain
    case oblique
}

/// The layout direction of the primary and secondary actions.
public enum ModalButtonOrientation: Sendable, Hashable {
    case vertical
    case horizontal
}
