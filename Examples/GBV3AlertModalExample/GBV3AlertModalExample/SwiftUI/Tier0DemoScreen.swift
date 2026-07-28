import SwiftUI
import GBV3AlertModal

/// Tier 0: a SwiftUI ViewModel drives the EXISTING executor. This screen has NO SwiftUI modal view —
/// it `await`s `executor.presentAndWait(...)` and the real UIKit `GBAlertModal` paints OVER this
/// screen (proven by `Tier0HostingSmokeTests`). The renderer is injected behind the executor, so this
/// exact VM code runs unchanged under a future Tier-1 `SwiftUIModalRenderer` — Tier 0 → Tier 1 is a
/// renderer swap, not a rewrite.
@MainActor
final class Tier0DemoViewModel: ObservableObject {
    @Published var lastResult = "—"
    private let executor: ModalExecutor

    init(executor: ModalExecutor) { self.executor = executor }

    func confirmDelete() async {
        let result = await executor.presentAndWait(
            AlertDialog(title: "Delete draft?",
                        subtitle: "This can't be undone.",
                        primary: "Delete",
                        secondary: "Keep")
        )
        lastResult = "\(result)"
    }

    func showInfo() async {
        let result = await executor.presentAndWait(
            AlertDialog(title: "You're all set",
                        subtitle: "Your changes have been saved.",
                        primary: "Got it")
        )
        lastResult = "\(result)"
    }
}

struct Tier0DemoScreen: View {
    @StateObject private var vm: Tier0DemoViewModel

    init(executor: ModalExecutor) {
        _vm = StateObject(wrappedValue: Tier0DemoViewModel(executor: executor))
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Last result: \(vm.lastResult)")
                .font(.footnote)
                .foregroundColor(.secondary)

            Text("This SwiftUI screen has no SwiftUI modal. It awaits executor.presentAndWait(); the real UIKit GBAlertModal paints over it.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)

            Button("Confirm delete (await result)") { Task { await vm.confirmDelete() } }
            Button("Show info") { Task { await vm.showInfo() } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Tier 0 · UIKit over SwiftUI")
    }
}
