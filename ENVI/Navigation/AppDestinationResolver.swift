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

        // MARK: - Publishing (Phase 16-01)

        case .schedulePost:
            SchedulePostSheetHost()

        case .publishResults:
            PublishResultsSheetHost()

        case .linkedInAuthorPicker:
            LinkedInAuthorPickerSheetHost()

        // MARK: - Profile-adjacent modals (Phase 16-02)

        case .agency:
            AgencySheetHost()

        case .teams:
            TeamsSheetHost()

        case .commerce:
            NavigationStack {
                MarketplaceView()
                    .navigationTitle("Commerce")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .preferredColorScheme(.dark)

        case .experiments:
            ExperimentsSheetHost()

        case .security:
            SecuritySheetHost()

        case .notifications:
            NotificationsSheetHost()

        // MARK: - AIFeatures (Phase 16-03)

        case .ideation:
            NavigationStack {
                IdeationDashboardView()
                    .navigationTitle("Ideation")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .preferredColorScheme(.dark)

        case .aiVisualEditor:
            AIVisualEditorSheetHost()

        case .captionGenerator:
            CaptionGeneratorSheetHost()

        case .hookLibrary:
            HookLibrarySheetHost()

        case .scriptEditor:
            ScriptEditorSheetHost()

        case .styleTransfer:
            StyleTransferSheetHost()

        case .imageGenerator:
            ImageGeneratorSheetHost()

        // MARK: - Library-adjacent modals (Phase 16-04)

        case .libraryTools:
            LibraryToolsMenu()

        case .brandKit:
            BrandKitSheetHost()

        case .campaigns:
            CampaignsSheetHost()

        case .collaboration:
            CollaborationSheetHost()

        case .community:
            CommunitySheetHost()

        case .metadata:
            MetadataSheetHost()

        case .repurposing:
            RepurposingSheetHost()

        case .admin:
            NavigationStack {
                SystemHealthView()
                    .navigationTitle("Admin")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .preferredColorScheme(.dark)

        case .enterprise:
            NavigationStack {
                ContractManagerView()
                    .navigationTitle("Enterprise")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .preferredColorScheme(.dark)

        default:
            // Phase 16-02+ will fill the remaining arms: admin,
            // agency, brandKit, campaigns, commerce, community,
            // enterprise, experiments, metadata, publishing,
            // repurposing, teams, collaboration, campaignDetail,
            // + all 7 AIFeatures + 6 Profile sub-sections
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

// MARK: - Publishing sheet hosts (Phase 16-01)

/// Host for `SchedulePostView`. Owns a fresh `SchedulingViewModel` for
/// the duration of the sheet so the composer can write through to the
/// same repository stack `ScheduleQueueView` reads from.
private struct SchedulePostSheetHost: View {
    @StateObject private var viewModel = SchedulingViewModel()

    var body: some View {
        SchedulePostView(viewModel: viewModel)
            .preferredColorScheme(.dark)
    }
}

/// Host for `PublishResultsView`. Presents the most-recent completed or
/// failed post's reconciliation details. If no such post exists, shows
/// a lightweight empty state rather than constructing the view with a
/// fake payload.
private struct PublishResultsSheetHost: View {
    @StateObject private var viewModel = SchedulingViewModel()
    @Environment(\.dismiss) private var dismiss

    private var mostRecentResolvedPost: ScheduledPost? {
        viewModel.scheduledPosts
            .filter { $0.status == .completed || $0.status == .failed }
            .sorted { $0.scheduledAt > $1.scheduledAt }
            .first
    }

    var body: some View {
        Group {
            if let post = mostRecentResolvedPost {
                PublishResultsView(viewModel: viewModel, post: post)
            } else {
                NavigationStack {
                    VStack(spacing: ENVISpacing.lg) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.white.opacity(0.4))
                        Text("NO PUBLISH RESULTS YET")
                            .font(.spaceMonoBold(12))
                            .tracking(1.8)
                            .foregroundColor(.white.opacity(0.55))
                        Text("Completed and failed posts will show their per-platform reconciliation here.")
                            .font(.interRegular(13))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, ENVISpacing.xxxl)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .navigationTitle("Publish Results")
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
    }
}

/// Host for `LinkedInAuthorPickerView`. The picker is designed to be
/// invoked from a compose flow with a selection callback, but when
/// surfaced as a generic router destination (no caller-supplied
/// callback) we just dismiss on confirm — the selected author is
/// discarded. This is acceptable because the picker itself is a read
/// surface from the Publishing tab's POV; the real write path
/// originates from the compose flow in a future plan.
private struct LinkedInAuthorPickerSheetHost: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LinkedInAuthorPickerView(
            onSelect: { _ in },
            onDismiss: { dismiss() }
        )
    }
}

// MARK: - Profile-adjacent sheet hosts (Phase 16-02)

/// Host for `AgencyDashboardView`. Owns a fresh `AgencyViewModel` so
/// the sheet can be surfaced from the generic router path without a
/// parent view having to allocate one.
private struct AgencySheetHost: View {
    @StateObject private var viewModel = AgencyViewModel()
    var body: some View {
        NavigationStack {
            AgencyDashboardView(viewModel: viewModel)
                .navigationTitle("Agency")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

private struct TeamsSheetHost: View {
    @StateObject private var viewModel = TeamViewModel()
    var body: some View {
        NavigationStack {
            TeamMemberView(viewModel: viewModel)
                .navigationTitle("Teams")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

private struct ExperimentsSheetHost: View {
    @StateObject private var viewModel = ExperimentViewModel()
    var body: some View {
        NavigationStack {
            ExperimentListView(viewModel: viewModel)
                .navigationTitle("Experiments")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

private struct SecuritySheetHost: View {
    @StateObject private var viewModel = SecurityViewModel()
    var body: some View {
        NavigationStack {
            AuditLogView(viewModel: viewModel)
                .navigationTitle("Security")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

private struct NotificationsSheetHost: View {
    @StateObject private var viewModel = NotificationViewModel()
    var body: some View {
        NavigationStack {
            NotificationListView(viewModel: viewModel)
                .navigationTitle("Notifications")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - AIFeatures sheet hosts (Phase 16-03)

/// Hosts for the AI writing suite — three views share a single
/// `AIWritingViewModel` per sheet so prompt/caption/hook/script state
/// stays coherent within one session. Separate VM instances per sheet
/// because each sheet presentation is logically independent.

private struct CaptionGeneratorSheetHost: View {
    @StateObject private var viewModel = AIWritingViewModel()
    var body: some View {
        NavigationStack {
            CaptionGeneratorView(viewModel: viewModel)
                .navigationTitle("Caption Generator")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

private struct HookLibrarySheetHost: View {
    @StateObject private var viewModel = AIWritingViewModel()
    var body: some View {
        NavigationStack {
            HookLibraryView(viewModel: viewModel)
                .navigationTitle("Hook Library")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

private struct ScriptEditorSheetHost: View {
    @StateObject private var viewModel = AIWritingViewModel()
    var body: some View {
        NavigationStack {
            ScriptEditorView(viewModel: viewModel)
                .navigationTitle("Script Editor")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

/// Hosts for the AI visual suite (three views share AIVisualViewModel).

private struct AIVisualEditorSheetHost: View {
    @StateObject private var viewModel = AIVisualViewModel()
    var body: some View {
        NavigationStack {
            AIVisualEditorView(viewModel: viewModel)
                .navigationTitle("AI Visual Editor")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

private struct StyleTransferSheetHost: View {
    @StateObject private var viewModel = AIVisualViewModel()
    var body: some View {
        NavigationStack {
            StyleTransferView(viewModel: viewModel)
                .navigationTitle("Style Transfer")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

private struct ImageGeneratorSheetHost: View {
    @StateObject private var viewModel = AIVisualViewModel()
    var body: some View {
        NavigationStack {
            ImageGeneratorView(viewModel: viewModel)
                .navigationTitle("Image Generator")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Library-adjacent sheet hosts (Phase 16-04)

private struct BrandKitSheetHost: View {
    @StateObject private var viewModel = BrandKitViewModel()
    var body: some View {
        NavigationStack {
            BrandKitListView(viewModel: viewModel)
                .navigationTitle("Brand Kit")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

private struct CampaignsSheetHost: View {
    @StateObject private var viewModel = CampaignViewModel()
    var body: some View {
        NavigationStack {
            CampaignListView(viewModel: viewModel)
                .navigationTitle("Campaigns")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

private struct CollaborationSheetHost: View {
    @StateObject private var viewModel = CollaborationViewModel()
    var body: some View {
        NavigationStack {
            ReviewListView(viewModel: viewModel)
                .navigationTitle("Collaboration")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

private struct CommunitySheetHost: View {
    @StateObject private var viewModel = CommunityViewModel()
    var body: some View {
        NavigationStack {
            InboxView(viewModel: viewModel)
                .navigationTitle("Community")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

private struct MetadataSheetHost: View {
    @StateObject private var viewModel = MetadataViewModel()
    var body: some View {
        NavigationStack {
            TagManagerView(viewModel: viewModel)
                .navigationTitle("Metadata")
                .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

private struct RepurposingSheetHost: View {
    @StateObject private var viewModel = RepurposingViewModel()
    var body: some View {
        NavigationStack {
            RepurposeDashboardView(viewModel: viewModel)
                .navigationTitle("Repurposing")
                .navigationBarTitleDisplayMode(.inline)
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
