//
//  GalleryViewController.swift
//  GBV3AlertModalExample
//
//  Root screen of the Dialog Gallery: a grouped list of every
//  `DialogCatalog.entries + StressCatalog.entries` shape (sectioned by
//  `entry.category`, in catalog order), plus traversal glue for the
//  `FloatingTraversalControl` installed by `AppDelegate` on the key window.
//  Tapping a row — or stepping the floating control — dismisses whichever
//  `SampleAlertModal` is currently shown and presents the newly selected one.
//

import UIKit
import SwiftUI
import GBV3AlertModal

@MainActor
final class GalleryViewController: UITableViewController {
    private struct Section {
        let category: String
        /// (index into `Self.allEntries`, the entry itself), in catalog order.
        let rows: [(globalIndex: Int, entry: DialogEntry)]
    }

    private static let cellReuseIdentifier = "DialogEntryCell"

    /// The full traversal order: the 26 Geniebook shapes, followed by the
    /// sampled stress matrix, followed by the title/subtitle/button-style/
    /// button-state variants, followed by the divergence shapes (the UIKit
    /// halves of the recorded UIKit-vs-SwiftUI differences) — combined into one
    /// list so `step(by:)` wraps across all four groups uniformly.
    private static let allEntries: [DialogEntry] =
        DialogCatalog.entries
            + StressCatalog.entries
            + VariantsCatalog.entries
            + DivergenceCatalog.entries

    private let sections: [Section]

    /// The floating Prev/Next pill living on the key window (owned by
    /// `AppDelegate`). Weak: the window owns it, we only sync it.
    weak var floatingControl: FloatingTraversalControl?

    /// Index into `Self.allEntries` of the entry the floating control
    /// (and, once a row has been tapped, the presented modal) currently points at.
    private var currentIndex: Int = 0

    /// The modal presented by the most recent `presentEntry(at:)` call, kept
    /// so the next traversal can dismiss it before presenting its neighbor.
    private var currentModal: SampleAlertModal?

    // MARK: - Init

    init() {
        var order: [String] = []
        var buckets: [String: [(Int, DialogEntry)]] = [:]
        for (index, entry) in Self.allEntries.enumerated() {
            if buckets[entry.category] == nil {
                buckets[entry.category] = []
                order.append(entry.category)
            }
            buckets[entry.category]?.append((index, entry))
        }
        self.sections = order.map { category in
            Section(category: category, rows: buckets[category] ?? [])
        }
        super.init(style: .grouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Dialog Gallery (\(Self.allEntries.count))"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellReuseIdentifier)
        // 8 titled bar button items don't fit an iPhone-width nav bar — UIKit silently drops
        // whichever ones don't fit rather than showing an overflow affordance, so half of these
        // were unreachable by tapping. One menu button, grouped into the two pairings that were
        // getting confused for each other (adoption demo vs. its same-shape 54-entry catalog).
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            menu: UIMenu(children: [
                UIMenu(title: "", options: .displayInline, children: [
                    UIAction(title: "SwiftUI") { [weak self] _ in self?.openSwiftUIDemo() },
                    UIAction(title: "Tier 0") { [weak self] _ in self?.openTier0Demo() },
                    UIAction(title: "Tier 1") { [weak self] _ in self?.openAdoptionDemo() },
                    UIAction(title: "Embedded") { [weak self] _ in self?.openEmbeddedDemo() },
                    UIAction(title: "Window") { [weak self] _ in self?.openWindowDemo() },
                ]),
                UIMenu(title: "", options: .displayInline, children: [
                    UIAction(title: "SwiftUI Catalog") { [weak self] _ in self?.openSwiftUICatalogTapped() },
                    UIAction(title: "Embedded Catalog") { [weak self] _ in self?.openEmbeddedCatalog() },
                    UIAction(title: "Window Catalog") { [weak self] _ in self?.openWindowCatalog() },
                ]),
            ])
        )
    }

