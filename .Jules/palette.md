## 2024-05-15 - Icon Button Tooltips in Flutter
**Learning:** `IconButton` widgets without a `tooltip` property lack semantic meaning for screen readers, breaking accessibility.
**Action:** Always include a clear, localized `tooltip` property on all `IconButton`s to provide an ARIA-equivalent label.
