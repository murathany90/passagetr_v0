## 2026-03-18 - Add missing ARIA equivalent tooltips to icon-only buttons
**Learning:** Icon-only interactive elements like `IconButton` in Flutter must always include a `tooltip` property. This property acts as the ARIA equivalent for screen readers, making the app more accessible, and gives desktop/web users a helpful native hover tooltip. Found several missing in both the Student App and Admin Console.
**Action:** Always include a localized `tooltip` property when creating an `IconButton` or any other icon-only interactive widget to ensure accessibility and better UX.
