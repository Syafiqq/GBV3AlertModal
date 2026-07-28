# Finding for design review: V3AlertModal primary button flips hue on press

**Date:** 2026-07-28
**Surfaced by:** building the SwiftUI prototype with the *real* Geniebook colour tokens (not approximations).
**Status:** needs designer confirmation — possible bug in the shipped UIKit theme, not a prototype issue.

## Observation

The primary (oblique) button in `Presentation.UiKit.V3AlertModal`'s real theme changes **hue** when
pressed — orange at rest, blue while held — rather than darkening within the same hue as a pressed
state normally would.

From the distribution app
(`Common/Common/Custom/Components/AlertModal/V3AlertModal+GBV3AlertModal.swift`,
`obliqueBottomLeftTheme`):

| State | Colour | Value |
|-------|--------|-------|
| Un-pressed | `UIColor.Genie.accentSecondaryDark` | **`0xF7941E`** (orange) |
| Pressed | `UIColor(netHex: 0x038CD5)` | **`0x038CD5`** (blue) |
| Disabled | `UIColor.Genie.borderLight` | `0xB4B4B4` (grey) |
| Shadow | `UIColor.Genie.orangeMandarin` | `0xE57B41` (orange) |

So a tap animates orange → blue → orange. The rest-state orange + orange shadow read as an
intentional brand look; the **blue pressed state is the anomaly**.

## Why it's flagged

- A pressed state that swaps hue (orange→blue) is unusual; the convention is a darker/lighter shade
  of the *same* hue (e.g. a darker orange). Blue here looks like a copy-paste or a stale token.
- It's easy to miss in the UIKit app (pressed state is transient), but it's real and shipping.

## Recommendation

Designer to confirm intent. If unintended, the likely fix is to set `pressedColor` to a darkened
orange (a pressed shade of `accentSecondaryDark 0xF7941E`) rather than `0x038CD5`. This is an
**app-side** change in `V3AlertModal+GBV3AlertModal.swift` — the GBV3AlertModal library and the
SwiftUI prototype only *consume* the theme.

## Prototype note

The SwiftUI prototype (`Examples/.../SwiftUI/ModalTokens.swift`) transcribes these values
**faithfully**, including the hue-flip, so the prototype is not the place to "fix" it — it should
track whatever the real theme becomes once this is resolved.
