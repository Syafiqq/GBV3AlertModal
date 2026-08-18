# Modal target independence

The package target split was verified on 2026-08-19 with Swift 6 language mode and an iPhone 17
simulator. The authoritative CI entry point is:

```sh
Script/test-swiftui-independence.sh
```

The disposable proof graph contains only these products and production targets:

| Product/target | Direct production dependency |
| --- | --- |
| `GBV3AlertModalCore` | None |
| `GBV3AlertModalSwiftUI` | `GBV3AlertModalCore` |

There is no package dependency declaration in that graph. In particular, SnapKit is neither
resolved nor linked. The proof deletes the UIKit, Migration, and compatibility source directories,
runs the Core and SwiftUI tests, and builds `GBV3AlertModalSwiftUIExample`. A temporary injected
SwiftUI-to-UIKit dependency is rejected before the real builds run.

The full coexistence graph retains five products. Core has no UI-framework edge; SwiftUI depends
only on Core; UIKit depends on Core and SnapKit; Migration alone imports both backends; the umbrella
product exists only for source-compatible migration.

## CI sequence

```sh
git diff --check
Script/test-lib.sh
Script/test-example.sh
Script/test-swiftui-independence.sh
```

Each test entry point fails when an expected suite reports zero executed tests. The example suite
separates contracts, UI smoke, and the standalone SwiftUI build. Run one stage while
diagnosing a failure with:

```sh
EXAMPLE_TEST_STAGE=contracts Script/test-example.sh
EXAMPLE_TEST_STAGE=ui-smoke Script/test-example.sh
EXAMPLE_TEST_STAGE=swiftui-build Script/test-example.sh
```

Each stage has a bounded timeout. Only a recognized simulator-infrastructure failure is retried,
once, after restarting and waiting for the selected simulator. UIKit/SwiftUI visual comparison is
performed manually in the gallery rather than enforced through platform-sensitive image baselines.

## Snapshot review

The package retains focused Migration snapshots for library regressions. The example gallery does
not keep full-catalog image baselines; compare its paired UIKit and SwiftUI entries manually when
reviewing native rendering, accessibility, or Dynamic Type behavior.

## Consumer migration and retirement checklist

- Add `GBV3AlertModalCore` and `GBV3AlertModalSwiftUI` to native SwiftUI consumers.
- Replace `import GBV3AlertModal` with imports of those focused modules.
- Keep UIKit properties and attributed-string conversion at Migration boundaries only.
- Migrate window/controller presentation separately because it remains integration behavior.
- Require the independence script to stay green before and after each consumer migration.
- Remove the umbrella, Migration, UIKit, SnapKit, and comparison tests only after no consumer uses
  them.
- Treat any Core or SwiftUI production edit needed by that deletion as a failed retirement check.
