import SwiftUI
import GBV3AlertModal

/// **Sanity check for `EmbeddedModalRenderer`/`EmbeddedModalHost` in a real running app —
/// the increment's own plan step 5.**
///
/// Deliberate near-copy of `AdoptionScreen`'s VM → executor → coordinator → renderer chain, with
/// `SwiftUIModalRenderer`/`ModalHost`/`GBAlertModal.Properties` swapped for
/// `EmbeddedModalRenderer`/`EmbeddedModalHost`/`ModalProperties` — the UIKit-free renderer this
/// session's plan (`iridescent-enchanting-pike.md`) shipped. No "rename (custom content)" button:
/// this renderer registers only the standard family (`AlertDialog`/`PopupDialog`) so far — bespoke
/// descriptors are a later increment.
///
/// Minimal preset, not a `GalleryPresets`-fidelity port — this screen answers "does the whole chain
/// actually work when it's a real running app, not a unit test", not "does it look production-exact".
@MainActor
final class EmbeddedAdoptionViewModel: ObservableObject {
    let renderer: EmbeddedModalRenderer

    @Published private(set) var lastResult = "—"
    @Published private(set) var log: [String] = []

    private let executor: DefaultModalExecutor

    init() {
        // GalleryPresets.standardModalProperties — the single UIKit-free example preset
        // preset shared with the "Window" gallery demo (rootRenderer's own sanity check).
        let renderer = EmbeddedModalRenderer(
            alertProperties: GalleryPresets.standardModalProperties,
            popupProperties: GalleryPresets.standardModalProperties
        )
        self.renderer = renderer

        let executor = DefaultModalExecutor(renderer: renderer)
        // Same "the coordinator is the point" wiring `AdoptionScreen` demonstrates: without it, two
        // taps present two modals; with it, the second waits.
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

    func showPopup() async {
        await record("popup") {
            await executor.presentAndWait(
                PopupDialog(
                    title: "Popup style",
                    subtitle: "PopupDialog resolves through the same consolidated standard configuration.",
                    primary: "Got it"
                )
            )
        }
    }

    /// Same coordinator-serialisation proof `AdoptionScreen.presentTwoAtOnce` demonstrates.
    func presentTwoAtOnce() async {
        append("— two at once —")
        async let first: Void = confirmDelete()
        async let second: Void = showPopup()
        _ = await (first, second)
    }

    private func record(_ label: String, _ present: () async -> AlertDialog.Result) async {
        let result = await present()
        guard !Task.isCancelled else { return }
        append("\(label): \(result)")
    }

    private func append(_ line: String) {
        log.append(line)
        lastResult = line
    }
}

struct EmbeddedAdoptionScreen: View {
    @StateObject private var viewModel = EmbeddedAdoptionViewModel()

    var body: some View {
        EmbeddedModalHost(renderer: viewModel.renderer) {
            List {
                Section("Present (EmbeddedModalRenderer — UIKit-free)") {
                    button("Confirm delete") { await viewModel.confirmDelete() }
                    button("Popup style") { await viewModel.showPopup() }
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
        .navigationTitle("Embedded renderer")
    }

    private func button(_ title: String, action: @escaping () async -> Void) -> some View {
        Button(title) { Task { await action() } }
    }
}
