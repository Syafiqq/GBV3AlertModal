# Follow-up brief: activate natural-aspect banners in the Geniebook app

**Status:** not scheduled — pick up when convenient.
**Repo:** `geniebook-student-ios-distribution` (the consumer). NOT this library.
**Depends on:** GBV3AlertModal library change `fix: render banner at natural image aspect ratio when bannerRatio is nil` (commit `229e9e2` on `refactor/decompose-modal`) — must be released/consumed first.

## Why

The library now renders a banner at the **image's own aspect ratio** when `bannerRatio == nil`
(fills the card width, height derived from the image; `bannerMaxHeight` still caps it). When
`bannerRatio` is a number, it keeps the old forced-ratio behavior (unchanged).

The Geniebook preset currently hardcodes `bannerRatio: 1` (square). So **16:9 (and any
non-square) banners still render as a squeezed square in the app** — the library fix does
nothing for the app until the preset opts in.

## The change (one line)

File: `Common/Common/Custom/Components/AlertModal/V3AlertModal+GBV3AlertModal.swift`,
in the static `properties` builder (~line 24):

```swift
// before
bannerRatio: 1,
// after
bannerRatio: nil,   // render each banner at its natural aspect ratio
```

## Consider alongside

- **`bannerMaxHeight`**: with `bannerRatio: nil`, a *tall* banner (e.g. 9:16) can get very tall
  and eat the card, especially in landscape. The library caps it via `bannerMaxHeight`, but the
  Genie preset currently leaves that nil. Set a sensible `bannerMaxHeight` (e.g. ~120–160pt,
  tune to the design) so tall banners don't push content. The library's stress tests used a
  small cap purely to fit a deliberately tight test card — production wants a design-driven value.
- **Per-call override**: call sites that DO want a fixed crop can still pass an explicit
  `bannerRatio` via `properties.copy(bannerRatio: ...)`; only the default changes.

## Risk / test

- Low risk, opt-in. Only affects modals that show a banner.
- The library's `BannerAspectStressTests` already prove 16:9 / 9:16 / 1:1 × portrait/landscape
  render correctly with content intact. In the app, smoke-test the real banner screens
  (Streak, Badges, NPS, worksheet generators) in both orientations after flipping the preset.

## Origin

Surfaced during the GBV3AlertModal decomposition/robustness work (2026-07-21). The user
confirmed the app ships 16:9 banners, making the pre-existing forced-square a real bug.
