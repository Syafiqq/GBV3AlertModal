import SwiftUI
import GBV3AlertModal

/// **The first end-to-end adoption of the Tier-1 stack: VM → executor → coordinator → SwiftUI
/// renderer, with no UIKit modal anywhere.**
///
/// Every other screen in this app exercises one seam. `Tier0DemoScreen` drives the executor but its
/// modals are painted by `UIKitModalRenderer` onto the key window; `SwiftUICatalogScreen` renders
/// through `SwiftUIModalRenderer` but presents shapes directly, with no executor and no coordinator.
/// This screen is the whole chain, arranged the way a product screen would actually arrange it:
///
/// * `SwiftUIModalRenderer` is owned by the VM and hosted by `ModalHost` in this view's body, so
///   modals are SwiftUI views inside this screen's hierarchy rather than a window overlay;
/// * `DefaultModalExecutor` is the only thing the VM's methods touch — they `await` a result and
///   never mention a renderer;
/// * `MainTabModalCoordinator` sits behind the executor, so competing presentations SERIALISE
///   instead of stacking, which is the property no unit test can demonstrate against a live screen.
///
/// **What this is for.** 452 library tests say the seam is correct; none of them say it is usable.
/// The questions this screen answers are the ones that only show up in an adoption: does the VM code
/// read like ordinary async code, does the coordinator behave when a user taps twice, does a
/// registered custom view keep its typed text across a re-render.
@MainActor
final class AdoptionViewModel: ObservableObject {
    /// Owned here, and `@Published` indirectly via `ModalHost`'s own `@ObservedObject` on it — the
    /// renderer IS the presentation state, so the screen re-renders when it changes.
    let renderer: SwiftUIModalRenderer

    @Published private(set) var lastResult = "—"
    @Published private(set) var log: [String] = []

    private let executor: DefaultModalExecutor

    init(properties: GBAlertModal.Properties) {
        let renderer = SwiftUIModalRenderer(alertProperties: properties)
        // Custom-content descriptors are registered by the CONSUMER, exactly as the Tier 0 screen
        // registers them against the UIKit renderer — the registration API is the same shape on both
        // backends, which is the portability claim being exercised.
        renderer.registerBuiltInDescriptors()
        self.renderer = renderer

        let executor = DefaultModalExecutor(renderer: renderer)
        // THE COORDINATOR IS THE POINT. Without it, two taps present two modals. With it, the second
        // waits for the first to resolve.
        executor.coordinator = MainTabModalCoordinator(renderer: renderer)
        self.executor = executor
    }

    func confirmDelete() async {
        await record("delete") {
            await executor.presentAndWait(
                AlertDialog(
                    title: "Delete draft?",
                    subtitle: "This can't be undone.",
                    primary: "Delete",
                    secondary: "Keep"
                )
            )
        }
    }

    func showInfo() async {
        await record("info") {
            await executor.presentAndWait(
                AlertDialog(
                    title: "Information",
                    subtitle: "Every SwiftUI alert uses the unified standard configuration.",
                    primary: "Got it"
                )
            )
        }
    }

    /// A registered custom view whose `@State` must survive the re-renders a presentation diff
    /// causes — the case `ModalHost`'s `ForEach` identity exists for.
    func rename() async {
        let result = await executor.presentAndWait(
            TextInputDialog(
                title: "Rename worksheet",
                placeholder: "Worksheet name",
                initialText: "Untitled",
                primary: "Save",
                secondary: "Cancel"
            )
        )
        guard !Task.isCancelled else { return }
        switch result {
        case let .submitted(text): append("rename: submitted '\(text)'")
        case .dismissed: append("rename: dismissed")
        }
    }

    /// **Two presentations launched together.** With the coordinator installed the second waits; the
    /// log's ORDER is the observable proof, and it is what a user hammering a button produces.
    func presentTwoAtOnce() async {
        append("— two at once —")
        async let first: Void = confirmDelete()
        async let second: Void = showInfo()
        _ = await (first, second)
    }

    private func record(_ label: String, _ present: () async -> AlertDialog.Result) async {
        let result = await present()
        // A cancelled await means the screen went away mid-presentation; recording it would be a lie.
        guard !Task.isCancelled else { return }
        append("\(label): \(result)")
    }

    private func append(_ line: String) {
        log.append(line)
        lastResult = line
    }
}

/// The screen. `ModalHost` wraps the content, so every modal this VM presents is a SwiftUI view in
/// THIS hierarchy — no window, no `UIViewController`, nothing UIKit-shaped in the call site.
struct AdoptionScreen: View {
    @StateObject private var viewModel: AdoptionViewModel

    init(properties: GBAlertModal.Properties) {
        _viewModel = StateObject(wrappedValue: AdoptionViewModel(properties: properties))
    }

    var body: some View {
        ModalHost(renderer: viewModel.renderer) {
            List {
                Section("Present") {
                    button("Confirm delete") { await viewModel.confirmDelete() }
                    button("Show information") { await viewModel.showInfo() }
                    button("Rename (custom content)") { await viewModel.rename() }
                    button("Two at once — coordinator serialises") {
                        await viewModel.presentTwoAtOnce()
                    }
                }
                Section("Last result") {
                    Text(viewModel.lastResult).font(.body.monospaced())
                }
                if !viewModel.log.isEmpty {
                    Section("Log") {
                        ForEach(Array(viewModel.log.enumerated()), id: \.offset) { _, line in
                            Text(line).font(.caption.monospaced())
                        }
                    }
                }
            }
        }
        .navigationTitle("Tier 1 adoption")
    }

    private func button(_ title: String, action: @escaping () async -> Void) -> some View {
        Button(title) { Task { await action() } }
    }
}
