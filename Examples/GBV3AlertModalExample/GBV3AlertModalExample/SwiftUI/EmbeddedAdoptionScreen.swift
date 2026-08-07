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
        let renderer = EmbeddedModalRenderer(
            alertProperties: Self.properties,
            popupProperties: Self.popupProperties
        )
        self.renderer = renderer

        let executor = DefaultModalExecutor(renderer: renderer)
        // Same "the coordinator is the point" wiring `AdoptionScreen` demonstrates: without it, two
        // taps present two modals; with it, the second waits.
        executor.coordinator = RootScreenModalCoordinator(renderer: renderer)
        self.executor = executor
    }

    /// A minimal, UIKit-free preset — no `GalleryColor`/`GallerySHSans` mirroring, this is a
    /// functional sanity check, not a fidelity port.
    private static let properties = ModalProperties(
        baseTint: .blue,
        overlayColor: .black.opacity(0.6),
        contentProperty: ModalProperties.ContentProperty(
            backgroundColor: .white,
            cornerRadius: 16,
            fixedWidthPortrait: 256,
            maxWidthPortrait: 256,
            fixedWidthLandscape: 256,
            maxWidthLandscape: 256,
            childShouldMatchParent: true
        ),
        margin: EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20),
        padding: UIMinMaxEdgeInsets(top: (16, 24), left: (16, 32), bottom: (16, 24), right: (16, 32)),
        bannerRatio: 1,
        titleFont: .system(size: 24, weight: .bold),
        titleColor: .primary,
        subtitleFont: .system(size: 16),
        subtitleColor: .secondary,
        buttonActionShouldMatchParent: true,
        buttonActionOrientation: .vertical,
        primaryActionStyle: .obliqueBottomLeft(
            ModalProperties.ActionStyle.ObliqueBottomLeftTheme(
                unPressedColor: .orange,
                pressedColor: .blue,
                disabledColor: .gray,
                shadowColor: .orange,
                titleColor: .white,
                titleDisableColor: .white,
                titleFont: .system(size: 16, weight: .medium)
            )
        ),
        secondaryActionStyle: .plain(
            ModalProperties.ActionStyle.PlainTheme(
                titleColor: .blue, titleDisableColor: .gray, titleFont: .system(size: 16, weight: .medium)
            )
        ),
        closeButtonTint: .black,
        space: ModalProperties.ComponentSpace(banner: 8, title: 8, subtitle: 16, interButton: 8)
    )

    private static let popupProperties = ModalProperties(
        baseTint: properties.baseTint,
        overlayColor: properties.overlayColor,
        contentProperty: properties.contentProperty,
        margin: properties.margin,
        padding: UIMinMaxEdgeInsets(top: (20, 32), left: (20, 32), bottom: (20, 32), right: (20, 32)),
        titleFont: properties.titleFont,
        titleColor: properties.titleColor,
        subtitleFont: properties.subtitleFont,
        subtitleColor: properties.subtitleColor,
        buttonActionShouldMatchParent: properties.buttonActionShouldMatchParent,
        buttonActionOrientation: properties.buttonActionOrientation,
        primaryActionStyle: properties.primaryActionStyle,
        secondaryActionStyle: properties.secondaryActionStyle,
        closeButtonTint: properties.closeButtonTint,
        space: ModalProperties.ComponentSpace(banner: 16, title: 16, subtitle: 24, interButton: 8)
    )

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
                    subtitle: "A different descriptor resolves to the popup preset.",
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
