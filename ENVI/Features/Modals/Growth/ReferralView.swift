import SwiftUI

/// Referral dashboard showing the user's referral code, invite list, and earned rewards.
///
/// Phase 17 — Plan 01. Previously held `ReferralProgram.mock` and
/// `ReferralInvite.mockList` as `@State` defaults; now VM-driven via
/// `GrowthViewModel` and `GrowthRepository`.
struct ReferralView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: GrowthViewModel
    @State private var newEmail = ""
    @State private var showingInviteField = false
    @State private var codeCopied = false

    init(viewModel: GrowthViewModel = GrowthViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header

                if viewModel.isLoading && viewModel.referralProgram == nil {
                    ENVILoadingState()
                } else if let error = viewModel.errorMessage,
                          viewModel.referralProgram == nil {
                    ENVIErrorBanner(message: error)
                } else if let program = viewModel.referralProgram {
                    referralCodeCard(program)
                    rewardsRow(program)
                    inviteSection
                }
            }
            .padding(ENVISpacing.lg)
        }
        .background(ENVITheme.background(for: colorScheme).ignoresSafeArea())
        .task { await viewModel.loadReferrals() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("REFERRALS")
                .font(.spaceMono(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Invite friends and earn rewards")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Referral Code Card

    private func referralCodeCard(_ program: ReferralProgram) -> some View {
        VStack(spacing: ENVISpacing.md) {
            Text("YOUR CODE")
                .font(.spaceMono(10))
                .tracking(1.5)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text(program.code)
                .font(.spaceMonoBold(28))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Button {
                UIPasteboard.general.string = program.code
                withAnimation { codeCopied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { codeCopied = false }
                }
            } label: {
                HStack(spacing: ENVISpacing.sm) {
                    Image(systemName: codeCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                    Text(codeCopied ? "Copied" : "Copy Code")
                        .font(.spaceMono(12))
                }
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .padding(.horizontal, ENVISpacing.lg)
                .padding(.vertical, ENVISpacing.sm)
                .background(ENVITheme.surfaceHigh(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(ENVISpacing.xl)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Rewards Row

    private func rewardsRow(_ program: ReferralProgram) -> some View {
        HStack(spacing: ENVISpacing.md) {
            rewardStat(value: "\(program.referralCount)", label: "REFERRALS")
            rewardStat(value: String(format: "$%.0f", program.earnedRewards), label: "EARNED")
            rewardStat(value: program.rewardType.displayName.uppercased(), label: "REWARD TYPE")
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    private func rewardStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.spaceMonoBold(17))
                .foregroundColor(ENVITheme.text(for: colorScheme))
            Text(label)
                .font(.spaceMono(9))
                .tracking(1.5)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Invite Section

    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            HStack {
                Text("INVITES")
                    .font(.spaceMono(13))
                    .tracking(1)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Spacer()

                Button {
                    withAnimation { showingInviteField.toggle() }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }
            }

            if showingInviteField {
                inviteField
            }

            ForEach(viewModel.referralInvites) { invite in
                inviteRow(invite)
            }
        }
    }

    private var inviteField: some View {
        HStack(spacing: ENVISpacing.sm) {
            TextField("Email address", text: $newEmail)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)

            Button {
                guard !newEmail.isEmpty else { return }
                let email = newEmail
                newEmail = ""
                showingInviteField = false
                Task { await viewModel.sendInvite(email: email) }
            } label: {
                Text("Send")
                    .font(.spaceMono(12))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.md)
                    .padding(.vertical, ENVISpacing.sm)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.md)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    private func inviteRow(_ invite: ReferralInvite) -> some View {
        HStack(spacing: ENVISpacing.md) {
            ZStack {
                Circle()
                    .fill(ENVITheme.surfaceHigh(for: colorScheme))
                    .frame(width: 36, height: 36)
                Image(systemName: invite.status.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(statusColor(invite.status))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(invite.recipientEmail)
                    .font(.interRegular(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text(invite.status.displayName)
                    .font(.spaceMono(11))
                    .foregroundColor(statusColor(invite.status))
            }

            Spacer()

            Text(relativeDate(invite.sentAt))
                .font(.spaceMono(10))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func statusColor(_ status: ReferralInviteStatus) -> Color {
        switch status {
        case .accepted:  return ENVITheme.success
        case .pending:   return ENVITheme.warning
        case .expired:   return ENVITheme.error
        case .cancelled: return ENVITheme.textSecondary(for: colorScheme)
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    ReferralView(viewModel: .preview())
        .preferredColorScheme(.dark)
}
