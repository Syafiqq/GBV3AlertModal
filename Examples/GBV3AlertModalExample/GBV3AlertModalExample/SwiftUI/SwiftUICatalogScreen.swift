//
//  SwiftUICatalogScreen.swift
//  GBV3AlertModalExample
//
//  The SwiftUI Dialog Gallery: every catalog shape on the SwiftUI backend, in
//  front of a human's eyes — the 26 real Geniebook dialogs, the 28-entry stress
//  matrix, and the divergence section (one dialog per recorded UIKit-vs-SwiftUI
//  difference, each captioned with what to look for).
//
//  Wiring, end to end:
//      SwiftUICatalog.entries[i].present(executor)
//        → DefaultModalExecutor.presentAndWait(descriptor)
//          → SwiftUIModalRenderer.present(_:id:resolve:)   (styling from GalleryPresets)
//            → ModalHost draws the presentation over this screen
//
//  The traversal pill floats ABOVE the `ModalHost` overlay (later ZStack child),
//  the same way `FloatingTraversalControl` lives on the key window above the
//  UIKit gallery's modals — otherwise the modal's scrim would swallow every tap
//  and the owner could not step to the next shape.
//

import SwiftUI
import GBV3AlertModal

// MARK: - Model

/// Owns the renderer + executor for the screen and the traversal cursor.
///
/// One present at a time, tracked as a `Task` so stepping cancels the previous
/// await — `presentAndWait` sets `dismissOnAwaitCancel`, so the cancellation
/// tears the previous modal down through the token's `onDrop` instead of leaving
/// it stacked. That is the same scope-based cleanup `Tier0DemoScreen` relies on.
@MainActor
final class SwiftUICatalogModel: ObservableObject {
    let renderer: SwiftUIModalRenderer
    private let executor: DefaultModalExecutor

    @Published private(set) var currentIndex: Int
    /// Last resolved result, shown in the pill so a tap visibly round-trips.
    @Published private(set) var lastResult: String = "—"

    private var pending: Task<Void, Never>?
    private let initialEntryName: String?
    private var didPresentInitialEntry = false

    init(initialEntryName: String? = nil) {
        let renderer = SwiftUICatalog.makeRenderer()
        self.renderer = renderer
        self.executor = DefaultModalExecutor(renderer: renderer)
        self.initialEntryName = initialEntryName
        if let initialEntryName, let index = SwiftUICatalog.index(ofEntryNamed: initialEntryName) {
            self.currentIndex = index
        } else {
            self.currentIndex = 0
        }
    }

    var currentEntry: SwiftUICatalogEntry? {
        SwiftUICatalog.entries[safeIndex: currentIndex]
    }

    /// Drives the `GB_SWIFTUI_ENTRY` launch-environment hook: when the screen was
    /// opened for one named entry, show it as soon as the view appears (once).
    func presentInitialEntryIfNeeded() {
        guard !didPresentInitialEntry, initialEntryName != nil else {
            return
        }
        didPresentInitialEntry = true
        present(at: currentIndex)
    }

    /// Steps the cursor by `offset`, wrapping at both ends, then presents.
    func step(by offset: Int) {
        let count = SwiftUICatalog.entries.count
        guard count > 0 else {
            return
        }
        present(at: ((currentIndex + offset) % count + count) % count)
    }

    /// Dismisses whatever is shown and presents `entries[index]`.
    func present(at index: Int) {
        guard SwiftUICatalog.entries.indices.contains(index) else {
            return
        }
        pending?.cancel()
        currentIndex = index

        lastResult = "…"
        // Captures only `index` (Sendable) and `self` (a @MainActor class); the
        // entry itself is re-read inside, on the main actor.
        pending = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            let outcome = await SwiftUICatalog.entries[index].present(self.executor)
            guard !Task.isCancelled else {
                return   // superseded by a newer present, or the screen went away
            }
            self.lastResult = outcome
        }
    }

    /// Tears the current modal down without stepping — so the list underneath
    /// becomes tappable again.
    func dismissCurrent() {
        pending?.cancel()
        pending = nil
        lastResult = "dismissed"
    }
}

