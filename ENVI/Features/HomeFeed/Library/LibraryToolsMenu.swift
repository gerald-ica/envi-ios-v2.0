import SwiftUI

/// Phase 16-04 — content-adjacent tools menu for the Library surface.
///
/// Surfaces 7 visible-by-default tools (BrandKit, Metadata, Repurposing,
/// Campaigns, Collaboration, Community, Search) plus 2 admin/enterprise
/// tools that are hidden behind `FeatureFlags.shared.showAdminTools`
/// and only appear when the flag is flipped true (via Remote Config or
/// a future role-system gate).
///
/// Visual language matches `AIToolsMenuView` (Phase 16-03) for
/// consistency — sectioned list-of-cards with a title + subtitle +
/// SF Symbol icon per entry. Sections: Content, Campaigns & Teams,
/// Advanced.
struct LibraryToolsMenu: View {

    // MARK: - Tool model

    struct Tool: Identifiable, Hashable {
        let id: String
        let destination: AppDestination
        let title: String
        let subtitle: String
        let icon: String
    }

    struct Section: Identifiable {
        let id = UUID()
        let title: String
        let tools: [Tool]
    }

    // MARK: - Catalog

    /// Full catalog (9 entries). `visibleSections` filters admin/
    /// enterprise out when `showAdminTools` is false.
    static let allSections: [Section] = [
        Section(title: "CONTENT", tools: [
            Tool(id: "brandKit",     destination: .brandKit,     title: "Brand Kit",    subtitle: "Colors, fonts, logos, templates", icon: "paintpalette.fill"),
            Tool(id: "metadata",     destination: .metadata,     title: "Metadata",     subtitle: "Tags, auto-tag, smart labels",    icon: "tag.fill"),
            Tool(id: "repurposing",  destination: .repurposing,  title: "Repurposing",  subtitle: "Cross-post, remix, re-cut",       icon: "arrow.triangle.2.circlepath"),
        ]),
        Section(title: "CAMPAIGNS & TEAMS", tools: [
            Tool(id: "campaigns",     destination: .campaigns,     title: "Campaigns",     subtitle: "Briefs, sprints, tracking",        icon: "megaphone.fill"),
            Tool(id: "collaboration", destination: .collaboration, title: "Collaboration", subtitle: "Review, approve, share links",     icon: "checkmark.circle.fill"),
            Tool(id: "community",     destination: .community,     title: "Community",     subtitle: "Inbox, contacts, segments",         icon: "bubble.left.and.bubble.right.fill"),
        ]),
        Section(title: "ADVANCED", tools: [
            Tool(id: "search",        destination: .search,        title: "Advanced Search", subtitle: "Saved searches, hidden gems",   icon: "magnifyingglass"),
            Tool(id: "adminDashboard", destination: .admin,        title: "Admin",           subtitle: "System health, flags, logs",   icon: "gauge.with.dots.needle.67percent"),
            Tool(id: "enterpriseDashboard", destination: .enterprise, title: "Enterprise",   subtitle: "SSO, contracts, compliance",   icon: "building.columns.fill"),
        ]),
    ]

    /// Tools that gate on `showAdminTools`. `isAdminTool(_:)` tests
    /// against this set — keeping the gating logic declarative so the
    /// tests in Phase16Plan04LibraryToolsMenuTests can assert against
    /// the same source of truth.
    static let adminGatedDestinations: Set<AppDestination> = [.admin, .enterprise]

    static func isAdminTool(_ tool: Tool) -> Bool {
        adminGatedDestinations.contains(tool.destination)
    }

    /// Section list filtered to what the current user should see.
    static func visibleSections(showAdminTools: Bool) -> [Section] {
        allSections.map { section in
            Section(
                title: section.title,
                tools: section.tools.filter { tool in
                    if isAdminTool(tool) {
                        return showAdminTools
                    }
                    return true
                }
            )
        }
    }

    // MARK: - Body

    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: ENVISpacing.md),
        GridItem(.flexible(), spacing: ENVISpacing.md),
    ]

    var body: some View {
        let sections = LibraryToolsMenu.visibleSections(
            showAdminTools: FeatureFlags.shared.showAdminTools
        )

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                    ForEach(sections) { section in
                        if !section.tools.isEmpty {
                            VStack(alignment: .leading, spacing: ENVISpacing.md) {
                                Text(section.title)
                                    .font(.spaceMonoBold(11))
                                    .tracking(1.3)
                                    .foregroundColor(.white.opacity(0.6))

                                LazyVGrid(columns: columns, spacing: ENVISpacing.md) {
                                    ForEach(section.tools) { tool in
                                        Button {
                                            router.present(tool.destination)
                                        } label: {
                                            card(for: tool)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, ENVISpacing.lg)
                .padding(.vertical, ENVISpacing.xl)
            }
            .background(Color.black)
            .navigationTitle("Library Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func card(for tool: Tool) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Image(systemName: tool.icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 36, height: 36)

            Text(tool.title)
                .font(.interMedium(14))
                .foregroundColor(.white)

            Text(tool.subtitle)
                .font(.interRegular(11))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(2)
        }
        .padding(ENVISpacing.md)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }
}

#if DEBUG
struct LibraryToolsMenu_Previews: PreviewProvider {
    static var previews: some View {
        LibraryToolsMenu()
            .environmentObject(AppRouter())
            .preferredColorScheme(.dark)
    }
}
#endif
