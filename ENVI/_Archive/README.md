# _Archive

Files moved here are **excluded from the Xcode build** but kept under git
for reference and possible future revival. They were archived because:

1. **No Sketch artboard** exists for them yet, OR
2. **No Sketch page** exists for the feature domain, OR
3. They were superseded by a newer implementation.

## Orphan Swift Views (no Sketch artboard)

| File | Origin | Reason |
|------|--------|--------|
| ProcurementView.swift | Features/Enterprise/ | No artboard on Agency & Enterprise page |
| AutomationBuilderView.swift | Features/Notifications/ | No artboard on Billing & Settings page |
| ComplianceView.swift | Features/Security/ | No artboard on Billing & Settings page |
| HealthScoreView.swift | Features/Support/ | No artboard on Billing & Settings page |
| CoachingOverlayView.swift | Features/Education/ | Overlay, not a screen |
| ModerationQueueView.swift | Features/Admin/ | No artboard |
| FeatureFlagView.swift | Features/Admin/ | No artboard |
| ThemePickerView.swift | Features/Settings/ | No artboard |
| SyncStatusView.swift | Features/Settings/ | No artboard |
| MetadataCompletenessView.swift | Features/Metadata/ | No artboard |

## Archived Feature Folders (no Sketch page)

| Folder | Files | Reason |
|--------|-------|--------|
| Integrations/ | APIKeyView, IntegrationMarketplaceView, IntegrationViewModel, WebhookManagerView | No Sketch page |
| DataPlatform/ | MLModelDashboardView | No Sketch page |

## Reviving an Archived File

To bring a file back:

```bash
git mv ENVI/_Archive/Features/<File>.swift ENVI/Features/<TargetFolder>/<File>.swift
```

Then add the file to `project.yml` sources (or let xcodegen re-discover it).
