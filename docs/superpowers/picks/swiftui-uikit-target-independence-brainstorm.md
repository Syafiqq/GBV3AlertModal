# SwiftUI/UIKit Target Independence — Brainstorm Log

**Source:** `docs/superpowers/specs/2026-08-18-swiftui-uikit-target-independence.md`
**Mode:** autonomous; recommended answers are auto-accepted under the lazy/away rule.

## Decision 1 — Migration shape

Which implementation shape should turn the current monolithic package into independent backends?

- **A. Boundary-first staged extraction (Recommended):** neutralize shared vocabulary and remove backend coupling inside the existing target, then move files, declare targets, split tests/resources, and finally prove deletion.
- **B. Manifest-first split:** declare all targets immediately and repair compiler failures across the new boundaries.
- **C. Parallel replacement:** build new Core and SwiftUI targets beside the monolith, then switch consumers and remove duplicate implementations.

Recommendation rationale: A follows the brief's forced order, keeps each failure attributable, minimizes duplicate logic, and gives every stage a green build and atomic commit boundary.
