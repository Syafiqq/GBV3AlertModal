import SwiftUI

/// A bespoke SwiftUI dialog mirroring the real app's `SatisfactionLevelDialogView`, now built on the
/// shared `AlertModalScaffold` (spec D1): the scrim + card + Submit-button chrome come from the
/// scaffold; only the body (a 3-option picker) is custom composition. This is the validation-gate
/// pattern — Submit stays disabled until a selection is made. Never dismisses itself; caller reacts
/// to `onAction`. Demonstrates that the UIKit `subtitleCustomView` becomes a native content slot.
struct SatisfactionDemoView: View {
    enum Result: Equatable {
        case submitted(index: Int)
        case dismissed
    }

    let options: [(symbol: String, label: String)] = [
        ("hand.thumbsdown", "Not helpful"),
        ("hand.thumbsup", "Quite helpful"),
        ("star.fill", "Very helpful"),
    ]
    let onAction: (Result) -> Void

    @State private var selectedIndex: Int?

    var body: some View {
        AlertModalScaffold(
            primaryTitle: "Submit",
            primaryEnabled: selectedIndex != nil,
            onPrimary: { if let selectedIndex { onAction(.submitted(index: selectedIndex)) } },
            onOverlayTap: { onAction(.dismissed) }
        ) {
            Text("How helpful was this?")
                .font(ModalTokens.titleFont)
                .foregroundColor(ModalTokens.Palette.titleText)
                .multilineTextAlignment(.center)
                .padding(.bottom, ModalTokens.gapBelowTitle)

            HStack(spacing: 12) {
                ForEach(options.indices, id: \.self) { index in
                    optionButton(index)
                }
            }
            .padding(.bottom, ModalTokens.gapBelowSubtitle)
        }
    }

    private func optionButton(_ index: Int) -> some View {
        let isSelected = selectedIndex == index
        let option = options[index]
        return Button {
            selectedIndex = index
        } label: {
            VStack(spacing: 6) {
                Image(systemName: option.symbol)
                    .font(.title3)
                Text(option.label)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? ModalTokens.Palette.accent.opacity(0.15) : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? ModalTokens.Palette.accent : ModalTokens.Palette.titleText)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
