//
//  DialogCatalog.swift
//  GBV3AlertModalExample
//
//  The 26 distinct Geniebook dialog shapes, one factory per shape, sourced
//  verbatim (strings/config/assets) from
//  `docs/superpowers/specs/2026-07-21-dialog-catalog.md`. Entries are grouped
//  into `DialogCatalog+<Category>.swift` files (one array per feature area);
//  this file only declares the shared `DialogEntry` type and stitches the
//  per-category arrays together.
//
//  Fields the catalog marks `[API]`/`[DYNAMIC]` (server- or caller-supplied at
//  runtime in the real app) are stubbed here with a literal `"[API] "`-prefixed
//  representative string, or a generated placeholder image/view — see each
//  category file for details.
//

import UIKit
import GBV3AlertModal

/// One demo-able dialog shape: a display `name`/`category` for the gallery
/// list UI, plus a `make` factory that builds a fresh `SampleAlertModal`
/// (fresh, because `GBAlertModal` instances are one-shot presentations).
struct DialogEntry {
    let name: String
    let category: String
    let make: () -> SampleAlertModal
}

enum DialogCatalog {
    /// All 26 shapes from the catalog, in catalog order (cross-cutting first,
    /// then feature areas in the order they first appear in the spec).
    static let entries: [DialogEntry] =
        crossCuttingEntries
            + worksheetEntries
            + genieClassEntries
            + campaignEntries
            + workingSpaceEntries
            + badgeEntries

    /// A no-op completion handler shared by every factory — this is a demo,
    /// there is nothing to do with the resulting `ActionType`.
    static let noopCompletion: (GBAlertModal, GBAlertModal.ActionType) -> Void = { _, type in
        print("[DialogCatalog] dismissed with action: \(type)")
    }

    /// Generates a solid-color placeholder `UIImage`, used for the `[API]`
    /// dynamic banners/art the catalog says are resolved per-record at
    /// runtime (`badge.localImageName`) and are not among the 12 static
    /// assets copied in Task 1.
    static func placeholderImage(color: UIColor, size: CGSize = CGSize(width: 256, height: 168)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
