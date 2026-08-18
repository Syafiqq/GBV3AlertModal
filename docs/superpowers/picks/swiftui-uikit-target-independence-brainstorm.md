# SwiftUI/UIKit Target Independence — Brainstorm Log

**Source:** `docs/superpowers/specs/2026-08-18-swiftui-uikit-target-independence.md`
**Mode:** autonomous; recommended answers are auto-accepted under the lazy/away rule.

## Decision 1 — Migration shape

Which implementation shape should turn the current monolithic package into independent backends?

- **A. Boundary-first staged extraction (Recommended):** neutralize shared vocabulary and remove backend coupling inside the existing target, then move files, declare targets, split tests/resources, and finally prove deletion.
- **B. Manifest-first split:** declare all targets immediately and repair compiler failures across the new boundaries.
- **C. Parallel replacement:** build new Core and SwiftUI targets beside the monolith, then switch consumers and remove duplicate implementations.

Recommendation rationale: A follows the brief's forced order, keeps each failure attributable, minimizes duplicate logic, and gives every stage a green build and atomic commit boundary.

**Answer:** A. Boundary-first staged extraction. *(auto-accepted — lazy/away)*

## Decision 2 — Compatibility product

How should the existing `GBV3AlertModal` product behave after the package is split?

- **A. Preserve it as an explicit compatibility umbrella (Recommended):** keep the product name and export Core, SwiftUI, UIKit, and Migration during coexistence; add backend-specific products for new consumers and deletion-proof builds.
- **B. Repoint it to Core + SwiftUI:** make the old product name mean the new default backend, accepting an immediate breaking change for UIKit consumers.
- **C. Remove it:** require every consumer to choose backend-specific products immediately.

Recommendation rationale: A honors the brief's compatibility allowance, separates migration timing from architectural extraction, and gives the SwiftUI-only example a product that proves it does not inherit UIKit or SnapKit transitively.
