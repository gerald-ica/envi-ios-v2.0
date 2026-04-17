import SwiftUI

/// Phase 15-02 — Switches an `AppDestination` into the view that should
/// appear inside a `.sheet(item:)` / `.fullScreenCover(item:)` modifier.
///
/// Only 4 destinations are wired in this plan (search, contentCalendar,
/// chatHistory, contentLibrarySettings) — the proof-of-pattern migration
/// from 15-02 Task 2. Phase 16 fills the remaining arms when the orphan
/// modal groups are wired into entry points. Unhandled arms render an
/// `EmptyView` so the switch compiles; a `#warning` marks them as
/// intentional placeholders.
///
/// These resolvers live in one place so every tab that attaches
/// `.sheet(item: $router.sheet)` gets the same view set without having
/// to duplicate the switch. The tab root is what ultimately hosts the
/// modifier — the resolver just produces the child view.

// MARK: - Sheet resolver

struct AppDestinationSheetResolver: View {
    let destination: AppDestination

    var body: some View {
        switch destination {
        case .search:
            FeedSearchView()

        case .contentCalendar:
            ContentCalendarSheetHost()

        case .chatHistory:
            ChatHistorySheetHost()

        case .contentLibrarySettings:
            ContentLibrarySettingsView()

        default:
            // Phase 16 will wire: admin, agency, brandKit, campaigns,
            // commerce, community, enterprise, experiments, metadata,
            // publishing, repurposing, teams, collaboration,
            // campaignDetail, + all 7 AIFeatures + 6 Profile sub-sections
            // + exportSheet/mediaPicker/phPicker.
            PlaceholderSheetView(destination: destination)
        }
    }
}

// MARK: - Full-screen resolver

struct AppDestinationFullScreenResolver: View {
    let destination: AppDestination

    var body: some View {
        switch destination {
        case .contentEditor:
            // Phase 16 will wire the real editor — keep a clearly
            // labelled placeholder for now so a full-screen cover that
            // slips through doesn't ship a blank screen.
            PlaceholderSheetView(destination: destination)

        default:
            PlaceholderSheetView(destination: destination)
        }
    }
}

// MARK: - Sheet hosts

/// Host for `ContentCalendarView` — provides the NavigationStack + Done
/// button chrome that the tab-level `CalendarSheet` used to offer inline.
private struct ContentCalendarSheetHost: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                ContentCalendarView(days: AnalyticsData.mock.calendarDays)
                    .padding(.top, ENVISpacing.lg)
            }
            .background(AppBackground(imageName: "feed-bg"))
            .navigationTitle("Content Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Host for ChatHistory — matches the original empty-state sheet that
/// used to live inline inside `ChatExploreView`.
private struct ChatHistorySheetHost: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ENVISpacing.xl) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.white.opacity(0.4))
                    Text("NO PAST CHATS YET")
                        .font(.spaceMonoBold(12))
                        .tracking(1.8)
                        .foregroundColor(.white.opacity(0.55))
                    Text("Your recent ENVI conversations will appear here.")
                        .font(.interRegular(13))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, ENVISpacing.xxxl)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 120)
            }
            .background(Color.black)
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Placeholder for un-wired destinations

private struct PlaceholderSheetView: View {
    let destination: AppDestination
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: ENVISpacing.lg) {
                Image(systemName: "square.on.square.dashed")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.white.opacity(0.4))
                Text("Destination pending")
                    .font(.spaceMonoBold(12))
                    .tracking(1.8)
                    .foregroundColor(.white.opacity(0.7))
                Text(destination.id)
                    .font(.interRegular(13))
                    .foregroundColor(.white.opacity(0.4))
                Text("Wiring arrives in Phase 16.")
                    .font(.interRegular(12))
                    .foregroundColor(.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationTitle("Coming Soon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
