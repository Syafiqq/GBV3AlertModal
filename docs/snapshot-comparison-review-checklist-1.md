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
- `variant-subtitle-customview` intentionally has a blank SwiftUI side.
- Use “Comment for next feeder” for concrete observations and required follow-ups.
- Leave unresolved items unchecked; do not treat an overall green snapshot suite as visual approval.

Reviewer: <!-- name -->

Review date: <!-- YYYY-MM-DD -->

Source commit: <!-- full SHA -->

Report path or artifact URL: <!-- path/URL -->

Overall handoff notes:

> Add summary, cross-cutting findings, and the recommended next action here.

## 1. `ai-notes-ready-banner`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve
## 2. `badge-detail-popup`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: it is not horizontally centered, the swiftui also doesnt have the placeholder image, the title is nod bolded

## 3. `badge-unlock-multi`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 4. `badge-unlock-single`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 5. `close-button-dismiss`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 6. `credit-deduction-popup`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 7. `database-error-banner`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 8. `date-picker-worksheet`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 9. `divergence-banner-wide-landscape-width`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 10. `divergence-inset-band`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 11. `divergence-ratio-not-artwork-aspect`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 12. `divergence-shows-primary-not-obeyed`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 13. `divergence-tall-uncapped-artwork`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: need top and bottom margin

## 14. `exit-worksheet-confirm-banner`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 15. `force-update-banner`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 16. `oblique-red-leave-confirm`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 17. `onboarding-trial-banner`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 18. `onboarding-welcome-nobanner`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 19. `permission-denied-settings`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 20. `quiz-begin-banner`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 21. `quiz-info-banner`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 22. `rename-worksheet`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: The text field should follow the dialog background, now it not look consistent

## 23. `standard-one-button`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 24. `standard-two-button`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 25. `streak-popup-banner`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 26. `stress-all-none`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 27. `stress-banner-only`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 28. `stress-banner-ultratall`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: need top and bottom margin

## 29. `stress-banner-ultrawide`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: need top and bottom margin

## 30. `stress-baseline`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: need top and bottom margin

## 31. `stress-buttons-horizontal`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: need top and bottom margin

## 32. `stress-buttons-only`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: need top and bottom margin

## 33. `stress-close-button-horizontal-wrapped`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 34. `stress-close-button-title`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: need top and bottom margin

## 35. `stress-maxed-horizontal`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: need top and bottom margin

## 36. `stress-maxed-vertical`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: need top and bottom margin

## 37. `stress-maxed-widebanner-horizontal`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: need top and bottom margin, the banner is cut from device, the dialog has larger than the device


## 38. `stress-nasty-horizontal-wrapped-no-banner`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 39. `stress-nasty-tallbanner-subtitle`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: need top and bottom margin

## 40. `stress-nasty-widebanner-horizontal-wrapped`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 41. `stress-no-buttons`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: need top and bottom margin

## 42. `stress-primary-none`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: need top and bottom margin

## 43. `stress-primary-wrapped`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: need top and bottom margin

## 44. `stress-secondary-none`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: need top and bottom margin

## 45. `stress-secondary-wrapped`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: need top and bottom margin

## 46. `stress-subtitle-none`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: need top and bottom margin

## 47. `stress-subtitle-unbreakable`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: need top and bottom margin

## 48. `stress-title-4x-sliced-subtitle`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 49. `stress-title-none`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 50. `stress-title-only`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: need top and bottom margin

## 51. `stress-title-unbreakable`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 52. `stress-two-wrapped-vertical`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 53. `stress-widebanner-title-only`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 54. `switch-device-recommendation`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 55. `title-nil-error`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 56. `variant-button-capsule`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 57. `variant-button-capsuleOutlined`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: look the screenshot

## 58. `variant-button-oblique`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 59. `variant-button-plain`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: plain button is wrong

## 60. `variant-button-primary-disabled`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 61. `variant-button-states`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 62. `variant-subtitle-attributed`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 63. `variant-subtitle-customview`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: change requested
- Comment for next feeder: create custom preset for the ui like this

## 64. `variant-subtitle-plain`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 65. `variant-title-attributed`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 66. `variant-title-plain`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 67. `worksheet-abused-cap-banner`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 68. `worksheet-generating-abused`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 69. `worksheet-ready-timer-banner`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve

## 70. `worksheet-timeup-timer-banner`

- [v] UIKit snapshot reviewed
- [v] SwiftUI snapshot reviewed
- [v] Comparison reviewed
- [v] Approved for this handoff
- Decision: approve
