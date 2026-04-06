import SwiftUI

/// Support center with ticket list, FAQ browser, and new ticket creation.
struct SupportCenterView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: SupportTab = .tickets
    @State private var tickets: [SupportTicket] = SupportTicket.mockList
    @State private var faqs: [FAQArticle] = FAQArticle.mockList
    @State private var showingNewTicket = false
    @State private var newSubject = ""
    @State private var newDescription = ""
    @State private var newPriority: TicketPriority = .medium
    @State private var expandedFAQ: UUID?
    @State private var searchText = ""

    private enum SupportTab: String, CaseIterable {
        case tickets = "Tickets"
        case faq = "FAQ"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                tabBar
                if selectedTab == .tickets {
                    ticketSection
                } else {
                    faqSection
                }
            }
            .padding(ENVISpacing.lg)
        }
        .background(ENVITheme.background(for: colorScheme).ignoresSafeArea())
        .overlay {
            if showingNewTicket {
                newTicketOverlay
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("SUPPORT")
                .font(.spaceMono(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Get help and find answers")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(SupportTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    Text(tab.rawValue.uppercased())
                        .font(.spaceMono(12))
                        .tracking(1)
                        .foregroundColor(selectedTab == tab
                            ? ENVITheme.text(for: colorScheme)
                            : ENVITheme.textSecondary(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ENVISpacing.sm)
                        .background(selectedTab == tab
                            ? ENVITheme.surfaceHigh(for: colorScheme)
                            : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                }
            }
        }
        .padding(ENVISpacing.xs)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
    }

    // MARK: - Tickets

    private var ticketSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            HStack {
                Text("\(tickets.count) TICKETS")
                    .font(.spaceMono(13))
                    .tracking(1)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Spacer()

                Button {
                    withAnimation { showingNewTicket = true }
                } label: {
                    HStack(spacing: ENVISpacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                        Text("New")
                            .font(.spaceMono(12))
                    }
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.md)
                    .padding(.vertical, ENVISpacing.sm)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                }
            }

            ForEach(tickets) { ticket in
                ticketRow(ticket)
            }
        }
    }

    private func ticketRow(_ ticket: SupportTicket) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack {
                Image(systemName: ticket.status.iconName)
                    .font(.system(size: 12))
                    .foregroundColor(ticketStatusColor(ticket.status))

                Text(ticket.subject)
                    .font(.spaceMonoBold(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineLimit(1)

                Spacer()

                Text(ticket.priority.displayName.uppercased())
                    .font(.spaceMono(9))
                    .tracking(1)
                    .foregroundColor(priorityColor(ticket.priority))
            }

            Text(ticket.description)
                .font(.interRegular(12))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .lineLimit(2)

            HStack {
                Text(ticket.status.displayName)
                    .font(.spaceMono(10))
                    .foregroundColor(ticketStatusColor(ticket.status))

                Spacer()

                Text(relativeDate(ticket.createdAt))
                    .font(.spaceMono(10))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                if !ticket.messages.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 10))
                        Text("\(ticket.messages.count)")
                            .font(.spaceMono(10))
                    }
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
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

    // MARK: - FAQ

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Search
            HStack(spacing: ENVISpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                TextField("Search articles", text: $searchText)
                    .font(.interRegular(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
            }
            .padding(ENVISpacing.md)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.md)
                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
            )

            ForEach(filteredFAQs) { article in
                faqRow(article)
            }
        }
    }

    private var filteredFAQs: [FAQArticle] {
        if searchText.isEmpty { return faqs }
        return faqs.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func faqRow(_ article: FAQArticle) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedFAQ = expandedFAQ == article.id ? nil : article.id
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(article.category.uppercased())
                            .font(.spaceMono(9))
                            .tracking(1)
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                        Text(article.title)
                            .font(.spaceMonoBold(13))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: expandedFAQ == article.id ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }

            if expandedFAQ == article.id {
                Text(article.body)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .padding(.top, ENVISpacing.xs)

                HStack {
                    Spacer()
                    HStack(spacing: ENVISpacing.xs) {
                        Image(systemName: "hand.thumbsup")
                            .font(.system(size: 11))
                        Text("\(article.helpfulness)")
                            .font(.spaceMono(10))
                    }
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
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

    // MARK: - New Ticket Overlay

    private var newTicketOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showingNewTicket = false }
                }

            VStack(alignment: .leading, spacing: ENVISpacing.lg) {
                HStack {
                    Text("NEW TICKET")
                        .font(.spaceMono(16))
                        .tracking(-0.5)
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Spacer()

                    Button {
                        withAnimation { showingNewTicket = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }
                }

                VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                    Text("SUBJECT")
                        .font(.spaceMono(10))
                        .tracking(1.5)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    TextField("Brief summary", text: $newSubject)
                        .font(.interRegular(14))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .padding(ENVISpacing.md)
                        .background(ENVITheme.surfaceHigh(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                }

                VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                    Text("DESCRIPTION")
                        .font(.spaceMono(10))
                        .tracking(1.5)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    TextField("Describe your issue", text: $newDescription, axis: .vertical)
                        .font(.interRegular(14))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .lineLimit(4...8)
                        .padding(ENVISpacing.md)
                        .background(ENVITheme.surfaceHigh(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                }

                VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                    Text("PRIORITY")
                        .font(.spaceMono(10))
                        .tracking(1.5)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    HStack(spacing: ENVISpacing.sm) {
                        ForEach(TicketPriority.allCases) { priority in
                            Button {
                                newPriority = priority
                            } label: {
                                Text(priority.displayName)
                                    .font(.spaceMono(11))
                                    .foregroundColor(newPriority == priority
                                        ? ENVITheme.text(for: colorScheme)
                                        : ENVITheme.textSecondary(for: colorScheme))
                                    .padding(.horizontal, ENVISpacing.md)
                                    .padding(.vertical, ENVISpacing.sm)
                                    .background(newPriority == priority
                                        ? ENVITheme.surfaceHigh(for: colorScheme)
                                        : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                            }
                        }
                    }
                }

                Button {
                    guard !newSubject.isEmpty else { return }
                    let ticket = SupportTicket(
                        subject: newSubject,
                        description: newDescription,
                        priority: newPriority
                    )
                    withAnimation {
                        tickets.insert(ticket, at: 0)
                        newSubject = ""
                        newDescription = ""
                        newPriority = .medium
                        showingNewTicket = false
                    }
                } label: {
                    Text("Submit Ticket")
                        .font(.spaceMono(14))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ENVISpacing.md)
                        .background(ENVITheme.surfaceHigh(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                        )
                }
            }
            .padding(ENVISpacing.xl)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.xl))
            .padding(.horizontal, ENVISpacing.lg)
        }
    }

    // MARK: - Helpers

    private func ticketStatusColor(_ status: TicketStatus) -> Color {
        switch status {
        case .open:              return ENVITheme.info
        case .inProgress:        return ENVITheme.warning
        case .waitingOnCustomer: return ENVITheme.warning
        case .resolved:          return ENVITheme.success
        case .closed:            return ENVITheme.textSecondary(for: colorScheme)
        }
    }

    private func priorityColor(_ priority: TicketPriority) -> Color {
        switch priority {
        case .low:    return ENVITheme.textSecondary(for: colorScheme)
        case .medium: return ENVITheme.text(for: colorScheme)
        case .high:   return ENVITheme.warning
        case .urgent: return ENVITheme.error
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    SupportCenterView()
        .preferredColorScheme(.dark)
}
