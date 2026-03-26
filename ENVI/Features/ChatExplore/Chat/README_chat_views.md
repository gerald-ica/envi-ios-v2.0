# Enhanced Chat UI Views

All 5 views created in `/ENVI/Features/ChatExplore/Chat/`, matching the React `ChatPanel.tsx` design:

## Files Created

1. **EnhancedChatHomeView.swift** — Landing state with `[01] ENVI AI` header, `HOW CAN I HELP YOU CREATE?` heading (Inter Black 32pt), subtitle (SpaceMono 12pt), wrapped FlowLayout chips (Capsule border, SpaceMono 11pt uppercase), divider, `MESSAGE` label + underline TextField, `SEND MESSAGE` full-width button.

2. **EnhancedThreadView.swift** — Thread response with `[01] YOUR QUESTION` header, question as Inter Black 28pt heading, `✦ ENVI AI RESPONSE` label, response paragraphs (Inter 14pt, 0.75 opacity, 1.7 line height), 2×2 `LazyVGrid` metrics grid, divider, `EXPLORE MORE` label, tappable related questions with chevron.right.

3. **EnhancedChatInputBar.swift** — Bottom bar with tool chips row (Attach/paperclip, Voice/mic, Timeline/clock as Capsule-bordered chips), underline-style TextField + circular send button (arrow.up, visible only when text non-empty).

4. **MetricCardView.swift** — Individual metric card: label (SpaceMono 10pt uppercase), value (Inter Bold 24pt), change with trend color (#4EEAA8 up, #FF6B7A down, 0.4 opacity neutral). Rectangle stroke border, no fill.

5. **TypingDotsView.swift** — 3 circles (6pt) with staggered bounce animation (0ms/150ms/300ms delays).

## Design System Usage

- Colors: `ENVITheme.text(for:)`, `ENVITheme.border(for:)`, `ENVITheme.background(for:)`
- Fonts: `.spaceMono()`, `.spaceMonoBold()`, `.interRegular()`, `.interBlack()`, `.interBold()`, `.interMedium()`
- Spacing: `ENVISpacing.xs/.sm/.md/.lg/.xl/.xxl/.xxxl`
- Radius: `ENVIRadius.sm/.md/.lg`
- FlowLayout: Uses existing `FlowLayout` from `/ChatExplore/FlowLayout.swift`

## Dependencies

- `EnhancedChatViewModel` (in `Chat/EnhancedChatViewModel.swift`)
- `ChatThread`, `ThreadMetric`, `MetricTrend` (in `/Models/ChatThread.swift`)
- `FlowLayout` (in `/ChatExplore/FlowLayout.swift`)
