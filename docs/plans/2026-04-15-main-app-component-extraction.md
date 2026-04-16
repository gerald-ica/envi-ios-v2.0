## Main App Component Extraction

Source of truth:
- Sketch: `/Users/wendyly/Downloads/COPY-DRAFT ENVI-iOS-v2․0.sketch`
- Tokens: `/Users/wendyly/Downloads/copy-draft-envi-ios-v2-0.tokens.json`
- Page: `Main App`

Why the app drifted:
- The last pass matched screen layouts, not the component structure used by `Main App`.
- `Main App` contains only a small number of true Sketch symbols:
  - `ENVI-LOGO`
  - `HOME/ FEED ICON`
  - `AURA ICON`
  - `Instagram icon`
  - `TIKTOK ICON`
  - `Reach icon`
- Most of the UI is built from repeated groups that must be extracted into code-level shared components.

Component set to extract into the app:

1. `MainAppBottomPillBar`
- Sketch source: `Tab Pill Bar`
- Used in: Feed, Library, World Explorer, Analytics, Profile
- Responsibilities:
  - 164x64 glass/tinted pill
  - active white 45x45 background
  - left feed icon
  - center ENVI logo/title state
  - right profile icon

2. `MainAppTopSegmentSwitch`
- Sketch source: `Seg Container`, `FOR YOU Pill`
- Used in: Feed, Library
- Responsibilities:
  - 220x40 container
  - 100x32 active segment pill
  - exact text styling and spacing

3. `MainAppUtilityLeadingPill`
- Sketch source: `Chat Pill`
- Used in: Feed, Library
- Responsibilities:
  - 34x32 white rounded pill
  - black chat glyph

4. `MainAppUtilityTrailingIcon`
- Sketch source: top-right utility graphics
- Used in: Feed, Library, Chat header
- Responsibilities:
  - icon-only utility affordance with Sketch spacing

5. `MainAppFeedCard`
- Sketch source: `Front Card`
- Used in: Feed
- Responsibilities:
  - 361x480 stacked card geometry
  - image hero
  - platform badge
  - handle row
  - AI metric preview cluster

6. `MainAppAIPreviewCluster`
- Sketch source: `AI SCORE PREVIEWS`
- Used in: Feed cards
- Responsibilities:
  - confidence / time / reach pills
  - reach icon symbol usage

7. `MainAppSearchBar`
- Sketch source: `Search bar`
- Used in: Library
- Responsibilities:
  - 324x48 field
  - search icon left
  - placeholder treatment matching Sketch

8. `MainAppTemplateRailCard`
- Sketch source: `Saved Templates` cards
- Used in: Library
- Responsibilities:
  - consistent card widths/heights
  - image overlay
  - mono text hierarchy

9. `MainAppLibraryGridCard`
- Sketch source: Library arsenal tiles
- Used in: Library
- Responsibilities:
  - masonry tile treatment
  - overlay typography
  - exact radius and shadow style

10. `MainAppFAB`
- Sketch source: `FAB`
- Used in: Library
- Responsibilities:
  - 56x56 white floating action button
  - exact plus icon treatment

11. `MainAppHeaderBlock`
- Sketch source: chat header left block / analytics title block
- Used in: World Explorer, Analytics
- Responsibilities:
  - mono eyebrow
  - large title stack
  - supporting copy / date line

12. `MainAppContentTypeLegend`
- Sketch source: `Content types Group`
- Used in: World Explorer
- Responsibilities:
  - dot + label rows
  - selected / filtered states

13. `MainAppScrubber`
- Sketch source: `Timeline scrubber`
- Used in: World Explorer
- Responsibilities:
  - vertical line
  - scrub dot and month marker
  - zoom buttons

14. `MainAppSuggestionPill`
- Sketch source: suggested question pills
- Used in: World Explorer / AI Chat
- Responsibilities:
  - short and long pill variants
  - typography and inset matching

15. `MainAppComposerBar`
- Sketch source: `Envi-ous-brain ai Chat`
- Used in: AI Chat
- Responsibilities:
  - plus button
  - text field region
  - send/voice affordances

16. `MainAppKPIStatCard`
- Sketch source: analytics KPI cards and profile stat cards
- Used in: Analytics, Profile
- Responsibilities:
  - shared card shell
  - icon/metric variant
  - centered stat variant

17. `MainAppSubscriptionRow`
- Sketch source: `Subscription tab`
- Used in: Profile
- Responsibilities:
  - 345x50 translucent row
  - aura icon
  - title/subtitle
  - chevron

18. `MainAppPlatformConnectionRow`
- Sketch source: connected platform rows
- Used in: Profile
- Responsibilities:
  - platform icon symbol
  - platform name / handle
  - row shell and divider behavior

19. `MainAppSettingsRow`
- Sketch source: settings rows
- Used in: Profile
- Responsibilities:
  - 380x40 row
  - icon
  - title
  - chevron

20. `MainAppDivider`
- Sketch source: `divider`, `divider Style`
- Used in: Profile and any matching separators
- Responsibilities:
  - thin white separator with Sketch opacity

Implementation order:
1. Extract chrome components first:
   - bottom pill bar
   - top segment switch
   - utility pills/icons
2. Extract feed/library components:
   - feed card
   - AI preview cluster
   - search bar
   - template rail
   - arsenal grid card
   - FAB
3. Extract chat/analytics/profile components:
   - header block
   - legend
   - scrubber
   - suggestion pill
   - composer
   - KPI card
   - subscription row
   - platform row
   - settings row
   - divider
4. Refactor all `Main App` surfaces to consume only those components.

Code ownership target:
- New shared components should live under `ENVI/Components/MainApp/`.
- Screen files should become composition-only:
  - `ForYouGalleryContainerView.swift`
  - `ForYouSwipeView.swift`
  - `GalleryGridView.swift`
  - `ChatExploreView.swift`
  - `WorldExplorerView.swift`
  - `AnalyticsView.swift`
  - `ProfileView.swift`

Success criteria:
- No `Main App` screen owns its own pill/search/card/row styling.
- Shared `MainApp` components define the visual shell.
- Sketch tokens and geometry are centralized, not recopied per screen.
