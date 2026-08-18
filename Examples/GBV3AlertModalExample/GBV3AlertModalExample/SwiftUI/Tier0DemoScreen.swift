import SwiftUI
import GBV3AlertModal

/// Tier 0: a SwiftUI ViewModel drives the EXISTING executor. This screen has NO SwiftUI modal view —
/// it `await`s `executor.presentAndWait(...)` and the real UIKit `GBAlertModal` paints OVER this
/// screen. (The executor→UIKit-over-SwiftUI seam itself is proven by `Tier0HostingSmokeTests`; this
/// screen is the VM-facing usage of it.) The renderer is injected behind the executor, so this exact
/// VM code runs unchanged under a future Tier-1 `SwiftUIModalRenderer` — Tier 0 → Tier 1 is a renderer
/// swap, not a rewrite.
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
        guard !Task.isCancelled else { return }   // pop-while-shown cancels the await; don't record it
        lastResult = "\(result)"
    }

    func showInfo() async {
        let result = await executor.presentAndWait(
            AlertDialog(title: "You're all set",
                        subtitle: "Your changes have been saved.",
                        primary: "Got it")
        )
        guard !Task.isCancelled else { return }
        lastResult = "\(result)"
    }

    func showSecondaryInfo() async {
        let result = await executor.presentAndWait(
            AlertDialog(title: "More information",
                        subtitle: "SwiftUI examples use one standard alert descriptor.",
                        primary: "Got it")
        )
        guard !Task.isCancelled else { return }
        lastResult = "info: \(result)"
    }

    /// Custom content: a text field inside the modal; the result carries the entered text.
    func showRename() async {
        let result = await executor.presentAndWait(
            TextInputDialog(title: "Rename worksheet",
                            placeholder: "Worksheet name",
                            initialText: "Untitled",
                            primary: "Save",
                            secondary: "Cancel")
        )
        guard !Task.isCancelled else { return }
        switch result {
        case .submitted(let name): lastResult = "renamed: \(name)"
        case .dismissed:           lastResult = "rename: dismissed"
        }
    }

    /// Custom content: a date picker inside the modal; the result carries the picked date.
    func pickDate() async {
        let result = await executor.presentAndWait(
            DatePickerDialog(title: "Pick a date", initialDate: Date(), primary: "OK", secondary: "Cancel")
        )
        guard !Task.isCancelled else { return }
        switch result {
        case .submitted(let date): lastResult = "date: \(date.formatted(date: .abbreviated, time: .omitted))"
        case .dismissed:           lastResult = "date: dismissed"
        }
    }
}

struct Tier0DemoScreen: View {
    @StateObject private var vm: Tier0DemoViewModel
    /// The in-flight present. Bound to view lifecycle so leaving the screen cancels the await —
    /// which fires the token's `onDrop → dismiss`, tearing the UIKit modal down instead of orphaning
    /// it on the key window. This is exactly the scope-based cleanup Tier 1 relies on.
    @State private var pending: Task<Void, Never>?

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

            Button("Confirm delete (await result)") { present { await vm.confirmDelete() } }
            Button("Show info") { present { await vm.showInfo() } }
            Button("Show more information") { present { await vm.showSecondaryInfo() } }
            Button("Rename (text input)") { present { await vm.showRename() } }
            Button("Pick date (date picker)") { present { await vm.pickDate() } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Tier 0 · UIKit over SwiftUI")
        .onDisappear { pending?.cancel() }
    }

    /// Runs one present at a time, tracked so `onDisappear` can cancel it.
    private func present(_ op: @escaping () async -> Void) {
        pending?.cancel()
        pending = Task { await op() }
    }
}