    /// The floating pill is hidden while the SwiftUI catalog is on screen (it
    /// drives THIS gallery, and it would sit on top of that screen's own pill),
    /// so restore it whenever the gallery comes back.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        floatingControl?.isHidden = false
    }

    @objc private func openSwiftUIDemo() {
        let host = UIHostingController(rootView: SwiftUIDemoScreen())
        navigationController?.pushViewController(host, animated: true)
    }

    /// Tier 0: build the library executor over a UIKit renderer and inject it into a SwiftUI VM.
    /// The renderer paints the real UIKit modal on the key window, over the pushed SwiftUI screen.
    /// Styling comes from `GalleryPresets` — the faithful mirror of the distribution app's
    /// `Presentation.UiKit.V3AlertModal` preset — so the demo exercises production-shaped config.
    @objc private func openTier0Demo() {
        let properties = GalleryPresets.properties
        let renderer = UIKitModalRenderer(
            alertProperties: properties,
            popupProperties: GalleryPresets.popupProperties
        )
        // Custom-content input descriptors — registered by the consumer with the library's holders.
        renderer.register(TextInputDialog.self) { descriptor, resolve in
            (properties, UIKitModalRenderer.TextInputHolder.make(for: descriptor, resolve: resolve))
        }
        renderer.register(DatePickerDialog.self) { descriptor, resolve in
            (properties, UIKitModalRenderer.DatePickerHolder.make(for: descriptor, resolve: resolve))
        }
        let executor = DefaultModalExecutor(renderer: renderer)
        let host = UIHostingController(rootView: Tier0DemoScreen(executor: executor))
        navigationController?.pushViewController(host, animated: true)
    }

    /// Tier 1: the whole chain — VM → executor → coordinator → `SwiftUIModalRenderer`, with the
    /// modals rendered as SwiftUI views inside the pushed screen rather than on the key window. The
    /// same `GalleryPresets` config the Tier 0 demo uses, so the two differ only by renderer.
    @objc private func openAdoptionDemo() {
        let host = UIHostingController(
            rootView: AdoptionScreen(
                properties: GalleryPresets.properties,
                popupProperties: GalleryPresets.popupProperties
            )
        )
        navigationController?.pushViewController(host, animated: true)
    }

    /// Sanity check for `EmbeddedModalRenderer` — the UIKit-free renderer
    /// (`docs`... see the plan at `iridescent-enchanting-pike.md`) — running in a real app screen,
    /// not just unit tests. Same chain shape as `openAdoptionDemo`, minimal preset (not
    /// `GalleryPresets`-fidelity — this answers "does it work", not "does it look production-exact").
    @objc private func openEmbeddedDemo() {
        let host = UIHostingController(rootView: EmbeddedAdoptionScreen())
        navigationController?.pushViewController(host, animated: true)
    }

    /// Sanity check for `WindowModalRenderer` — rootRenderer, the window-level UIKit-free renderer
    /// (plan: `iridescent-enchanting-pike.md`; shipped `a1c6bbb`). Reuses `Tier0DemoScreen` as-is:
    /// that screen's whole point is "VM drives the executor, the modal paints over this SwiftUI
    /// screen at window level" — exactly rootRenderer's job, just SwiftUI-drawn instead of UIKit.
    /// All 5 of its buttons work here since `1d7aa46`: `registerBuiltInDescriptors()` registers the
    /// 5 bespoke kinds (Rename/Pick date included), same call `EmbeddedAdoptionScreen`'s renderer
    /// never needed for ITS 3 buttons (none of them use a bespoke kind) but this one does.
    @objc private func openWindowDemo() {
        let renderer = WindowModalRenderer(
            alertProperties: GalleryPresets.standardModalProperties,
            popupProperties: GalleryPresets.popupModalProperties
        )
        renderer.registerBuiltInDescriptors()
        let executor = DefaultModalExecutor(renderer: renderer)
        let host = UIHostingController(rootView: Tier0DemoScreen(executor: executor))
        navigationController?.pushViewController(host, animated: true)
    }

    @objc private func openSwiftUICatalogTapped() {
        openSwiftUICatalog(entryNamed: nil)
    }

    /// The 26 real shapes, in front of a human's eyes, on `EmbeddedModalRenderer` — the visual half
    /// of the claim `EmbeddedShapeCoverageTests` proves structurally in the library's test target.
    ///
    /// Hides the window-level pill first, same reason `openSwiftUICatalog` does: this screen draws
    /// its OWN bottom traversal pill (`EmbeddedCatalogScreen.traversalPill`), and leaving the
    /// window-level one up stacked the two at nearly the same bottom position.
    @objc private func openEmbeddedCatalog() {
        floatingControl?.pauseAutoPlay()
        floatingControl?.isHidden = true
        let host = UIHostingController(rootView: EmbeddedCatalogScreen())
        navigationController?.pushViewController(host, animated: true)
    }

    /// The `WindowModalRenderer` twin of `openEmbeddedCatalog` — same 26 shapes, rootRenderer
    /// backend, same own-pill-vs-window-pill overlap fixed the same way (`WindowCatalogScreen`
    /// draws its own `traversalPill` too).
    @objc private func openWindowCatalog() {
        floatingControl?.pauseAutoPlay()
        floatingControl?.isHidden = true
        let host = UIHostingController(rootView: WindowCatalogScreen())
        navigationController?.pushViewController(host, animated: true)
    }

    /// Tier 1: the SAME 26 shapes as this gallery's `DialogCatalog` rows, rendered
    /// by `SwiftUIModalRenderer` + `ModalHost` instead of `GBAlertModal`. Pass
    /// `entryNamed:` to present one specific shape on appear — that is the
    /// `GB_SWIFTUI_ENTRY` launch-environment hook's path (see `AppDelegate`).
    func openSwiftUICatalog(entryNamed name: String?) {
        // The window-level pill drives THIS gallery's UIKit modals; leaving it up
        // over the SwiftUI catalog would present UIKit dialogs on top of it and
        // collide with that screen's own traversal pill.
        floatingControl?.pauseAutoPlay()
        floatingControl?.isHidden = true
        let host = UIHostingController(rootView: SwiftUICatalogScreen(initialEntryName: name))
        navigationController?.pushViewController(host, animated: name == nil)
    }

    // MARK: - Traversal (called by AppDelegate / FloatingTraversalControl)

    /// Steps `currentIndex` by `offset` (wrapping around both ends), then presents that entry.
    func step(by offset: Int) {
        let count = Self.allEntries.count
        guard count > 0 else {
            return
        }
        let next = ((currentIndex + offset) % count + count) % count
        presentEntry(at: next)
    }

    /// Looks up an entry by its exact `name` (e.g. `"stress-maxed-vertical"`) and presents
    /// it. Used only by `AppDelegate`'s `GB_STRESS_ENTRY` launch-environment hook, which
    /// exists so a specific gallery entry can be driven straight from `xcrun simctl launch`
    /// for scripted/CI screenshotting without needing UI automation.
    func presentEntry(named name: String) {
        guard let index = Self.allEntries.firstIndex(where: { $0.name == name }) else {
            return
        }
        presentEntry(at: index)
    }

    /// Dismisses whatever's currently shown, builds+shows `Self.allEntries[globalIndex]`,
    /// and syncs the floating control label + the table's selected row.
    func presentEntry(at globalIndex: Int) {
        guard Self.allEntries.indices.contains(globalIndex) else {
            return
        }

        currentModal?.hide()

        let entry = Self.allEntries[globalIndex]
        let modal = entry.make()
        modal.show()
        currentModal = modal
        currentIndex = globalIndex

        bringFloatingControlToFront()
        syncFloatingControl()
        syncSelectedRow()
    }

    /// Pushes the current `currentIndex` state to the floating control's label without
    /// presenting anything — used once at launch so the pill isn't blank before any tap.
    func syncFloatingControl() {
        guard Self.allEntries.indices.contains(currentIndex) else {
            return
        }
        let entry = Self.allEntries[currentIndex]
        floatingControl?.setLabel("\(entry.name) (\(currentIndex + 1)/\(Self.allEntries.count))")
    }

    /// The dialogs `show()` themselves as subviews of the key window (see
    /// `SampleAlertModal.show()`), the same window the floating control lives
    /// on (see `AppDelegate`) — so each new presentation can cover the pill.
    /// Re-asserting front-most order after every `show()` keeps it tappable.
    private func bringFloatingControlToFront() {
        guard let floatingControl, let window = floatingControl.superview else {
            return
        }
        window.bringSubviewToFront(floatingControl)
    }

    private func syncSelectedRow() {
        guard let indexPath = indexPath(forGlobalIndex: currentIndex) else {
            return
        }
        tableView.indexPathsForSelectedRows?.forEach { tableView.deselectRow(at: $0, animated: false) }
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
    }

    private func indexPath(forGlobalIndex globalIndex: Int) -> IndexPath? {
        for (sectionIndex, section) in sections.enumerated() {
            if let row = section.rows.firstIndex(where: { $0.globalIndex == globalIndex }) {
                return IndexPath(row: row, section: sectionIndex)
            }
        }
        return nil
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].category
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellReuseIdentifier, for: indexPath)
        cell.textLabel?.text = sections[indexPath.section].rows[indexPath.row].entry.name
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // A manual row tap is a manual traversal too — stop any running auto-next.
        floatingControl?.pauseAutoPlay()
        let globalIndex = sections[indexPath.section].rows[indexPath.row].globalIndex
        presentEntry(at: globalIndex)
    }
}
