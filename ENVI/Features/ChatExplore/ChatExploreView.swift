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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            segmentedControl
            divider

            // Content area with crossfade
            ZStack {
                if selectedMode == .explore {
                    WorldExplorerView()
                        .transition(.opacity)
                } else {
                    EnhancedChatView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: selectedMode)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ENVITheme.background(for: colorScheme))
        .preferredColorScheme(.dark)
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
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedMode = mode
            }
        } label: {
            Text(mode.rawValue)
                .font(.custom("SpaceMono-Regular", size: 11))
                .tracking(11 * 0.15) // 0.15em relative to font size
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, ENVISpacing.sm)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                                .fill(ENVITheme.Dark.surfaceHigh)
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
            .fill(Color.white.opacity(0.08))
            .frame(height: 0.5)
    }
}

// MARK: - EnhancedChatView

struct EnhancedChatView: View {
    @StateObject private var viewModel = EnhancedChatViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isHome {
                EnhancedChatHomeView(viewModel: viewModel)
            } else {
                if viewModel.isTyping {
                    TypingDotsView()
                } else if let thread = viewModel.activeThread {
                    EnhancedThreadView(thread: thread, onRelatedQuestion: { q in
                        viewModel.startThread(q)
                    })
                }
            }
            Spacer(minLength: 0)
            EnhancedChatInputBar(onSend: { text in
                viewModel.inputText = text
                viewModel.startThread(text)
            })
        }
        .background(ENVITheme.background(for: colorScheme))
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
