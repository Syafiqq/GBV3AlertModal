# Snapshot comparison and self-contained HTML report brief

## Objective

Build a repeatable visual-comparison pipeline for migrations, rewrites, shared components, and cross-platform implementations.

The pipeline produces two artifacts:

1. deterministic full-context PNG snapshots checked by automated tests;
2. one self-contained HTML report that places the reference and candidate renderings side by side for human review.

Use this approach when pixel diffs alone are too opaque and reviewing individual snapshot files is too slow. The HTML report is a review surface, not a replacement for snapshot assertions.

## The operating model

Keep four concerns separate:

```text
canonical case matrix
        │
        ├── reference renderer ──> immutable PNG export + manifest
        │
        └── candidate renderer ──> tested PNG snapshots
                                      │
                                      ▼
                         validation + HTML assembly
                                      │
                                      ▼
                         self-contained comparison report
```

The matrix defines what must be compared. Renderers only produce evidence for those cases. The report generator validates and presents that evidence; it must not silently invent, omit, or update cases.

## When this pattern is useful

- replacing UIKit with SwiftUI, Views with Compose, or one web component system with another;
- extracting a component from an application into a shared library;
- comparing a legacy implementation with a redesign;
- validating phone, tablet, locale, theme, accessibility, and responsive-layout behavior;
- reviewing a visual change with designers, QA, or engineers who do not run the test suite locally.

It is less useful for animation timing, continuously changing data, or interactions that cannot be represented by stable states.

## Canonical case matrix

Create one machine-readable matrix before writing the report generator. JSON works well because snapshot tests, export validation, and the report can all consume it.

```json
{
  "groups": [
    {
      "name": "Core states",
      "candidatePrefix": "testCoreStates",
      "defaultDevice": "Phone — 390×844 pt",
      "deviceOverrides": {
        "success-tablet": "Tablet — 820×1180 pt"
      },
      "cases": [
        "success-phone",
        "success-tablet",
        "error-multiline"
      ]
    },
    {
      "name": "Responsive widths",
      "candidatePrefix": "testResponsiveWidths",
      "defaultDevice": "Phone — 390×844 pt",
      "cases": [
        "phone-compact",
        "phone-full"
      ]
    }
  ]
}
```

Case keys are durable identifiers. Do not rename them casually: they connect fixtures, snapshot filenames, reference manifests, report rows, and review history.

The matrix should cover product behavior, not every combination mechanically. Include:

- representative real scenarios;
- component variants and important states;
- boundary conditions such as long copy or missing assets;
- phone and tablet layouts;
- light/dark appearance where supported;
- Dynamic Type or browser zoom boundaries;
- LTR and RTL direction;
- features that exist only in the candidate implementation.

Group cases by the question a reviewer is answering. “Responsive widths” is more useful than “Miscellaneous.”

## Deterministic snapshot contract

Define the render environment explicitly. A snapshot name alone is not enough.

For every logical device or viewport, record:

- canvas width and height in logical units;
- display scale or browser device-pixel ratio;
- safe-area or page insets;
- appearance and color scheme;
- locale and layout direction;
- content-size category or font scaling;
- background color;
- animation policy;
- OS, simulator, browser, or rendering-engine version where relevant.

Capture the full page or component host when position and responsive width matter. A tightly cropped component can hide edge collisions, incorrect centering, safe-area mistakes, and maximum-width failures.

Disable animations and timers. Capture a stable final state, never a transition frame.

## Reference renderer and export manifest

Render the reference in its owning project using the real production component. Do not copy the legacy implementation into the candidate project merely to generate convenient images; that removes the source-of-truth guarantee.

Export this structure:

```text
visual-reference/
├── manifest.json
└── images/
    ├── success-phone.png
    ├── success-tablet.png
    └── error-multiline.png
```

The manifest records provenance and makes unsupported cases explicit:

```json
{
  "schemaVersion": 1,
  "source": {
    "repository": "legacy-application",
    "commit": "FULL_GIT_SHA",
    "implementation": "Module.ComponentName",
    "toolchain": "Xcode 26.5",
    "runtime": "iOS 26.5"
  },
  "cases": {
    "success-phone": {
      "status": "captured",
      "image": "images/success-phone.png",
      "device": "phone",
      "canvasPoints": [390, 844],
      "scale": 3,
      "pixelSize": [1170, 2532]
    },
    "phone-full": {
      "status": "unsupported",
      "reason": "Full width is available only in the new component."
    }
  }
}
```

An unsupported row is evidence. It tells reviewers that the case was considered and has no valid opposite rendering. Silently dropping it makes the report look more complete than it is.

Treat imported reference PNGs as immutable inputs. Candidate tests must never overwrite them. A reference update should require a new export, source commit, and visual review.

## Candidate snapshot tests

Render candidate snapshots independently with fixtures mapped to the same case keys.

For SwiftUI/XCTest, the shape is:

```swift
@MainActor
final class ComponentSnapshotTests: XCTestCase {
  func testResponsiveWidths() {
    for fixture in ResponsiveWidthFixtures.all {
      assertSnapshot(
        of: SnapshotHost.fullPage(
          fixture.view,
          device: fixture.device,
          layoutDirection: fixture.layoutDirection
        ),
        as: .image(precision: 1),
        named: fixture.key
      )
    }
  }
}
```

Separate fixture definitions from rendering mechanics. The fixture says what to render; the snapshot host says how to render it deterministically.

Record mode is a deliberate operation:

1. add or change fixtures;
2. run once in record mode;
3. inspect every new image visually;
4. turn record mode off;
5. rerun the same tests in strict comparison mode.

Never leave `record: .all` or its equivalent committed in the test. A recording test can replace evidence instead of detecting a regression.

