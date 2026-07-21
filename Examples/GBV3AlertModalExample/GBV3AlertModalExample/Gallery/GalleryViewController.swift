//
//  GalleryViewController.swift
//  GBV3AlertModalExample
//
//  Root screen of the Dialog Gallery: a grouped list of every
//  `DialogCatalog.entries` shape (sectioned by `entry.category`, in catalog
//  order), plus traversal glue for the `FloatingTraversalControl` installed
//  by `AppDelegate` on the key window. Tapping a row — or stepping the
//  floating control — dismisses whichever `SampleAlertModal` is currently
//  shown and presents the newly selected one.
//

import UIKit
import GBV3AlertModal

final class GalleryViewController: UITableViewController {
    private struct Section {
        let category: String
        /// (index into `DialogCatalog.entries`, the entry itself), in catalog order.
        let rows: [(globalIndex: Int, entry: DialogEntry)]
    }

    private static let cellReuseIdentifier = "DialogEntryCell"

    private let sections: [Section]

    /// The floating Prev/Next pill living on the key window (owned by
    /// `AppDelegate`). Weak: the window owns it, we only sync it.
    weak var floatingControl: FloatingTraversalControl?

    /// Index into `DialogCatalog.entries` of the entry the floating control
    /// (and, once a row has been tapped, the presented modal) currently points at.
    private var currentIndex: Int = 0

    /// The modal presented by the most recent `presentEntry(at:)` call, kept
    /// so the next traversal can dismiss it before presenting its neighbor.
    private var currentModal: SampleAlertModal?

    // MARK: - Init

    init() {
        var order: [String] = []
        var buckets: [String: [(Int, DialogEntry)]] = [:]
        for (index, entry) in DialogCatalog.entries.enumerated() {
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
        title = "Dialog Gallery (\(DialogCatalog.entries.count))"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellReuseIdentifier)
    }

    // MARK: - Traversal (called by AppDelegate / FloatingTraversalControl)

    /// Steps `currentIndex` by `offset` (wrapping around both ends), then presents that entry.
    func step(by offset: Int) {
        let count = DialogCatalog.entries.count
        guard count > 0 else {
            return
        }
        let next = ((currentIndex + offset) % count + count) % count
        presentEntry(at: next)
    }

    /// Dismisses whatever's currently shown, builds+shows `DialogCatalog.entries[globalIndex]`,
    /// and syncs the floating control label + the table's selected row.
    func presentEntry(at globalIndex: Int) {
        guard DialogCatalog.entries.indices.contains(globalIndex) else {
            return
        }

        currentModal?.hide()

        let entry = DialogCatalog.entries[globalIndex]
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
        guard DialogCatalog.entries.indices.contains(currentIndex) else {
            return
        }
        let entry = DialogCatalog.entries[currentIndex]
        floatingControl?.setLabel("\(entry.name) (\(currentIndex + 1)/\(DialogCatalog.entries.count))")
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
        let globalIndex = sections[indexPath.section].rows[indexPath.row].globalIndex
        presentEntry(at: globalIndex)
    }
}