// MARK: - Screen

struct SwiftUICatalogScreen: View {
    @StateObject private var model: SwiftUICatalogModel

    /// `initialEntryName` is the `GB_SWIFTUI_ENTRY` hook's payload: when non-nil,
    /// that entry is presented as soon as the screen appears, so a specific shape
    /// can be screenshotted straight from `xcrun simctl launch`.
    init(initialEntryName: String? = nil) {
        _model = StateObject(wrappedValue: SwiftUICatalogModel(initialEntryName: initialEntryName))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ModalHost(renderer: model.renderer) {
                entryList
            }
            traversalPill
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .navigationTitle("SwiftUI Catalog")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.presentInitialEntryIfNeeded() }
        .onDisappear { model.dismissCurrent() }
    }

    // MARK: List

    private var entryList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                ForEach(SwiftUICatalog.entries.indices, id: \.self) { index in
                    // The list is three groups (26 real shapes, 28 stress shapes, the
                    // divergence section) and ~59 rows; without a break at each category
                    // change it is one undifferentiated scroll.
                    if isFirstRowOfCategory(index) {
                        categoryHeader(SwiftUICatalog.entries[index].category)
                    }
                    row(at: index)
                    Divider()
                }
                // Breathing room so the last row clears the floating pill.
                Color.clear.frame(height: 72)
            }
            .padding(.horizontal, 16)
        }
    }

    /// True when `index` opens a new `category` run — the list is already grouped by
    /// construction (catalog order), so this is a neighbour comparison, not a sort.
    private func isFirstRowOfCategory(_ index: Int) -> Bool {
        guard index > 0 else {
            return true
        }
        return SwiftUICatalog.entries[index].category != SwiftUICatalog.entries[index - 1].category
    }

    private func categoryHeader(_ category: String) -> some View {
        Text(category.uppercased())
            .font(.caption2.bold())
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 18)
            .padding(.bottom, 2)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(SwiftUICatalog.entries.count) shapes, SwiftUI backend")
                .font(.headline)
            Text("Same entry names as the UIKit Dialog Gallery — the 26 real shapes, then the "
                + "stress matrix, then the divergence section. Tap a row to present it here; "
                + "step with the pill. Compare each one against the UIKit gallery entry of the same name.")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Known divergences from UIKit — every entry:")
                .font(.caption.bold())
                .padding(.top, 4)
            ForEach(SwiftUIDivergence.global, id: \.caption) { divergence in
                Text("• " + divergence.caption)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    private func row(at index: Int) -> some View {
        let entry = SwiftUICatalog.entries[index]
        return Button {
            model.present(at: index)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(index + 1). \(entry.name)")
                        .font(.system(size: 15, weight: index == model.currentIndex ? .bold : .semibold))
                    Spacer(minLength: 8)
                    Text(entry.category)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                ForEach(entry.divergences, id: \.caption) { divergence in
                    Text("⚠︎ " + divergence.caption)
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Pill

    private var traversalPill: some View {
        HStack(spacing: 8) {
            pillButton(systemName: "chevron.left") { model.step(by: -1) }
            VStack(spacing: 1) {
                Text(model.currentEntry?.name ?? "—")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("\(model.currentIndex + 1)/\(SwiftUICatalog.entries.count) · \(model.lastResult)")
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .opacity(0.8)
            }
            .frame(maxWidth: .infinity)
            pillButton(systemName: "xmark") { model.dismissCurrent() }
            pillButton(systemName: "chevron.right") { model.step(by: 1) }
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .foregroundColor(.white)
        .background(Color.black.opacity(0.85))
        .clipShape(Capsule())
    }

    private func pillButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