## Validate before building HTML

The report generator should fail early when:

- the matrix and manifest contain different case-key sets;
- a captured reference points to a missing file;
- a required candidate snapshot is missing;
- an image is not a supported format;
- dimensions disagree with the declared device contract;
- duplicate keys appear;
- a group resolves to zero cases.

Also validate image content where practical. A valid PNG can still be blank. Useful checks include:

- more than one distinct pixel/color region;
- a minimum non-background bounding box;
- expected alpha behavior;
- expected canvas dimensions;
- visible content inside safe margins.

Automated content checks are a guardrail, not a substitute for looking at the first recorded baseline.

## HTML report contract

Generate a static document with one section per matrix group and one card per case.

Each card should contain:

- human-readable case title;
- durable case key;
- device/viewport description;
- image dimensions;
- reference image or explicit unsupported reason;
- candidate image or explicit missing-state message.

The simplest useful layout is side by side:

```html
<article class="comparison-card">
  <header>
    <h2>Phone Full</h2>
    <code>phone-full</code>
  </header>
  <div class="two-up">
    <figure>Reference image or unsupported reason</figure>
    <figure>Candidate image</figure>
  </div>
</article>
```

Make the report self-contained by embedding PNGs as Base64 data URIs:

```python
encoded = base64.b64encode(path.read_bytes()).decode("ascii")
source = f"data:image/png;base64,{encoded}"
```

This creates one portable HTML file that can be attached to a ticket, archived as a CI artifact, or opened without preserving a sibling image directory.

Escape all matrix and manifest text before inserting it into HTML. These files may be repository-controlled, but correct escaping prevents broken markup and makes the generator safe to reuse.

Use responsive CSS so the two columns stack on narrow screens. Preserve image aspect ratio and show images against a neutral or checkerboard surface that makes page boundaries and transparency visible.

## Recommended generator interface

A small Python script is sufficient and avoids a frontend build dependency:

```shell
python3 Scripts/generate_snapshot_comparison.py
python3 Scripts/generate_snapshot_comparison.py --skip-tests
python3 Scripts/generate_snapshot_comparison.py --output .build/reports/comparison.html
```

The default command should:

1. resolve or boot an eligible simulator/browser;
2. run only the relevant snapshot suite;
3. validate the matrix, manifest, and generated snapshots;
4. write the HTML report;
5. print the number of comparisons and output path.

`--skip-tests` should rebuild HTML from existing approved snapshots. It is useful when iterating on report styling, but CI should normally run the snapshots first.

## Test the report generator

The generator is production code for test evidence and deserves focused tests.

At minimum, test that it:

- discovers the exact expected case count;
- preserves matrix ordering and group ordering;
- reports captured, unsupported, and missing sides correctly;
- rejects mismatched manifest/matrix keys;
- embeds images as `data:image/png;base64,...`;
- produces the intended side-by-side structure;
- escapes case names and unsupported reasons;
- writes no external image or script dependencies.

Use temporary directories for missing-file and unsupported-case tests. Reuse a small known-valid PNG fixture instead of manufacturing image bytes in every test.

## CI and review workflow

Recommended CI sequence:

```text
unit tests
  -> snapshot assertions
  -> manifest/matrix validation
  -> HTML generation
  -> publish HTML + snapshot diffs as artifacts
```

On snapshot failure, retain:

- expected image;
- actual image;
- visual diff, if the framework provides one;
- generated HTML report;
- test logs and render-environment metadata.

Do not update baselines automatically in CI. Baseline changes should be made locally or in a controlled recording job, committed, and reviewed like source code.

## Failure modes worth guarding against

### The container is correct but the visible component is wrong

A host view can have the expected 400-point width while the background-bearing component inside it still wraps its content. Assert or snapshot the visible surface, not only its hosting frame.

### Blank snapshots become trusted baselines

A rendering helper can return a valid full-page PNG with zero-height or invisible content. Snapshot frameworks faithfully preserve that mistake. Visually inspect first recordings and add non-background-content validation.

### Cropped snapshots conceal layout defects

A fitted component image cannot prove device-edge margins, safe-area offsets, centering, or maximum width. Use full-page snapshots for responsive and positional contracts.

### Reference and candidate render through the same copied code

This creates agreement without independence. Render each side in the project that owns it and join them only at the artifact/report layer.

### Missing cases disappear

Require exact matrix/manifest key equality. Represent unsupported behavior explicitly with a reason.

### Per-case tolerances hide regressions

Start strict. If renderer differences require tolerance, document one small global policy. Avoid hand-tuned exceptions unless the underlying nondeterminism is understood.

### Report generation mutates evidence

The HTML generator should be read-only with respect to snapshots and references. Its only output is the report file.

## Adoption checklist for another project

1. Choose the reference and candidate implementations.
2. Define logical devices/viewports and deterministic traits.
3. Create the canonical case matrix.
4. Build real fixtures in each owning project.
5. Capture the reference export and provenance manifest.
6. Add candidate full-context snapshot tests.
7. Validate exact key coverage and image files.
8. Build the self-contained HTML generator.
9. Add generator unit tests.
10. Record, visually inspect, and commit initial candidate baselines.
11. Rerun in strict mode.
12. Publish the HTML report as a CI or release artifact.

## Definition of done

- Every canonical key appears exactly once in the report.
- Every supported side has a deterministic, correctly sized PNG.
- Unsupported sides show a reason instead of disappearing.
- Reference provenance includes repository, commit, implementation, and toolchain/runtime.
- Snapshot tests run with recording disabled and pass strictly.
- The HTML file opens without network access or sibling assets.
- Phone/tablet, direction, accessibility, and boundary cases are visibly reviewable.
- A reviewer can understand each difference without opening the test implementation.

