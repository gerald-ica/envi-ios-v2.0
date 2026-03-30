import SwiftUI

// MARK: - Explore Mode

enum ExploreMode: String, CaseIterable {
    case explore = "EXPLORE"
    case chat = "CHAT"
}

// MARK: - ChatExploreView

/// Main container that hosts a custom segmented control toggling between
/// WorldExplorerView (.explore) and EnhancedChatView (.chat).
struct ChatExploreView: View {
    @State private var selectedMode: ExploreMode = .explore
    @State private var seededChatPrompt: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            segmentedControl
            divider

            // Content area with crossfade + subtle slide
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
        }
        .background(ENVITheme.background(for: colorScheme))
    }

    // MARK: - Segmented Control

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(ExploreMode.allCases, id: \.self) { mode in
                segmentButton(for: mode)
            }
        }
        .padding(.horizontal, ENVISpacing.lg)
        .padding(.top, ENVISpacing.sm)
        .padding(.bottom, ENVISpacing.md)
    }

    private func segmentButton(for mode: ExploreMode) -> some View {
        let isSelected = selectedMode == mode

        return Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedMode = mode
            }
        } label: {
            Text(mode.rawValue)
                .font(.custom("SpaceMono-Regular", size: 11))
                .tracking(11 * 0.15) // 0.15em relative to font size
                .foregroundColor(isSelected ? ENVITheme.text(for: colorScheme) : ENVITheme.textSecondary(for: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, ENVISpacing.sm)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                                .fill(ENVITheme.surfaceHigh(for: colorScheme))
                        }
                    }
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(ENVITheme.border(for: colorScheme))
            .frame(height: 0.5)
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

            EnhancedChatInputBar(onSend: { text in
                viewModel.inputText = text
                viewModel.startThread(text)
            })
        }
        .background(ENVITheme.background(for: colorScheme))
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
            .preferredColorScheme(.dark)
    }
}
#endif
