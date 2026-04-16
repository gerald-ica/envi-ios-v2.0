import SwiftUI

/// CRM contact list with engagement scores, segment tags, and search.
struct ContactListView: View {
    @ObservedObject var viewModel: CommunityViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                searchBar
                segmentSummary
                contactList
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .refreshable { await viewModel.loadContacts() }
        .task { await viewModel.loadContacts() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text("AUDIENCE")
                    .font(.spaceMonoBold(17))
                    .tracking(-0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("\(viewModel.filteredContacts.count) contacts")
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
            Spacer()
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: ENVISpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            TextField("Search contacts...", text: $viewModel.contactSearchText)
                .font(.spaceMono(13))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .textFieldStyle(.plain)

            if !viewModel.contactSearchText.isEmpty {
                Button { viewModel.contactSearchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.md)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Segment Summary

    private var segmentSummary: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                ForEach(viewModel.segments) { segment in
                    segmentPill(segment)
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
        }
        .task { await viewModel.loadSegments() }
    }

    private func segmentPill(_ segment: AudienceSegment) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text(segment.name)
                .font(.interMedium(12))
                .foregroundColor(ENVITheme.text(for: colorScheme))
            Text("\(segment.memberCount) members")
                .font(.spaceMono(10))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.md)
        .padding(.vertical, ENVISpacing.sm)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Contact List

    private var contactList: some View {
        LazyVStack(spacing: ENVISpacing.md) {
            if viewModel.isLoadingContacts {
                ENVILoadingState()
            } else if viewModel.filteredContacts.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.filteredContacts) { contact in
                    NavigationLink(value: contact.id) {
                        contactCard(contact)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 32))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            Text("No contacts found")
                .font(.interMedium(15))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Contact Card

    private func contactCard(_ contact: AudienceContact) -> some View {
        HStack(spacing: ENVISpacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(ENVITheme.surfaceHigh(for: colorScheme))
                    .frame(width: 40, height: 40)
                Text(String(contact.name.prefix(1)).uppercased())
                    .font(.interMedium(16))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
            }

            // Info
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                HStack(spacing: ENVISpacing.sm) {
                    Text(contact.name)
                        .font(.interMedium(14))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Spacer()

                    engagementBadge(contact.engagementScore)
                }

                // Platform icons
                HStack(spacing: ENVISpacing.xs) {
                    ForEach(contact.platforms) { platform in
                        Image(systemName: platform.iconName)
                            .font(.system(size: 11))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }

                    Spacer()

                    Text(contact.lastInteraction, style: .relative)
                        .font(.spaceMono(10))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                // Segment tags
                if !contact.segments.isEmpty {
                    HStack(spacing: ENVISpacing.xs) {
                        ForEach(contact.segments, id: \.self) { segment in
                            Text(segment)
                                .font(.spaceMono(9))
                                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                                .padding(.horizontal, ENVISpacing.sm)
                                .padding(.vertical, 2)
                                .background(ENVITheme.surfaceHigh(for: colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                        }
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Engagement Badge

    private func engagementBadge(_ score: Int) -> some View {
        let color: Color = {
            if score >= 80 { return ENVITheme.success }
            if score >= 50 { return ENVITheme.warning }
            return ENVITheme.error
        }()
        return HStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(score)")
                .font(.spaceMono(11))
                .foregroundColor(color)
        }
    }
}
