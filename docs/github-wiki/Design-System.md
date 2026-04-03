# Design system

**Last updated:** 2026-04-03 UTC

## Principles (`ENVITheme.swift`)

- Monochrome **black / white / grays**; accent **`#30217C`** used sparingly (comment: ~max 20% coverage in subtle gradients).
- Semantic colors exposed as static functions: `background`, `surfaceLow`, `surfaceHigh`, `text`, `textSecondary`, `primary`, `secondary`, `border`, `accent` — each `(for scheme: ColorScheme)`.
- **Status colors:** success `#22C55E`, warning `#F59E0B`, error `#EF4444`, info `#3B82F6`.
- **Gradients:** `primaryGradient`, `cardOverlayGradient`, `accentGradient`.
- **Shadows:** `Shadow.card`, `Shadow.elevated`.
- **UIKit mirror:** `ENVITheme.UIKit` for dark-oriented surfaces/text.

## Typography (`ENVITypography.swift`)

- **Space Mono** — headings, labels, navigation, buttons (uppercase where `Style` demands).
- **Inter** — body, descriptions, placeholders (sentence case).
- **`Style` enum:** `displayLarge` … `badge` with size, weight, tracking.
- **`registerFonts()`** — called at app launch (App + Scene delegate).
- **View helper:** `.enviTextStyle(_:)`.

## Spacing (`ENVISpacing.swift`)

- **`ENVISpacing`:** `xs` (4) through `xxxxl` (48).
- **`ENVIRadius`:** `sm`–`xl` (8–14pt); comments note no capsule radii in token set.

## Theme manager

See [Business logic & rules](Business-Logic-and-Rules) for persistence and window override behavior.

---

Update when Figma tokens or accent usage rules change.
