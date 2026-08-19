import SwiftUI

/// A vertical scroll view that hugs short content and yields under pressure without reserving an
/// arbitrary minimum height.
struct ModalMeasuredScrollView<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var idealHeight: CGFloat?

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                content()
            }
                .environment(\.modalUsesExternalContentScroll, true)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ModalMeasuredContentHeightKey.self,
                            value: proxy.size.height
                        )
                    }
                }
        }
        // A short title/subtitle group keeps its natural height. Under pressure this flexible frame
        // accepts less than the ideal and the remainder stays reachable through the scroll view.
        .frame(maxHeight: idealHeight)
        .onPreferenceChange(ModalMeasuredContentHeightKey.self) { height in
            if height > 0, idealHeight != height {
                idealHeight = height
            }
        }
    }
}

private struct ModalMeasuredContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
