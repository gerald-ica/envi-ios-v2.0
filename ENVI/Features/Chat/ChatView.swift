import SwiftUI

/// Main chat screen with home state and thread view.
struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Header pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.sm) {
                    HeaderPill(title: "Create", icon: "plus")
                    HeaderPill(title: "Insights", icon: "chart.bar")
                    HeaderPill(title: "Edit", icon: "slider.horizontal.3")
                    HeaderPill(title: "Schedule", icon: "calendar")
                }
                .padding(.horizontal, ENVISpacing.xl)
                .padding(.vertical, ENVISpacing.md)
            }

            // Content
            if viewModel.isHome {
                ChatHomeView(viewModel: viewModel)
            } else {
                ScrollView {
                    ThreadView(
                        messages: viewModel.messages,
                        onRelatedSelect: { question in
                            viewModel.inputText = question
                            viewModel.sendMessage()
                        }
                    )
                    .padding(.horizontal, ENVISpacing.xl)
                    .padding(.bottom, 100)
                }
            }

            Spacer(minLength: 0)

            // Input bar
            ChatInputBar(viewModel: viewModel)
        }
        .background(ENVITheme.background(for: colorScheme))
    }
}

private struct HeaderPill: View {
    let title: String
    let icon: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
            Text(title.uppercased())
                .font(.spaceMonoBold(11))
                .tracking(1.5)
        }
        .foregroundColor(ENVITheme.text(for: colorScheme))
        .padding(.horizontal, ENVISpacing.lg)
        .padding(.vertical, ENVISpacing.sm)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }
}

#Preview {
    ChatView()
        .preferredColorScheme(.dark)
}
