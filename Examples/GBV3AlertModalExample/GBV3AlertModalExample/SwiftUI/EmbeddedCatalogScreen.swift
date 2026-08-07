//
//  EmbeddedCatalogScreen.swift
//  GBV3AlertModalExample
//
//  The `EmbeddedModalRenderer` twin of `SwiftUICatalogScreen` — the 26 real Geniebook shapes, in
//  front of a human's eyes, on the mainUIRenderer backend. Reuses `SwiftUICatalog.dialogEntries`
//  UNCHANGED: each entry's `present` closure only calls `executor.presentAndWait(descriptor())`,
//  which is renderer-agnostic — only the renderer THIS screen's executor wraps differs.
//
//  Closes the gap `EmbeddedShapeCoverageTests` couldn't: that suite proves every shape presents and
//  has a body structurally; nobody had actually LOOKED at one rendered by this renderer until now.
//

import SwiftUI
import GBV3AlertModal

@MainActor
final class EmbeddedCatalogModel: ObservableObject {
    let renderer: EmbeddedModalRenderer
    private let executor: DefaultModalExecutor

    @Published private(set) var currentIndex = 0
    @Published private(set) var lastResult: String = "—"

    private var pending: Task<Void, Never>?

    init() {
        let renderer = EmbeddedModalRenderer(
            alertProperties: GalleryPresets.standardModalProperties,
            popupProperties: GalleryPresets.popupModalProperties
        )
        for (style, properties) in UIKitFreeCatalogPresets.stylePresets {
            renderer.register(style: style, properties: properties)
        }
        renderer.registerBuiltInDescriptors()
        self.renderer = renderer
        self.executor = DefaultModalExecutor(renderer: renderer)
    }

    var currentEntry: SwiftUICatalogEntry? {
        SwiftUICatalog.dialogEntries[safeIndex: currentIndex]
    }

    func step(by offset: Int) {
        let count = SwiftUICatalog.dialogEntries.count
        guard count > 0 else { return }
        present(at: ((currentIndex + offset) % count + count) % count)
    }

    func present(at index: Int) {
        guard SwiftUICatalog.dialogEntries.indices.contains(index) else { return }
        pending?.cancel()
        currentIndex = index

        let entry = SwiftUICatalog.dialogEntries[index]
        guard entry.present != nil else {
            lastResult = "not yet renderable"
            pending = nil
            return
        }

        lastResult = "…"
        pending = Task { @MainActor [weak self] in
            guard let self, let present = SwiftUICatalog.dialogEntries[index].present else { return }
            let outcome = await present(self.executor)
            guard !Task.isCancelled else { return }
            self.lastResult = outcome
        }
    }

    func dismissCurrent() {
        pending?.cancel()
        pending = nil
        lastResult = "dismissed"
    }
}

struct EmbeddedCatalogScreen: View {
    @StateObject private var model = EmbeddedCatalogModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            EmbeddedModalHost(renderer: model.renderer) {
                entryList
            }
            traversalPill
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .navigationTitle("Embedded Catalog")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.dismissCurrent() }
    }

    private var entryList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(SwiftUICatalog.dialogEntries.count) real shapes, EmbeddedModalRenderer")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                ForEach(SwiftUICatalog.dialogEntries.indices, id: \.self) { index in
                    row(at: index)
                    Divider()
                }
                Color.clear.frame(height: 72)
            }
            .padding(.horizontal, 16)
        }
    }

    private func row(at index: Int) -> some View {
        let entry = SwiftUICatalog.dialogEntries[index]
        return Button {
            model.present(at: index)
        } label: {
            Text("\(index + 1). \(entry.name)")
                .font(.system(size: 15, weight: index == model.currentIndex ? .bold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var traversalPill: some View {
        HStack(spacing: 8) {
            pillButton(systemName: "chevron.left") { model.step(by: -1) }
            VStack(spacing: 1) {
                Text(model.currentEntry?.name ?? "—")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("\(model.currentIndex + 1)/\(SwiftUICatalog.dialogEntries.count) · \(model.lastResult)")
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
