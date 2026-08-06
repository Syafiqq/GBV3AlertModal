# Brief — Pass 5: retire UIKit, and let Swift 6 hold the line

**Status: NOT STARTED.** Written 2026-08-07 at the end of the Pass 4 session, to be picked up next
session. Direction doc: `2026-08-05-backend-independence.md` (§5's Pass 5 entry, §6a's "ready is the
finish line", §6's note that the differential gate has an end date).

---

## 0. What is already true, measured — read this before planning anything

**Five statements in this spec family have been measured false**, four corrected in Pass 1's §0 and
one in Pass 4 (§3d: the bespoke views were never delegating). Every one was a description of the
boundary that nothing re-checked. This section exists so that this brief does not become the sixth.

Everything below was measured on 2026-08-07, at commit `2923d8a`.

### The module is ALREADY in Swift 6 language mode

`Package.swift` is `// swift-tools-version: 6.0`, with a comment stating the consequence: "tools 6.0
=> Swift 6 language mode is the default for all targets (strict concurrency = errors)." There is no
migration to perform. **Do not scope this pass as a Swift 6 migration.**

What Swift 6 *does* give this pass is a load-bearing test of whether the retirement actually worked —
see §2.

### The module has exactly ONE strict-concurrency escape hatch, and it is UIKit's

```
Library/.../GBV3AlertModal.swift:4
nonisolated(unsafe) public var globalProperties = GBAlertModal.Properties()
```

That is the entire list. Grepped for `@unchecked Sendable`, `@preconcurrency` and
`nonisolated(unsafe)` across `Sources/`: two hits, both the comment and the declaration above.

**So "the SwiftUI half is Swift 6 clean" is not an aspiration — it is already true, and the one blot
on the module belongs to the half being retired.** That is the cleanest available definition of done
for this pass, and it is checkable in one grep.

### The remaining UIKit surface in `SwiftUI/` is an enforced allow-list

`SwiftUIPurityTests` (added in Pass 4) names it and fails both when it grows and when an entry goes
stale:

| file | why | fate |
|---|---|---|
| `ModalFont`, `ModalTokens` | measurement stays on `UIFont` by measurement, not choice (§3b); `ModalTokens` derives from `Properties`, the app's live API | **permanent** |
| `AttributedTextBridge` | re-scopes attributes between SwiftUI's and UIKit's scopes — naming both is its job | permanent while `Properties` is |
| `SwiftUIModalRenderer` | see §3 | **this pass** |

`AlertModalScaffold.swift` was on that list until Pass 4 found it importing UIKit and using zero UIKit
symbols. Expect more of that: a dead import is how an allow-list becomes a fiction.

### The public UIKit-typed API of the SwiftUI half is 6 entry points

All on `SwiftUIModalRenderer`:

1. `init(alertProperties:popupProperties:)` — `GBAlertModal.Properties`
2. `register(style:properties:)` — `GBAlertModal.Properties`
3. `properties(for:)` — returns `GBAlertModal.Properties?`
4. `Presentation.properties` — `GBAlertModal.Properties`
5. `Presentation.onAction` — `(GBAlertModal.ActionType) -> Void`
6. `Factory` typealias — `(GBAlertModal.Properties?, GBAlertModal.DataHolder)`

`ModalTokens.init(from: GBAlertModal.Properties)` also names one and is **not** a gap: it is the
UIKit path's own derivation, with `init(from: ModalProperties)` beside it.

`SwiftUIAlertModal`, `AlertModalScaffold` and all five bespoke views are already clean.

### The second coupling: the shared `DataHolder`

`SwiftUI/` calls `UIKitModalRenderer.*Holder.make` **17 times**. `DataHolder` carries `UIImage?`
twice and `UIView?` once, is **not** `Sendable`, and every holder factory is `@MainActor`.

This was kept **on purpose** (Pass 3, D4): it is what makes both backends provably resolve
identically. Its justification expires with the differential gate and not before.

---

## 1. The goal, stated so it can be checked

§5's finish line is one sentence with two halves, and they are at different distances:

- **"A caller never has to name a UIKit type."** Six entry points away. No open design questions.
- **"A future module split is a manifest edit rather than a refactor."** Not reachable while the
  SwiftUI renderer builds a `UIImage`-carrying `DataHolder` 17 times.

**Both halves are in scope for this pass.** Doing only the first leaves the module permanently
unsplittable, and the second's blocker is a decision that becomes retractable in this pass and never
again.

§6a still governs: **"ready" is the finish line, not "deleted."** UIKit stays present, compiling and
untouched. Success is that nothing in `SwiftUI/` reaches for it except the three permanent entries
above, and that deleting `Executor/` + `Components/` + `GBAlertModal*.swift` would be a manifest edit.

---

## 2. The Swift 6 angle, and why it is the acceptance test rather than the work

Three facts compose into something useful:

1. `GBAlertModal.resolve` is `nonisolated` — deliberately, and its doc says why: "genuinely pure
   (value inputs only, no main-actor state), so it is callable off the main actor."
2. Reaching it on the SwiftUI path requires a `DataHolder`.
3. Every holder factory is `@MainActor`.

**So `resolve`'s `nonisolated` promise is currently unreachable from the SwiftUI half.** The type
system already knows the coupling is there; nothing has asked it.

That makes the acceptance test for this pass a compile-time one rather than a matter of judgement:

> **After the pass, a SwiftUI presentation must be resolvable off the main actor.**

Write it as a `nonisolated` function — or better, an `actor` — that takes a descriptor and
`ModalProperties`, resolves, and derives `ModalTokens`, with no `await` and no `@MainActor`. If that
compiles, the UIKit coupling is genuinely gone; if it does not, the compiler names the file. This is
strictly better than an import-counting check, which is why it should exist *in addition to*
`SwiftUIPurityTests` rather than instead of it.

Two corollaries worth deciding early:

- **`ModalDescriptor: Sendable` already holds**, which is why `ModalImage` carries an asset name and
  not a `UIImage`. The SwiftUI-native holder replacement must preserve that.
- **Deleting `globalProperties`' `nonisolated(unsafe)` is NOT this pass's job.** It is UIKit's, it is
  public API, and §6a forbids touching it. The pass's claim is narrower and still worth making: *the
  SwiftUI half needs no escape hatch, and the module's only one is on the half being retired.*

---

## 3. The plan, in forced order

Steps 1–3 are recoverable. Step 4 is not. Do not reorder them.

### 1. Split `DifferentialGeometrySupport.swift` (974 lines) — refactor only, no deletions

It is **two things wearing one filename**, and only one of them dies:

- **SwiftUI measurement machinery** — `ProbeHost`, `Sink`, `host`, `landscapeHost`, `makeWindow`,
  `pump`, `teardown`, `tolerance`, `swiftUIFrames`, and the 15 `Shape` fixtures. `BespokeBannerColumnTests`
  already uses six of these for pure SwiftUI measurement, and step 2 needs all of them. **Keeps living**,
  move to `SwiftUIGeometry.swift`.
- **The comparison half** — `uiKitFrames`, `makeUIKitModal`, `uiKitLayerVisuals`, `compare`, `Verdict`,
  `hugWidthElements`. Dies in step 4.

Green before and after, as its own commit. A refactor and a deletion in one diff is how you lose track
of which one broke something.

### 2. Record the golden pins, WHILE THE GATE IS STILL GREEN ⚠️

Today's absolute pins are **7 assertions covering measurement functions only** —
`contentMaxWidth`, `titleMinimumScaleFactor`, `subtitleFloorHeight`, `textHeight` ×2,
`titleFloorHeight` ×2 (`TitleSubtitleTruncationTests.test_theMeasurementsThemselves_arePinnedAbsolutely`).
They cover **none** of the card geometry the gate proves.

Record the gate's own SwiftUI-side numbers as absolute pins: **15 shapes × 7 probe elements**
(`card`, `banner`, `title`, `subtitle`, `primaryButton`, `secondaryButton`, `closeButton`), in both
orientations wherever the gate runs both, plus the layer visuals. This is mechanical — the gate
already computes exactly these numbers.

**The objection, and the answer.** §6 is emphatic that recorded baselines failed here before: *"a
recorded snapshot can only detect drift FROM ITSELF — never wrong-but-consistent design."* True, and
it is why the gate exists. But that failure was recording an **unverified prototype**; recording a
state the live comparison has just certified is a different act, and §6 already sanctions it: *"Its
measurements — the geometry rules, the truth table, the divergence catalogue — outlive it as
documentation of what the shipping dialog did."*

What is genuinely given up is the ability to detect drift **in UIKit**. That is acceptable precisely
because UIKit is frozen and about to be inert — and it is the only thing being given up, so say so
in the commit rather than letting a reader discover it.

### 3. Mutation-verify the pins ALONE, with the gate switched off

The step people skip. Disable the gate (do not delete it yet), then re-run the Pass 1 mutation set
plus at least one card-geometry mutation, and confirm the pins catch what the gate caught:

| mutation | must fail |
|---|---|
| `titleMinimumScaleFactor` 0.75 → 0.70 | the measurement pins (Pass 1 proved the gate alone could NOT see this — 517/518 passed) |
| `ModalTokens.contentMaxWidth` +20 | the card + every row pin |
| `obliqueOffset` (−3,3) → (0,0) | the primary-button pin, and the layer-visual pin |
| a row's trailing gap made unconditional | the shapes Pass 2 added |

If any of these survives, the pins are not yet a replacement and step 4 must wait. **Record the
result in the commit either way** — this is the evidence that the net was in place before it was
needed.

### 4. Delete the gate

`DifferentialGeometryTests.swift` (1437 lines, 46 tests) and the comparison half of the support file.

**Not** `RendererParityTests` — see §4, D6.

### 5. Lift the `Factory` constraint, move the 6 entry points

`SwiftUIModalRenderer.Factory` is deliberately source-identical to `UIKitModalRenderer.Factory`, and
that identity is asserted structurally by the parity suite (`RendererParityTests`, and
`RendererFixtures`' *"the two branch bodies are LITERALLY THE SAME EXPRESSION"*). **That is the whole
reason Pass 3c could not finish the job.** Once the geometry gate is gone and the parity suite is
reduced (D6), the constraint lifts and the six entry points become mechanical.

### 6. Give the SwiftUI half its own holder

Replace the 17 `UIKitModalRenderer.*Holder.make` calls. The replacement must be `Sendable` and carry
no `UIImage`/`UIView` — descriptors already prove this is possible (`ModalImage` is an asset name).
This is what makes §2's acceptance test compile, and it is the half of §5's finish line that is
otherwise never reached.

---

## 4. Decisions taken into this pass

Carried from the decision list produced at the end of the Pass 4 session. **Two are still open** and
are marked.

| | decision | status |
|---|---|---|
| **D1** | Split the support file before deleting anything | recommended, uncontested |
| **D2** | Convert the gate's SwiftUI numbers into absolute pins, before deletion | **OPEN — the whole risk of the pass** |
| **D3** | The order in §3 is forced; step 3 is not optional | recommended |
| **D4** | Retire the shared `DataHolder` in this pass, not later | **OPEN — decides whether the module can split** |
| **D5** | Move the 6 renderer entry points; leave `Presentation.onAction` alone (`ActionType` is a 3-case enum, UIKit-*namespaced* not UIKit-*typed*; renaming is churn for a spelling) | recommended |
| **D6** | `RendererParityTests` survives, REDUCED. It tests renderer *behaviour* (present/dismiss/update/route/resolve-once), not geometry — a different gate that shares the word "parity". Keep the file, drop the UIKit arm | recommended |
| **D7** | No deletions outside `SwiftUI/` and the gate. UIKit stays, and so does the example app's UIKit gallery — once the gate's measurements become pins, that gallery is the only remaining live record of what the shipping dialog looked like | recommended |

**D2's alternative, stated fairly:** keep the gate forever and accept that `SwiftUIModalRenderer`
never sheds its six UIKit entry points. That is coherent — it is simply a different goal than §5's,
and choosing it should be explicit rather than arrived at by not deciding.

**D4's alternative:** stop at "no caller names a UIKit type" and leave the shared holder. Cheaper, and
it forfeits "module split is a manifest edit" permanently, because the justification for removing the
holder only exists while the gate is being retired.

---

## 5. What this pass must NOT do

- **Touch UIKit.** `GBAlertModal*`, `Components/`, `Executor/` stay frozen. §7.
- **Touch `geniebook-student-ios`.** Reference only, never a target. §6a.
- **Remove anything from `Properties`,** including `bannerFixedHeight`. It is dead and it is public
  and the consumer is not ours to edit.
- **Scope itself as a Swift 6 migration.** The module is already there (§0).
- **Delete the gate before §3 step 3 passes.** The one irreversible act in the sequence.

---

## 6. How the next session should start

Do not trust this document. Re-measure §0 first — it is four greps and a `cat Package.swift`, and
five of its predecessors' claims did not survive contact with the code:

```bash
cat Package.swift | head -3                                   # still tools 6.0?
grep -rn "@unchecked Sendable\|@preconcurrency\|nonisolated(unsafe)" \
  --include="*.swift" Library/GBV3AlertModal/Sources          # still just globalProperties?
grep -rn "Holder.make" Library/GBV3AlertModal/Sources/GBV3AlertModal/SwiftUI/ | wc -l   # still 17?
./Script/test-lib.sh                                          # still green? (552/0 at 2923d8a)
```

Then run `SwiftUIPurityTests` and read its allow-list — it is the live version of §0's table and, by
construction, the one that cannot have gone stale.
