import SwiftUI

/// Phase 16-03 — AI tools menu surfaced inside the ChatExplore tab.
///
/// Replaces the frontend-reachability gap for the 7 orphan AIFeatures
/// views (Ideation, Caption Generator, Hook Library, Script Editor,
/// Image Generator, Style Transfer, AI Visual Editor). Each card routes
/// via `router.present(.destination)` so the views open as sheets
/// resolved by `AppDestinationSheetResolver`.
///
/// The menu is presented from within `ChatExploreView`'s mode-switcher
/// as a third mode (`.ai`) sibling to `.explore` and `.chat`. The tab
/// already applies `.requiresAura()` at the `MainTabBarController`
/// level, so premium gating flows through to this view automatically.
struct AIToolsMenuView: View {

    // MARK: - Tool catalog

    struct Tool: Identifiable, Hashable {
        let id: String            // stable identifier (matches destination.id)
        let destination: AppDestination
        let title: String
        let subtitle: String
        let icon: String          // SF Symbol
    }

    /// Seven AIFeatures views, ordered for first-run legibility: writing
    /// tools first (Ideation → Caption → Hook → Script), then visual
    /// tools (Image → Style → Visual Editor).
    static let tools: [Tool] = [
        Tool(id: "ideation",
             destination: .ideation,
             title: "Ideation",
             subtitle: "Brainstorm new content ideas",
             icon: "lightbulb.max.fill"),
        Tool(id: "captionGenerator",
             destination: .captionGenerator,
             title: "Caption Generator",
             subtitle: "AI-drafted captions per platform",
             icon: "text.bubble.fill"),
        Tool(id: "hookLibrary",
             destination: .hookLibrary,
             title: "Hook Library",
             subtitle: "Attention-grabbing openers",
             icon: "bolt.fill"),
        Tool(id: "scriptEditor",
             destination: .scriptEditor,
             title: "Script Editor",
             subtitle: "Video & reel scripts",
             icon: "doc.text.fill"),
        Tool(id: "imageGenerator",
             destination: .imageGenerator,
             title: "Image Generator",
             subtitle: "AI image generation",
             icon: "wand.and.stars"),
        Tool(id: "styleTransfer",
             destination: .styleTransfer,
             title: "Style Transfer",
             subtitle: "Apply a style to your content",
             icon: "paintbrush.fill"),
        Tool(id: "aiVisualEditor",
             destination: .aiVisualEditor,
             title: "AI Visual Editor",
             subtitle: "Smart visual edits",
             icon: "slider.horizontal.3"),
    ]

    // MARK: - Body

    @EnvironmentObject private var router: AppRouter

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: ENVISpacing.md),
        GridItem(.flexible(), spacing: ENVISpacing.md),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.md) {
                Text("AI TOOLS")
                    .font(.spaceMonoBold(12))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, ENVISpacing.lg)
                    .padding(.top, 120)

                Text("Seven creator-focused AI helpers. Tap any card to open.")
                    .font(.interRegular(13))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, ENVISpacing.lg)

                LazyVGrid(columns: columns, spacing: ENVISpacing.md) {
                    ForEach(Self.tools) { tool in
                        Button {
                            router.present(tool.destination)
                        } label: {
                            card(for: tool)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, ENVISpacing.lg)
                .padding(.top, ENVISpacing.sm)
                .padding(.bottom, 140)
            }
        }
        .background(AppBackground(imageName: "chat-home-bg"))
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
struct AIToolsMenuView_Previews: PreviewProvider {
    static var previews: some View {
        AIToolsMenuView()
            .environmentObject(AppRouter())
            .preferredColorScheme(.dark)
    }
}
#endif
