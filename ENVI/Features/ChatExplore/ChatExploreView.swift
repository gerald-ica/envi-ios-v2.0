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
    @State private var showHistory = false
    @State private var showSettings = false

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
        .sheet(isPresented: $showHistory) {
            ChatHistorySheet()
        }
        .sheet(isPresented: $showSettings) {
            ContentLibrarySettingsView()
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: ENVISpacing.md) {
            Button { showHistory = true } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 24, height: 24)
            }

            Spacer()

            modeToggle

            Spacer()

            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 24, height: 24)
            }
        }
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(ExploreMode.allCases, id: \.self) { mode in
                segmentButton(for: mode)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func segmentButton(for mode: ExploreMode) -> some View {
        let isSelected = selectedMode == mode

        return Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedMode = mode
            }
        } label: {
            Text(mode.rawValue)
                .font(.spaceMonoBold(11))
                .tracking(1.2)
                .foregroundColor(isSelected ? .black : .white.opacity(0.62))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chat History Sheet

/// Placeholder chat-history sheet. Listing the user's prior threads
/// lives in a larger piece of scope; for now this displays an empty
/// state so the Sketch-spec header icon has a real destination.
private struct ChatHistorySheet: View {
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
            .preferredColorScheme(.dark)
    }
}
#endif
