import SwiftUI

/// A bespoke SwiftUI dialog mirroring the real app's `SatisfactionLevelDialogView`: it reuses
/// the same scrim + centered white rounded-card chrome as `SwiftUIAlertModal`, but the content
/// is custom composition (a 3-option picker), not a config-driven render. This is the
/// validation-gate pattern: the primary button stays disabled until a selection is made.
/// Like `SwiftUIAlertModal`, it never dismisses itself — the caller reacts to `onAction`.
struct SatisfactionDemoView: View {
    enum Result: Equatable {
        case submitted(index: Int)
        case dismissed
    }

    var scrim: Color = Color.black.opacity(0.6)
    let options: [(symbol: String, label: String)] = [
        ("hand.thumbsdown", "Not helpful"),
        ("hand.thumbsup", "Quite helpful"),
        ("star.fill", "Very helpful"),
    ]
    let onAction: (Result) -> Void

    @State private var selectedIndex: Int?

    var body: some View {
        ZStack {
            scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onAction(.dismissed) }

            card
                .frame(maxWidth: 300)
                .padding(24)
        }
    }

    private var card: some View {
        VStack(spacing: 20) {
            Text("How helpful was this?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                ForEach(options.indices, id: \.self) { index in
                    optionButton(index)
                }
            }

            Button {
                if let selectedIndex {
                    onAction(.submitted(index: selectedIndex))
                }
            } label: {
                Text("Submit")
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .disabled(selectedIndex == nil)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? .accentColor : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
