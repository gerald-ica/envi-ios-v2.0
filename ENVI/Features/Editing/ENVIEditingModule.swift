//  ENVIApp.swift
//  ENVI v3.0 — iOS 26+ Only
//
//  Integrates with the existing UIKit AppDelegate + SceneDelegate architecture.
//  This file provides a SwiftUI-based editing module that plugs into the
//  current app's MainTabBarController via the World Explorer / AI Chat flow.
//
//  Dependencies: RevenueCat, Firebase, GoogleSignIn (via current app)
//  Target: iOS 26+ | Swift 5+ (matching current app's .swiftLanguageMode(.v5))
//

import SwiftUI
import SwiftData
import Metal

// MARK: - ENVI Editing Module
/// SwiftUI-based editing module that can be hosted inside the current app's
/// UIKit architecture. Not a standalone `@main` — the real app entry point
/// is `AppDelegate` in the main target.
///
/// Usage in current app:
///   let editingVC = UIHostingController(
///     rootView: ENVIEditingModule()
///       .environmentObject(AppRouter.shared)
///       .requiresAura()
///   )
@MainActor
public struct ENVIEditingModule: View {
    @StateObject private var pipeline: ReverseEditingPipeline
    @State private var selectedTab: ENVIEditingTab = .edit

    public init() {
        _pipeline = StateObject(wrappedValue: ReverseEditingPipeline())
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            // Main editing flow
            EditTabView(pipeline: pipeline)
                .tabItem {
                    Label("Edit", systemImage: "wand.and.stars")
                }
                .tag(ENVIEditingTab.edit)

            // Template browser
            TemplateBrowserView()
                .tabItem {
                    Label("Browse", systemImage: "square.grid.2x2")
                }
                .tag(ENVIEditingTab.browse)

            // Style explorer
            StyleExplorerView()
                .tabItem {
                    Label("Styles", systemImage: "paintbrush")
                }
                .tag(ENVIEditingTab.styles)

            // History
            EditHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(ENVIEditingTab.history)
        }
        .accentColor(Color(hex: 0x7A56C4)) // Match ENVI brand purple
    }
}

// MARK: - Edit Tab

enum ENVIEditingTab: String, CaseIterable {
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
        var sources: [MediaAnalysisEngine.SourceMedia] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
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
                .background(Color(hex: 0x7A56C4))
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
                    .background(Color(hex: 0x7A56C4))
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
                    .background(Color(hex: 0x7A56C4))
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
                    .background(Color(hex: 0x7A56C4))
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
                    .background(Color(hex: 0x7A56C4))
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

// MARK: - Color Helper

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255.0,
            green: Double((hex >> 8) & 0xff) / 255.0,
            blue: Double(hex & 0xff) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - Preview

#Preview {
    ENVIEditingModule()
}
