import SwiftUI

// MARK: - Content View
/// Main app shell for ENVI. Tab-based navigation across all 4 core views.
@MainActor
public struct ContentView: View {
    @StateObject private var pipeline = ReverseEditingPipeline()
    @State private var selectedTab: Tab = .edit
    @State private var showOnboarding: Bool = false

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            // Main editing flow
            EditTabView(pipeline: pipeline)
                .tabItem {
                    Label("Edit", systemImage: "wand.and.stars")
                }
                .tag(Tab.edit)

            // Template browser
            TemplateBrowserView()
                .tabItem {
                    Label("Browse", systemImage: "square.grid.2x2")
                }
                .tag(Tab.browse)

            // Style explorer
            StyleExplorerView()
                .tabItem {
                    Label("Styles", systemImage: "paintbrush")
                }
                .tag(Tab.styles)

            // History
            EditHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(Tab.history)
        }
        .accentColor(.accentColor)
        .onAppear {
            // Check first launch
            if !UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
    }
}

// MARK: - Tab Enum

enum Tab: String, CaseIterable {
    case edit = "edit"
    case browse = "browse"
    case styles = "styles"
    case history = "history"
}

// MARK: - Edit Tab View

struct EditTabView: View {
    @ObservedObject var pipeline: ReverseEditingPipeline
    @State private var showMediaPicker: Bool = false
    @State private var selectedItems: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            VStack {
                switch pipeline.state {
                case .idle:
                    EmptyEditState(onSelectMedia: { showMediaPicker = true })

                case .analyzing, .matching, .rendering:
                    if let progress = pipeline.progress {
                        RenderProgressView(progress: progress)
                    } else {
                        ProgressView("Creating your edit...")
                    }

                case .preview:
                    if pipeline.renderedOutput != nil {
                        ApprovalFlowView(pipeline: pipeline)
                    }

                case .approved:
                    ApprovedState(onNewEdit: { pipeline.reset() })

                case .rejected:
                    if pipeline.currentMatch != nil {
                        ApprovalFlowView(pipeline: pipeline)
                    } else {
                        NoMoreMatchesState(onNewEdit: { pipeline.reset() })
                    }

                case .cancelled:
                    CancelledState(onResume: { pipeline.reset() })

                case .error:
                    if let error = pipeline.error {
                        ErrorState(error: error, onRetry: { pipeline.reset() })
                    }
                }
            }
            .navigationTitle("ENVI")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if pipeline.state != .idle {
                        Button("Cancel") {
                            pipeline.cancel()
                        }
                    }
                }
            }
            .photosPicker(
                isPresented: $showMediaPicker,
                selection: $selectedItems,
                maxSelectionCount: 20,
                matching: .any(of: [.images, .videos])
            )
            .onChange(of: selectedItems) { _, items in
                Task { await loadAndEdit(items) }
            }
        }
    }

    private func loadAndEdit(_ items: [PhotosPickerItem]) async {
        // Convert PhotosPickerItem to SourceMedia
        var sources: [MediaAnalysisEngine.SourceMedia] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                // Determine if image or video and create appropriate SourceMedia
                // Simplified: treat all as photos for now
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try? data.write(to: tempURL)
                sources.append(.photo(tempURL))
            }
        }

        await pipeline.start(with: sources)
    }
}

// MARK: - Empty Edit State

struct EmptyEditState: View {
    let onSelectMedia: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text("Select photos or videos")
                    .font(.title2.weight(.semibold))
                Text("ENVI will find the perfect template and auto-edit for you")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: onSelectMedia) {
                HStack {
                    Image(systemName: "photo.stack")
                    Text("Select from Library")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .clipShape(Capsule())
            }
            .padding(.top, 16)

            Spacer()
        }
    }
}

// MARK: - Approved State

struct ApprovedState: View {
    let onNewEdit: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .symbolRenderingMode(.multicolor)

            Text("Approved!")
                .font(.title2.weight(.bold))

            Text("Your edit has been saved to Photos")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(action: onNewEdit) {
                Text("Edit Something New")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
            .padding(.top, 16)

            Spacer()
        }
    }
}

// MARK: - No More Matches State

struct NoMoreMatchesState: View {
    let onNewEdit: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "rectangle.stack.badge.minus")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No more matches")
                .font(.title2.weight(.bold))

            Text("Try different photos or browse templates manually")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: onNewEdit) {
                Text("Start Over")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
            .padding(.top, 16)

            Spacer()
        }
    }
}

// MARK: - Cancelled State

struct CancelledState: View {
    let onResume: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            Text("Cancelled")
                .font(.title2.weight(.bold))

            Button(action: onResume) {
                Text("Resume")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
            .padding(.top, 16)

            Spacer()
        }
    }
}

// MARK: - Error State

struct ErrorState: View {
    let error: ReverseEditingPipeline.PipelineError
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            Text("Something went wrong")
                .font(.title2.weight(.bold))

            Text(errorDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: onRetry) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
            .padding(.top, 16)

            Spacer()
        }
    }

    private var errorDescription: String {
        switch error {
        case .analysisFailed(let msg): return "Analysis failed: \(msg)"
        case .matchingFailed(let msg): return "Template matching failed: \(msg)"
        case .renderFailed(let msg): return "Rendering failed: \(msg)"
        case .noTemplatesAvailable: return "No templates match your content. Try different photos."
        case .userCancelled: return "You cancelled the edit."
        case .engineNotReady: return "ENVI is still initializing. Please wait a moment."
        }
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage: Int = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "photo.on.rectangle.angled",
            title: "Select Your Media",
            description: "Pick photos and videos from your camera roll. ENVI supports photos, carousels, videos, stories, and new formats."
        ),
        OnboardingPage(
            icon: "wand.and.stars",
            title: "AI Auto-Edits",
            description: "ENVI analyzes your content and picks the perfect template from 474 archetypes across 406 styles."
        ),
        OnboardingPage(
            icon: "checkmark.circle.fill",
            title: "Approve or Reject",
            description: "Swipe right to approve, left to reject. ENVI learns your preferences and gets better over time."
        ),
        OnboardingPage(
            icon: "square.and.arrow.up",
            title: "Share Anywhere",
            description: "Export to Instagram, TikTok, YouTube Shorts, Threads, or anywhere else in one tap."
        )
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Page content
            let page = pages[currentPage]
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundStyle(.accentColor)
                .symbolRenderingMode(.hierarchical)
                .padding(.bottom, 16)

            Text(page.title)
                .font(.title.weight(.bold))

            Text(page.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(currentPage == index ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 24)

            // Action button
            Button(action: {
                if currentPage < pages.count - 1 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                    isPresented = false
                }
            }) {
                Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
}

// MARK: - Preview

#Preview {
    ContentView()
}
