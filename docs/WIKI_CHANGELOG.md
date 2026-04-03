# Documentation & wiki changelog

All timestamps are **UTC** unless noted. Update this file whenever wiki pages or `docs/github-wiki/` change.

| Date (UTC) | Time (UTC) | Author | Change |
|------------|------------|--------|--------|
| 2026-04-03 | Initial pass | Engineering docs | Created `docs/github-wiki/` mirror for GitHub Wiki: Home, Architecture, User-Flows, Features, Business-Logic, Models, APIs, Data Connect, ENVI Brain, Subscriptions, Design System, Roadmap, Build, Components sidebar. Added this changelog and `docs/github-wiki/SYNC-TO-GITHUB-WIKI.md`. |
| 2026-04-03 | Verification pass 2 | Engineering docs | Added `Testing-and-SPM.md`; documented `LocationPermissionManager` in Business-Logic; sidebar + Home links updated. |
| 2026-04-03 | Verification pass 3 | Engineering docs | README links to wiki folder; Architecture notes RevenueCatUI; Testing page documents `swift test` vs Xcode caveat. |

## Verification checklist (last run: 2026-04-03)

- [x] App entry, coordinators, tabs
- [x] All feature areas (Auth, Feed, Library, Chat/Explore, Analytics, Profile, Editor, Export, Subscription)
- [x] Models catalog
- [x] Storage keys & permissions
- [x] Networking stubs vs future
- [x] AI subsystems (ENVIBrain)
- [x] RevenueCat / Aura
- [x] Data Connect schema + operations + seed
- [x] Placeholders / coming soon from codebase grep
- [x] README alignment (bundle ID, stack)
- [x] Package.swift / ENVITests
- [x] LocationPermissionManager
- [x] Firebase: `.firebaserc` vs iOS integration gap

When you add features, update the relevant wiki page and append a row above.
