# Alert modal snapshot comparison review checklist

Duplicate this file for each review pass. Keep the durable keys unchanged so comments can be traced back to the corresponding HTML comparison and snapshot filenames.

Report command:

```shell
python3 Scripts/generate_snapshot_comparison.py --skip-tests
```

Report output: `.build/reports/alert-modal-snapshot-comparison.html`

Review conventions:

- Check each renderer independently before checking the comparison.
- A supported renderer with no image is a failure, not an acceptable blank.
- `variant-subtitle-customview` uses the SwiftUI custom-subtitle preset and is reviewable on both sides.
- Use “Comment for next feeder” for concrete observations and required follow-ups.
- Leave unresolved items unchecked; do not treat an overall green snapshot suite as visual approval.

Reviewer: <!-- name -->

Review date: <!-- YYYY-MM-DD -->

Source commit: <!-- full SHA -->

Report path or artifact URL: <!-- path/URL -->

Overall handoff notes:

> Add summary, cross-cutting findings, and the recommended next action here.

## 1. `ai-notes-ready-banner`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 2. `badge-detail-popup`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 3. `badge-unlock-multi`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 4. `badge-unlock-single`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 5. `close-button-dismiss`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 6. `credit-deduction-popup`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 7. `database-error-banner`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 8. `date-picker-worksheet`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 9. `divergence-banner-wide-landscape-width`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 10. `divergence-inset-band`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 11. `divergence-ratio-not-artwork-aspect`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 12. `divergence-shows-primary-not-obeyed`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 13. `divergence-tall-uncapped-artwork`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 14. `exit-worksheet-confirm-banner`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 15. `force-update-banner`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 16. `oblique-red-leave-confirm`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 17. `onboarding-trial-banner`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 18. `onboarding-welcome-nobanner`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 19. `permission-denied-settings`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 20. `quiz-begin-banner`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 21. `quiz-info-banner`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 22. `rename-worksheet`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 23. `standard-one-button`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 24. `standard-two-button`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 25. `streak-popup-banner`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 26. `stress-all-none`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 27. `stress-banner-only`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 28. `stress-banner-ultratall`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 29. `stress-banner-ultrawide`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 30. `stress-baseline`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 31. `stress-buttons-horizontal`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 32. `stress-buttons-only`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 33. `stress-close-button-horizontal-wrapped`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 34. `stress-close-button-title`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 35. `stress-maxed-horizontal`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 36. `stress-maxed-vertical`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 37. `stress-maxed-widebanner-horizontal`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 38. `stress-nasty-horizontal-wrapped-no-banner`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 39. `stress-nasty-tallbanner-subtitle`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 40. `stress-nasty-widebanner-horizontal-wrapped`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 41. `stress-no-buttons`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 42. `stress-primary-none`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 43. `stress-primary-wrapped`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 44. `stress-secondary-none`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 45. `stress-secondary-wrapped`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 46. `stress-subtitle-none`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 47. `stress-subtitle-unbreakable`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 48. `stress-title-4x-sliced-subtitle`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 49. `stress-title-none`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 50. `stress-title-only`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 51. `stress-title-unbreakable`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 52. `stress-two-wrapped-vertical`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 53. `stress-widebanner-title-only`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 54. `switch-device-recommendation`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 55. `title-nil-error`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 56. `variant-button-capsule`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 57. `variant-button-capsuleOutlined`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 58. `variant-button-oblique`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 59. `variant-button-plain`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 60. `variant-button-primary-disabled`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 61. `variant-button-states`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 62. `variant-subtitle-attributed`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 63. `variant-subtitle-customview`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI custom-subtitle preset matches the UIKit custom-view content
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 64. `variant-subtitle-plain`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 65. `variant-title-attributed`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 66. `variant-title-plain`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 67. `worksheet-abused-cap-banner`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 68. `worksheet-generating-abused`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 69. `worksheet-ready-timer-banner`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.

## 70. `worksheet-timeup-timer-banner`

- [ ] UIKit snapshot reviewed
- [ ] SwiftUI snapshot reviewed
- [ ] Comparison reviewed
- [ ] Approved for this handoff
- Decision: approve / change requested / needs discussion
- Comment for next feeder:

  > Add context, suspected cause, requested change, or follow-up owner here.
