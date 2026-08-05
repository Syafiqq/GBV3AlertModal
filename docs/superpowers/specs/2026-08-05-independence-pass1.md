# Brief — Backend independence, Pass 1

**Status:** open, nothing started. **Branch:** `feat/modal-executor-capability` @ `ef7db2b`, clean.
**Library suite:** 518 / 0. **Example app:** green.

**Read first:** `2026-08-05-backend-independence.md` — the direction and the five-pass path. This
brief is Pass 1 only.

---

## 1. The destination, in one line

**Keep UIKit. Mature SwiftUI. Delete UIKit.** SwiftUI is the product; UIKit is legacy.

Every *other* document in this module predates that decision and assumes parity-with-UIKit is the
goal. It is a checkpoint, not the destination. Three consequences:

- The differential gate is a **migration tool with an end date**, not the permanent proof.
- **"UIKit is frozen" now means legacy, not canonical.** Don't change it; don't treat it as truth.
- **Reproducing a UIKit defect in SwiftUI is anti-value.** A divergence is a question — "is UIKit
  right here, or merely first?" — not automatically a SwiftUI bug.

## 2. What Pass 1 is

Remove the SwiftUI half's *cosmetic* UIKit dependencies. No architectural change, no new public
config type (that is Pass 3), no touching the descriptor gap (Pass 2).

Five files in `Sources/GBV3AlertModal/SwiftUI/` import UIKit. After Pass 1, only the ones that are
structurally justified should.

| file | uses | Pass 1 action |
|---|---|---|
| `ModalTokens.swift` | `UIFont` (×2), `UIMinMaxEdgeInsets` | **replace the `UIFont` twins with CoreText measurement** — see §3 |
| `SwiftUIModalRenderer.swift` | `UIScreen`, `UIKitModalRenderer` | **`UIScreen` → environment**; leave the renderer delegation (Pass 4) |
| `AlertModalScaffold.swift` | `NSLayoutConstraint.Axis` | only the bridge extension remains; **leave it** until Pass 3 gives SwiftUI its own resolver |
| `AttributedTextBridge.swift` | `NSAttributedString` | leave — legitimate bridge while the holder path exists |
| `SwiftUIAlertModal.swift` | `NSAttributedString`, `UIKitModalRenderer` | leave — same reason |

So Pass 1 is genuinely **two changes**: measurement, and orientation.

## 3. The `UIFont` twins — the real work

`ModalTokens` carries two measurement twins:

```swift
public var titleUIFont: UIFont = .systemFont(ofSize: 24, weight: .bold)
public var subtitleUIFont: UIFont = .systemFont(ofSize: 16, weight: .regular)
```

**They are NOT a vocabulary leak — do not just delete them.** They exist because SwiftUI's `Font`
is opaque and cannot report a line height, and the shrink floor needs a real measurement:

- `ModalTokens.swift:~331` → `ModalLayout.titleFloorHeight(text, font: titleUIFont, width:)`
- `ModalTokens.swift:~346` → `ModalLayout.subtitleFloorHeight(font: subtitleUIFont)`

Pinned by `test_theStandardTitleFontAndItsMeasurementTwin_agree` and friends in
`TitleSubtitleTruncationTests`.

**CoreText can measure without UIKit.** `CTFont` is CoreText, `CGFloat` is CoreGraphics — neither is
UIKit. The job is to express the same floors through CoreText (or `NSAttributedString` +
`CTFramesetter`, which is Foundation/CoreText, not UIKit) and drop the public `UIFont` surface.

Note `ModalTokens.swift:~878` already has `Font.init(_ uiFont: UIFont)` going the *other* way via
`CTFont` — `UIFont` is toll-free bridged to `CTFont`, so the conversion machinery is half there.

**Whatever you do, the floors must not move.** The shrink floor is shared with UIKit and pinned by
the differential gate; a changed number is a regression, not an improvement.

## 4. `UIScreen` — small, and a real bug

`SwiftUIModalRenderer.swift:~534`:

```swift
static var isLandscape: Bool {
    let bounds = UIScreen.main.bounds
    return bounds.width > bounds.height
}
```

Its own doc concedes the value is *"only consumed for `contentWidth`, which every Genie preset
states identically for both orientations."* So it reaches for a global UIKit singleton to compute
something that does not vary — and on iPad multitasking it is simply wrong, because `UIScreen.main`
is the screen, not the window.

