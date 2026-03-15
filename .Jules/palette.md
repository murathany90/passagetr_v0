## 2024-05-24 - Add Tooltips to IconButtons
**Learning:** In Flutter Web, `IconButton` widgets without a `tooltip` property lack an ARIA-equivalent semantic label. This causes accessibility issues for screen readers and makes the UI less intuitive for mouse users who expect a tooltip on hover.
**Action:** Always provide a descriptive `tooltip` property to all `IconButton` and similar icon-only interactive elements. This simple addition significantly improves both a11y and general UX.
