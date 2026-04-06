import SwiftUI

/// Invoice list showing billing history with date, amount, status badge,
/// and receipt download link.
struct BillingHistoryView: View {

    @ObservedObject var viewModel: BillingViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            // Header
            Text("BILLING HISTORY")
                .font(.spaceMonoBold(18))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .padding(.horizontal, ENVISpacing.xl)

            if viewModel.isLoadingHistory {
                HStack {
                    ProgressView()
                    Text("Loading invoices...")
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
                .padding(.horizontal, ENVISpacing.xl)
            } else if viewModel.billingHistory.isEmpty {
                emptyState
            } else {
                invoiceList
            }
        }
    }

    // MARK: - Invoice List

    private var invoiceList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.billingHistory.enumerated()), id: \.element.id) { index, entry in
                invoiceRow(entry)

                if index < viewModel.billingHistory.count - 1 {
                    Divider()
                        .background(ENVITheme.border(for: colorScheme))
                        .padding(.horizontal, ENVISpacing.md)
                }
            }
        }
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func invoiceRow(_ entry: BillingHistoryEntry) -> some View {
        HStack(spacing: ENVISpacing.md) {
            // Icon
            Circle()
                .fill(statusColor(entry.status).opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: statusIcon(entry.status))
                        .font(.system(size: 14))
                        .foregroundColor(statusColor(entry.status))
                )

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.description)
                    .font(.interMedium(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text(dateFormatter.string(from: entry.date))
                    .font(.interRegular(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            // Amount + status
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.formattedAmount)
                    .font(.spaceMonoBold(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                statusBadge(entry.status)
            }

            // Receipt button
            if let receiptURL = entry.receiptURL {
                Button {
                    openURL(receiptURL)
                } label: {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 14))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }
        }
        .padding(ENVISpacing.lg)
    }

    // MARK: - Status Badge

    private func statusBadge(_ status: BillingStatus) -> some View {
        Text(status.rawValue.uppercased())
            .font(.spaceMono(9))
            .tracking(0.5)
            .padding(.horizontal, ENVISpacing.sm)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.15))
            .foregroundColor(statusColor(status))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: "doc.text")
                .font(.system(size: 32))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("No billing history yet")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(ENVISpacing.xxxxl)
    }

    // MARK: - Helpers

    private func statusColor(_ status: BillingStatus) -> Color {
        switch status {
        case .paid:     return ENVITheme.success
        case .pending:  return ENVITheme.warning
        case .failed:   return ENVITheme.error
        case .refunded: return ENVITheme.info
        }
    }

    private func statusIcon(_ status: BillingStatus) -> String {
        switch status {
        case .paid:     return "checkmark.circle.fill"
        case .pending:  return "clock.fill"
        case .failed:   return "xmark.circle.fill"
        case .refunded: return "arrow.uturn.backward.circle.fill"
        }
    }
}

#Preview {
    ScrollView {
        BillingHistoryView(viewModel: BillingViewModel())
    }
    .preferredColorScheme(.dark)
}
