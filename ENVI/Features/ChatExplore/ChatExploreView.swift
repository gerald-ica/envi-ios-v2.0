import SwiftUI

// MARK: - Explore Mode

enum ExploreMode: String, CaseIterable {
    case explore = "EXPLORE"
    case chat = "CHAT"
}

// MARK: - ChatExploreView

/// Main container that hosts a custom segmented control toggling between
/// WorldExplorerView (.explore) and EnhancedChatView (.chat).
///
/// Phase 15-02: `showHistory` and `showSettings` bool flags replaced with
/// `router.present(.chatHistory)` / `.contentLibrarySettings`. The
/// `.sheet(item: $router.sheet)` modifier attached here lets router-
/// driven sheets originate from this tab.
struct ChatExploreView: View {
    @State private var selectedMode: ExploreMode = .explore
    @State private var seededChatPrompt: String?
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                if selectedMode == .explore {
                    WorldExplorerView(onSuggestionClick: { prompt in
                        seededChatPrompt = prompt
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedMode = .chat
                        }
                    })
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .offset(x: -20)),
                                removal: .opacity.combined(with: .offset(x: -20))
                            )
                        )
                } else {
                    EnhancedChatView(seedPrompt: $seededChatPrompt)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .offset(x: 20)),
                                removal: .opacity.combined(with: .offset(x: 20))
                            )
                        )
                }
            }
            .animation(.easeInOut(duration: 0.3), value: selectedMode)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Sketch "13 - AI Chat" header row: Chat History (left),
            // EXPLORE/CHAT toggle (center-right), Settings (right).
            headerRow
                .padding(.top, 52)
                .padding(.horizontal, 22)
        }
        .background(AppBackground(imageName: "chat-home-bg"))
        .preferredColorScheme(.dark)
        .sheet(item: $router.sheet) { destination in
            AppDestinationSheetResolver(destination: destination)
        }
        .fullScreenCover(item: $router.fullScreen) { destination in
            AppDestinationFullScreenResolver(destination: destination)
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: ENVISpacing.md) {
            Button { router.present(.chatHistory) } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 24, height: 24)
            }

            Spacer()

            modeToggle

            Spacer()

            Button { router.present(.contentLibrarySettings) } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 24, height: 24)
            }
        }
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: ENVISpacing.xl) {
            ForEach(ExploreMode.allCases, id: \.self) { mode in
                segmentButton(for: mode)
            }
        }
    }

    private func segmentButton(for mode: ExploreMode) -> some View {
        let isSelected = selectedMode == mode

        return Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedMode = mode
            }
        } label: {
            VStack(spacing: 4) {
                Text(mode.rawValue)
                    .font(.spaceMonoBold(12))
                    .tracking(1.5)
                    .foregroundColor(isSelected ? .white : .white.opacity(0.4))
                
                Rectangle()
                    .fill(isSelected ? Color.white : Color.clear)
                    .frame(height: 2)
            }
            .fixedSize()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - EnhancedChatView

struct EnhancedChatView: View {
    @StateObject private var viewModel = EnhancedChatViewModel()
    @Binding var seedPrompt: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Main content area with transitions
            ZStack {
                if viewModel.isHome {
                    EnhancedChatHomeView(viewModel: viewModel)
                        .transition(.opacity.combined(with: .offset(y: 8)))
                } else if viewModel.isTyping {
                    VStack {
                        Spacer()
                        TypingDotsView()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                } else if let thread = viewModel.activeThread {
                    EnhancedThreadView(
                        thread: thread,
                        isTyping: false,
                        onRelatedQuestion: { q in
                            viewModel.startThread(q)
                        },
                        onBack: {
                            viewModel.resetToHome()
                        }
                    )
                    .transition(.opacity.combined(with: .offset(y: 8)))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.isHome)
            .animation(.easeInOut(duration: 0.25), value: viewModel.isTyping)

            Spacer(minLength: 0)

            ZStack(alignment: .bottomLeading) {
                ENVIBottomComposer(
                    text: $viewModel.inputText,
                    lightMode: colorScheme == .light,
                    isPlusMenuOpen: .constant(false), // Or add state if needed
                    onPlusTap: { },
                    onVoiceTap: { },
                    onCompassTap: { },
                    onSendTap: {
                        let trimmed = viewModel.inputText.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        viewModel.startThread(trimmed)
                        viewModel.inputText = ""
                    }
                )
                .padding(.bottom, ENVISpacing.xl)
            }
        }
        .background(AppBackground(imageName: "chat-home-bg"))
        .onChange(of: seedPrompt) { _, prompt in
            guard let prompt, !prompt.isEmpty else { return }
            viewModel.startThread(prompt)
            seedPrompt = nil
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ChatExploreView_Previews: PreviewProvider {
    static var previews: some View {
        ChatExploreView()
            .environmentObject(AppRouter())
            .preferredColorScheme(.dark)
    }
}
#endif
