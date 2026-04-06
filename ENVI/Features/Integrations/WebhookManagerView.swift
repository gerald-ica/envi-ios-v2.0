import SwiftUI

/// Webhook list with event selector, URL input, and test button (ENVI-0841..0845).
struct WebhookManagerView: View {

    @StateObject private var viewModel = IntegrationViewModel()
    @Environment(\.colorScheme) private var colorScheme

    @State private var showCreateSheet = false
    @State private var newURL = ""
    @State private var selectedEvents: Set<WebhookEvent> = []

    var body: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.xxl) {
                header
                statsRow
                createButton
                webhookList
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .sheet(isPresented: $showCreateSheet) { createSheet }
        .task { await viewModel.loadWebhooks() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: ENVISpacing.sm) {
            Text("WEBHOOKS")
                .font(.spaceMonoBold(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Receive real-time event notifications")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: ENVISpacing.md) {
            miniStat(label: "TOTAL", value: "\(viewModel.webhooks.count)")
            miniStat(label: "ACTIVE", value: "\(viewModel.activeWebhookCount)")
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(spacing: ENVISpacing.xs) {
            Text(value)
                .font(.spaceMonoBold(18))
                .foregroundColor(ENVITheme.text(for: colorScheme))
            Text(label)
                .font(.spaceMono(9))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    // MARK: - Create Button

    private var createButton: some View {
        Button {
            showCreateSheet = true
        } label: {
            HStack(spacing: ENVISpacing.sm) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text("NEW WEBHOOK")
                    .font(.spaceMonoBold(12))
                    .tracking(0.44)
            }
            .foregroundColor(ENVITheme.background(for: colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, ENVISpacing.md)
            .background(ENVITheme.text(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Webhook List

    private var webhookList: some View {
        Group {
            if viewModel.isLoadingWebhooks {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if viewModel.webhooks.isEmpty {
                VStack(spacing: ENVISpacing.sm) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 28))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    Text("No webhooks configured")
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                LazyVStack(spacing: ENVISpacing.sm) {
                    ForEach(viewModel.webhooks) { webhook in
                        webhookCard(webhook)
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }
        }
    }

    private func webhookCard(_ webhook: WebhookConfig) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            // URL + status
            HStack {
                Image(systemName: "link")
                    .font(.system(size: 11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                Text(webhook.url)
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Text(webhook.isActive ? "ACTIVE" : "INACTIVE")
                    .font(.spaceMono(8))
                    .tracking(0.44)
                    .foregroundColor(webhook.isActive ? ENVITheme.success : ENVITheme.textSecondary(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.xs)
                    .padding(.vertical, 2)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }

            // Events
            FlowLayout(spacing: ENVISpacing.xs) {
                ForEach(webhook.events) { event in
                    Text(event.displayName)
                        .font(.spaceMono(9))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        .padding(.horizontal, ENVISpacing.sm)
                        .padding(.vertical, 3)
                        .background(ENVITheme.surfaceHigh(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                }
            }

            // Secret + last triggered
            HStack {
                Text("Secret: \(webhook.maskedSecret)")
                    .font(.spaceMono(9))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Spacer()

                if let last = webhook.lastTriggeredAt {
                    Text("Last: \(last, style: .relative) ago")
                        .font(.spaceMono(9))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }

            // Actions
            HStack(spacing: ENVISpacing.sm) {
                Button {
                    viewModel.testWebhook(id: webhook.id)
                } label: {
                    HStack(spacing: ENVISpacing.xs) {
                        Image(systemName: "paperplane")
                            .font(.system(size: 10))
                        Text("TEST")
                            .font(.spaceMonoBold(10))
                            .tracking(0.44)
                    }
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.md)
                    .padding(.vertical, ENVISpacing.sm)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                }

                Spacer()

                Button {
                    Task { await viewModel.deleteWebhook(id: webhook.id) }
                } label: {
                    HStack(spacing: ENVISpacing.xs) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                        Text("DELETE")
                            .font(.spaceMonoBold(10))
                            .tracking(0.44)
                    }
                    .foregroundColor(ENVITheme.error)
                    .padding(.horizontal, ENVISpacing.md)
                    .padding(.vertical, ENVISpacing.sm)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                }
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Create Sheet

    private var createSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                    // URL input
                    VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                        Text("ENDPOINT URL")
                            .font(.spaceMonoBold(11))
                            .tracking(0.88)
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                        TextField("https://example.com/webhook", text: $newURL)
                            .font(.spaceMono(13))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            .padding(ENVISpacing.md)
                            .background(ENVITheme.surfaceLow(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                    }

                    // Event selector
                    VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                        Text("EVENTS")
                            .font(.spaceMonoBold(11))
                            .tracking(0.88)
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                        LazyVStack(spacing: ENVISpacing.xs) {
                            ForEach(WebhookEvent.allCases) { event in
                                eventRow(event)
                            }
                        }
                    }
                }
                .padding(ENVISpacing.xl)
            }
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle("New Webhook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCreateSheet = false }
                        .font(.interRegular(14))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await viewModel.createWebhook(url: newURL, events: Array(selectedEvents))
                            newURL = ""
                            selectedEvents = []
                            showCreateSheet = false
                        }
                    }
                    .font(.spaceMonoBold(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .disabled(newURL.isEmpty || selectedEvents.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func eventRow(_ event: WebhookEvent) -> some View {
        let isSelected = selectedEvents.contains(event)
        return Button {
            if isSelected {
                selectedEvents.remove(event)
            } else {
                selectedEvents.insert(event)
            }
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? ENVITheme.text(for: colorScheme) : ENVITheme.textSecondary(for: colorScheme))

                Text(event.displayName)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                Text(event.rawValue)
                    .font(.spaceMono(9))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
            .padding(ENVISpacing.sm)
            .background(isSelected ? ENVITheme.surfaceLow(for: colorScheme) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
        }
    }
}

// MARK: - Flow Layout

/// Simple horizontal flow layout for wrapping tags/chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

#Preview {
    WebhookManagerView()
        .preferredColorScheme(.dark)
}