## 5. Where the code is

| what | where |
|---|---|
| SwiftUI backend | `Library/GBV3AlertModal/Sources/GBV3AlertModal/SwiftUI/` (10 files) |
| Shared, already UIKit-free | `Sources/GBV3AlertModal/Core/` — enforced by `CorePurityTests` |
| UIKit backend (FROZEN) | `GBAlertModal+*.swift`, `Support/ModalLayout.swift` |
| The differential gate | `Tests/GBV3AlertModalTests/SwiftUI/DifferentialGeometry{Tests,Support}.swift` |
| Measurement floors | `Support/ModalLayout.swift` — `titleFloorHeight`, `subtitleFloorHeight` |

## 6. How to verify

```
./Script/test-lib.sh        # seconds — must stay 518 / 0
./Script/test-example.sh    # ~25 minutes — run before landing
```

`Script/test-example.sh` already retries the known simulator flake once. **Read §7 before trusting
any failure.**

## 7. Traps this session sprang — read before starting

Every one of these cost real time in the session that produced the current state.

- **`** TEST FAILED **` with ZERO test cases executed is a simulator fault, not a result.** Happened
  four times (SpringBoard crash, result-bundle IO fault, boot timeout). `xcrun simctl shutdown all`
  clears it. **Always confirm test cases actually ran** by counting `Test case '…'` lines — never
  trust the exit code alone.
- **A long `xcodebuild` in a pipe gets killed and takes the buffered output with it.** Three runs
  died producing zero bytes. Use `nohup xcodebuild … > /tmp/x.log 2>&1 &` and poll the file.
- **Reading a signature is not reading the code.** `titleUIFont` looked like a UIKit leak from its
  type alone; it is load-bearing measurement. Two other conclusions this session were wrong for the
  same reason.
- **Grepping the working tree is not checking `git status`.** A whole uncommitted changeset was
  mistaken for landed work because the tombstone comments were there.
- **Comparing against a commit INSIDE the change set proves nothing.** Eight snapshot failures were
  called "pre-existing" on a comparison against the very commit suspected of causing them. The
  right baseline was the commit before the work started.
- **Mutation-verify every new or changed test.** Four tests on this branch could not fail — one
  containment assertion stayed green through the exact regression it claimed to guard. Revert the
  production change, confirm red, restore.
- **A comment claiming a test exists must be true.** Do not name a test file you have not written.
- **Snapshot tests must pin their appearance** — and `window.overrideUserInterfaceStyle` **silently
  does nothing**, because `assertSnapshot` re-hosts the view in its own window. Only
  `.preferredColorScheme` on the view tree survives. See `SwiftUIAlertModalSmokeTests.render`.
- **An ambient `.foregroundColor` on an `AttributedString` binds the SwiftUI attribute scope**,
  which the UIKit renderer does not read — it draws unstyled. Use per-run attributes.
- **Three claims of impossibility in this module turned out FALSE when probed.** "The height must be
  REACHED, not merely bounded"; "no closed form reaches the landscape residual"; and a third about
  the column rule that was true but only provable by measuring. **Measure before designing.**

## 8. What already exists — do not re-derive it

- Two closed-form banner geometry rules, fitted to 30+ measurements, pinned against real Auto Layout
  in `BannerGeometryTruthTests`.
- 19 shape×orientation combinations agreeing element-for-element at 0.5pt.
- Six divergences measured to the point, each rendered on BOTH backends in the example gallery for
  eyeballing (`Gallery/DivergenceCatalog.swift` + `SwiftUI/SwiftUICatalog+Divergences.swift`).
- A structural guard: `assertAgrees` fails if an exclusion set leaves nothing comparable.

## 9. Out of scope for Pass 1

- **The descriptor gap** (Pass 2) — nine `notRenderable` gallery entries, the `showsPrimary`
  divergence, and all four bespoke-view delegations are one problem: `ModalDescriptor` is a
  `Sendable` value that cannot carry a `UIView`, cannot express "no primary button"
  (`AlertDialog.primary` is a non-optional `String`), and has no presentation-state channel.
- **The SwiftUI-native config type and resolver** (Pass 3). Its shape is decided — same field names
  as `Properties`, SwiftUI types, `bannerFixedHeight` deliberately dropped. See §3a of the direction
  spec.
- **Native bespoke views** (Pass 4) and **retiring UIKit** (Pass 5).
- **Changing UIKit.** Still frozen.
