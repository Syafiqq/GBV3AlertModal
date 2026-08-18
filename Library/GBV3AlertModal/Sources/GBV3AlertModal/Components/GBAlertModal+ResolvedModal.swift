import Foundation

extension GBAlertModal {
    nonisolated public static func resolve(
        properties: Properties?, holder: DataHolder, isLandscape: Bool
    ) -> ResolvedModal {
        resolveModal(inputs: properties, content: holder, isLandscape: isLandscape)
    }

    nonisolated public static func resolve(
        inputs: (any ModalStructureInputs)?, holder: DataHolder, isLandscape: Bool
    ) -> ResolvedModal {
        resolveModal(inputs: inputs, content: holder, isLandscape: isLandscape)
    }

    nonisolated public static func resolve(
        inputs: (any ModalStructureInputs)?,
        content: any ModalContentInputs,
        isLandscape: Bool
    ) -> ResolvedModal {
        resolveModal(inputs: inputs, content: content, isLandscape: isLandscape)
    }
}
