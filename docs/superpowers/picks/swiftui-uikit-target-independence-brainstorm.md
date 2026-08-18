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

**Answer:** A. Preserve `GBV3AlertModal` as an explicit compatibility umbrella during coexistence. *(auto-accepted — lazy/away)*

## Decision 3 — Neutral inset vocabulary

How should the misleading but Foundation-only `UIMinMaxEdgeInsets` type cross the Core boundary?

- **A. Add `MinMaxEdgeInsets` in Core and keep a deprecated UIKit-side typealias (Recommended):** migrate neutral and SwiftUI code to the new name while retaining source compatibility for legacy UIKit callers during coexistence.
- **B. Move `UIMinMaxEdgeInsets` unchanged into Core:** avoid API churn now, despite leaving a UIKit-prefixed name in the platform-neutral module.
- **C. Replace it separately in each backend:** use SwiftUI `EdgeInsets` and a UIKit-local min/max type, accepting duplicated range semantics and adapters.

Recommendation rationale: A makes Core vocabulary honest without coupling backend extraction to a consumer flag day; the alias can disappear with UIKit/Migration retirement.

**Answer:** A. Add Core `MinMaxEdgeInsets` with a deprecated UIKit-side `UIMinMaxEdgeInsets` typealias. *(auto-accepted — lazy/away)*

## Decision 4 — Font scaling semantics

What Dynamic Type contract should the UIKit-free `ModalFont` expose?

- **A. Explicit scaling policy with fixed-size default (Recommended):** model `.fixed` and an opt-in semantic relative-text-style policy; preserve current preset geometry by default and test both paths.
- **B. Always scale:** interpret every system and custom font relative to a Dynamic Type text style, accepting broad geometry and snapshot changes.
- **C. Fixed fonts only:** preserve current behavior and leave Dynamic Type support to a future API redesign.

Recommendation rationale: A avoids falsely promising scaling for existing fixed custom fonts, keeps migration predictable, and still makes accessibility behavior explicit and extensible rather than accidental.

**Answer:** A. Use an explicit scaling policy with a fixed-size default and opt-in semantic scaling. *(auto-accepted — lazy/away)*

## Decision 5 — Design approval

Should the standalone design proceed with the following architecture?

- Core owns descriptors, executor/coordinator protocols and state, `ResolvedModal`, the single pure resolver, `MinMaxEdgeInsets`, and resource identifiers—but no rendering framework types.
- SwiftUI owns `ModalProperties`, descriptive `ModalFont`, token derivation, SwiftUI-scoped attributed content, native views/renderers/host, and its own bundle resources.
- UIKit owns all legacy modal/controller/window/layout implementation, UIKit resources, and the only SnapKit dependency.
- Migration owns every cross-backend conversion and coverage test; a compatibility shim preserves `import GBV3AlertModal` during coexistence.
- Boundary-first commits neutralize dependencies before physical moves and target declarations; test suites then split by ownership, followed by a manifest-variant deletion proof.

Options:

- **A. Approve this design (Recommended):** write it as the standalone design and derive the implementation plan from it.
- **B. Revise boundaries:** reopen ownership or compatibility decisions before planning.
- **C. Defer:** retain the source brief without producing an execution plan.

Recommendation rationale: A directly satisfies the release gate—UIKit and Migration can later be removed without editing Core or SwiftUI production files—and preserves the brief's forced implementation order.

**Answer:** A. Approve the proposed design. *(auto-accepted — lazy/away)*
