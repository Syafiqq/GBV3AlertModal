# ``GBV3AlertModal``

Build modal flows with independently consumable Core, SwiftUI, and UIKit products.

## Overview

The package exposes focused products so a native SwiftUI consumer does not need the UIKit backend
or SnapKit:

- `GBV3AlertModalCore` owns descriptors, resolution, execution, and coordination.
- `GBV3AlertModalSwiftUI` owns native SwiftUI configuration, resources, views, and rendering.
- `GBV3AlertModalUIKit` owns the legacy UIKit renderer and its SnapKit dependency.
- `GBV3AlertModalMigration` is the only integration product that knows both backends.
- `GBV3AlertModal` is a transitional compatibility product that re-exports the complete legacy
  surface.

New SwiftUI consumers should depend on and import `GBV3AlertModalCore` and
`GBV3AlertModalSwiftUI`. Existing consumers can remain on `GBV3AlertModal` while they migrate.

## Verify independence

Run `Script/test-swiftui-independence.sh` from the repository root. The command creates a disposable
copy, removes UIKit, Migration, compatibility, and their tests, applies the checked-in SwiftUI-only
manifest, and then builds/tests Core and SwiftUI plus the standalone SwiftUI example. It also proves
that its graph gate rejects a deliberately injected SwiftUI-to-UIKit edge.

Use `Script/test-lib.sh` for all backend-owned package suites and `Script/test-example.sh` for the
mixed compatibility gallery and its exactly-70-entry SwiftUI catalog contract.

## Retire the compatibility backend

Before removing UIKit, Migration, compatibility, or SnapKit:

1. Move each consumer from the umbrella product/import to the focused products it uses.
2. Replace legacy `GBAlertModal.Properties` values with native `ModalProperties` at SwiftUI call
   sites; keep conversion at remaining coexistence boundaries.
3. Confirm no Core or SwiftUI source imports UIKit, Migration, compatibility, or SnapKit.
4. Run all three verification scripts and archive the independence summary in CI.
5. Delete UIKit, Migration, compatibility, SnapKit, and transitional comparison tests without
   editing Core or SwiftUI production files. Any required production edit violates the retirement
   invariant and should block removal.
