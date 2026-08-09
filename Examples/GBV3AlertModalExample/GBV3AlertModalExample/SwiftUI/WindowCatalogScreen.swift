//
//  WindowCatalogScreen.swift
//  GBV3AlertModalExample
//
//  The `WindowModalRenderer` twin of `EmbeddedCatalogScreen` — the same 26 real Geniebook shapes, 28
//  stress entries, and 11 variant shapes, same `SwiftUICatalog.dialogAndStressEntries` reused
//  unchanged, on the rootRenderer backend instead. No `ModalHost`/`EmbeddedModalHost` wrapper:
//  `WindowModalRenderer` installs each presentation directly into the key `UIWindow`, so it paints
//  OVER this screen exactly like `Tier0DemoScreen`'s UIKit modal does — the screen itself is just the
//  list + traversal pill, nothing to embed.
//

import SwiftUI
import GBV3AlertModal

@MainActor
final class WindowCatalogModel: ObservableObject {
    private let executor: DefaultModalExecutor

    @Published private(set) var currentIndex = 0
    @Published private(set) var lastResult: String = "—"

    private var pending: Task<Void, Never>?

    init() {
        let renderer = WindowModalRenderer(
            alertProperties: GalleryPresets.standardModalProperties,
            popupProperties: GalleryPresets.popupModalProperties
        )
        let presets = UIKitFreeCatalogPresets.stylePresets
            + UIKitFreeCatalogPresets.stressPresets
            + UIKitFreeCatalogPresets.variantPresets
        for (style, properties) in presets {
            renderer.register(style: style, properties: properties)
        }
        renderer.registerBuiltInDescriptors()
        self.executor = DefaultModalExecutor(renderer: renderer)
    }

    var currentEntry: SwiftUICatalogEntry? {
        SwiftUICatalog.dialogAndStressEntries[safeIndex: currentIndex]
    }

    func step(by offset: Int) {
        let count = SwiftUICatalog.dialogAndStressEntries.count
        guard count > 0 else { return }
        present(at: ((currentIndex + offset) % count + count) % count)
    }

    func present(at index: Int) {
        guard SwiftUICatalog.dialogAndStressEntries.indices.contains(index) else { return }
        pending?.cancel()
        currentIndex = index

        let entry = SwiftUICatalog.dialogAndStressEntries[index]
        guard entry.present != nil else {
            lastResult = "not yet renderable"
            pending = nil
            return
        }

        lastResult = "…"
        pending = Task { @MainActor [weak self] in
            guard let self, let present = SwiftUICatalog.dialogAndStressEntries[index].present else { return }
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

struct WindowCatalogScreen: View {
    @StateObject private var model = WindowCatalogModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            entryList
            traversalPill
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .navigationTitle("Window Catalog")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.dismissCurrent() }
    }

    private var entryList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(SwiftUICatalog.dialogAndStressEntries.count) shapes, WindowModalRenderer "
                    + "(26 real + 28 stress + 11 variants)")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                ForEach(SwiftUICatalog.dialogAndStressEntries.indices, id: \.self) { index in
                    row(at: index)
                    Divider()
                }
                Color.clear.frame(height: 72)
            }
            .padding(.horizontal, 16)
        }
    }

    private func row(at index: Int) -> some View {
        let entry = SwiftUICatalog.dialogAndStressEntries[index]
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
                Text("\(model.currentIndex + 1)/\(SwiftUICatalog.dialogAndStressEntries.count) · \(model.lastResult)")
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
