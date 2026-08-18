import SwiftUI

/// A value-semantic font description owned by the SwiftUI backend.
public struct ModalFont: Sendable, Equatable {
    public enum Family: Sendable, Equatable {
        case system
        case custom(String)
    }

    public enum Weight: Sendable, Equatable, CaseIterable {
        case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black
    }

    public enum TextStyle: Sendable, Equatable, CaseIterable {
        case largeTitle, title, title2, title3, headline, subheadline, body, callout, footnote, caption, caption2
    }

    public enum ScalingPolicy: Sendable, Equatable {
        case fixed
        case relative(to: TextStyle)
    }

    public let family: Family
    public let size: CGFloat
    public let weight: Weight
    public let scalingPolicy: ScalingPolicy

    public init(
        family: Family,
        size: CGFloat,
        weight: Weight = .regular,
        scalingPolicy: ScalingPolicy = .fixed
    ) {
        self.family = family
        self.size = size
        self.weight = weight
        self.scalingPolicy = scalingPolicy
    }

    public static func system(
        size: CGFloat,
        weight: Weight = .regular,
        scalingPolicy: ScalingPolicy = .fixed
    ) -> ModalFont {
        ModalFont(family: .system, size: size, weight: weight, scalingPolicy: scalingPolicy)
    }

    public static func custom(
        _ name: String,
        size: CGFloat,
        scalingPolicy: ScalingPolicy = .fixed
    ) -> ModalFont {
        ModalFont(family: .custom(name), size: size, scalingPolicy: scalingPolicy)
    }

    public var font: Font {
        switch (family, scalingPolicy) {
        case (.system, .fixed):
            .system(size: size, weight: weight.swiftUIWeight)
        case let (.system, .relative(to: style)):
            .system(style.swiftUITextStyle).weight(weight.swiftUIWeight)
        case let (.custom(name), .fixed):
            .custom(name, fixedSize: size)
        case let (.custom(name), .relative(to: style)):
            .custom(name, size: size, relativeTo: style.swiftUITextStyle)
        }
    }
}

private extension ModalFont.Weight {
    var swiftUIWeight: Font.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}

private extension ModalFont.TextStyle {
    var swiftUITextStyle: Font.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption
        case .caption2: .caption2
        }
    }
}
