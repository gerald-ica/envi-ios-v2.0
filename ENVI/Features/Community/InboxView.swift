import SwiftUI

/// Unified community inbox with platform icons, sentiment badges, and quick reply.
struct InboxView: View {
    @ObservedObject var viewModel: CommunityViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                filterBar
                messageList
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .refreshable { await viewModel.loadInbox() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text("INBOX")
                    .font(.spaceMonoBold(17))
                    .tracking(-0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("\(viewModel.filteredMessages.count) messages")
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
            Spacer()
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                ForEach(InboxFilter.allCases) { filter in
                    filterChip(title: filter.displayName, isSelected: viewModel.inboxFilter == filter) {
                        viewModel.inboxFilter = filter
                        viewModel.platformFilter = nil
                        Task { await viewModel.loadInbox() }
                    }
                }

                Divider()
                    .frame(height: 20)

                ForEach(SocialPlatform.allCases) { platform in
                    platformChip(platform: platform)
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.interMedium(13))
                .foregroundColor(isSelected ? ENVITheme.background(for: colorScheme) : ENVITheme.text(for: colorScheme))
                .padding(.horizontal, ENVISpacing.md)
                .padding(.vertical, ENVISpacing.sm)
                .background(isSelected ? ENVITheme.text(for: colorScheme) : ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .strokeBorder(isSelected ? Color.clear : ENVITheme.border(for: colorScheme), lineWidth: 1)
                )
        }
    }

    private func platformChip(platform: SocialPlatform) -> some View {
        let isSelected = viewModel.platformFilter == platform
        return Button {
            viewModel.platformFilter = isSelected ? nil : platform
        } label: {
            Image(systemName: platform.iconName)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? ENVITheme.background(for: colorScheme) : ENVITheme.text(for: colorScheme))
                .frame(width: 32, height: 32)
                .background(isSelected ? ENVITheme.text(for: colorScheme) : ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .strokeBorder(isSelected ? Color.clear : ENVITheme.border(for: colorScheme), lineWidth: 1)
                )
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        LazyVStack(spacing: ENVISpacing.md) {
            if viewModel.isLoadingInbox {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if viewModel.filteredMessages.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.filteredMessages) { message in
                    messageCard(message)
                }
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            Text("No messages")
                .font(.interMedium(15))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Message Card

    private func messageCard(_ message: InboxMessage) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Top row: platform icon + sender + timestamp + sentiment
            HStack(spacing: ENVISpacing.sm) {
                Image(systemName: message.platform.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text(message.senderName)
                    .font(.interMedium(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineLimit(1)

                if !message.isRead {
                    Circle()
                        .fill(ENVITheme.text(for: colorScheme))
                        .frame(width: 6, height: 6)
                }

                Spacer()

                sentimentBadge(message.sentiment)

                Text(message.timestamp, style: .relative)
                    .font(.spaceMono(10))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            // Message text
            Text(message.text)
                .font(.spaceMono(12))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .lineLimit(2)

            // Actions row
            HStack(spacing: ENVISpacing.md) {
                Button {
                    viewModel.selectedMessage = message
                } label: {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                        .font(.spaceMono(11))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }

                Button {
                    Task { await viewModel.toggleMessageFlag(message) }
                } label: {
                    Label(message.isFlagged ? "Unflag" : "Flag", systemImage: message.isFlagged ? "flag.fill" : "flag")
                        .font(.spaceMono(11))
                        .foregroundColor(message.isFlagged ? ENVITheme.warning : ENVITheme.textSecondary(for: colorScheme))
                }

                Spacer()

                if !message.isRead {
                    Button {
                        Task { await viewModel.markMessageRead(message) }
                    } label: {
                        Text("Mark read")
                            .font(.spaceMono(10))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }
                }
            }

            // Quick reply panel (shown when selected)
            if viewModel.selectedMessage?.id == message.id {
                quickReplyPanel(message)
            }
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Sentiment Badge

    private func sentimentBadge(_ sentiment: MessageSentiment) -> some View {
        let color: Color = {
            switch sentiment {
            case .positive: return ENVITheme.success
            case .neutral:  return ENVITheme.textSecondary(for: colorScheme)
            case .negative: return ENVITheme.error
            }
        }()
        return Image(systemName: sentiment.iconName)
            .font(.system(size: 12))
            .foregroundColor(color)
    }

    // MARK: - Quick Reply Panel

    private func quickReplyPanel(_ message: InboxMessage) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.sm) {
                    ForEach(viewModel.quickReplies) { reply in
                        Button {
                            viewModel.applyQuickReply(reply)
                        } label: {
                            Text(reply.label)
                                .font(.spaceMono(10))
                                .foregroundColor(ENVITheme.text(for: colorScheme))
                                .padding(.horizontal, ENVISpacing.md)
                                .padding(.vertical, ENVISpacing.xs)
                                .background(ENVITheme.surfaceHigh(for: colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                        }
                    }
                }
            }

            HStack(spacing: ENVISpacing.sm) {
                TextField("Type a reply...", text: $viewModel.replyText)
                    .font(.spaceMono(12))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .textFieldStyle(.plain)

                Button {
                    Task { await viewModel.sendReply(to: message) }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14))
                        .foregroundColor(viewModel.replyText.isEmpty ? ENVITheme.textSecondary(for: colorScheme) : ENVITheme.text(for: colorScheme))
                }
                .disabled(viewModel.replyText.isEmpty || viewModel.isSendingReply)
            }
            .padding(ENVISpacing.sm)
            .background(ENVITheme.background(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.md)
                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
            )
        }
    }
}
