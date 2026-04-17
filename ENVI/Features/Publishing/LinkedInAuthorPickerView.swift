//
//  LinkedInAuthorPickerView.swift
//  ENVI
//
//  Phase 11 — LinkedIn Connector (v1.1 Real Social Connectors).
//
//  Radio-selector sheet: "Post to LinkedIn as…". Shown from the compose
//  flow when the user has a LinkedIn connection and either (a) admin
//  privileges on at least one company page or (b) the capability to
//  upgrade to those scopes.
//
//  Interaction
//  -----------
//  - Member row at the top (always present while connected).
//  - Organization rows below (present when `w_organization_social` is
//    granted). Sorted by localized name.
//  - "Unlock company pages" row shown only when the scope is absent —
//    tapping it fires `upgradeToOrganizationScopes()` and the picker
//    re-enters loading state while the OAuth round-trip runs.
//  - "Cancel" dismisses without calling `onSelect`.
//  - "Confirm" calls `onSelect(selectedAuthor)` then dismisses.
//
//  Accessibility
//  -------------
//  Each row is a single accessibility element with a combined label
//  ("Personal profile, ENVI User") and a `.isSelected` trait when
//  current. Screen readers announce selection changes via
//  `@Published` → SwiftUI's built-in diffing.
//

import SwiftUI

@MainActor
struct LinkedInAuthorPickerView: View {

    // MARK: - Inputs

    /// Invoked with the final selection when the user taps "Confirm".
    let onSelect: (LinkedInAuthorOption) -> Void

    /// Dismissal hook — called for both Cancel and Confirm, so the host
    /// doesn't have to thread a binding.
    let onDismiss: () -> Void

    // MARK: - State

    @StateObject private var viewModel: LinkedInAuthorPickerViewModel

    @MainActor
    init(
        onSelect: @escaping (LinkedInAuthorOption) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: LinkedInAuthorPickerViewModel())
        self.onSelect = onSelect
        self.onDismiss = onDismiss
    }

    init(
        viewModel: LinkedInAuthorPickerViewModel,
        onSelect: @escaping (LinkedInAuthorOption) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSelect = onSelect
        self.onDismiss = onDismiss
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Post to LinkedIn as…")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { onDismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Confirm") {
                            if let selection = viewModel.selectedAuthor {
                                onSelect(selection)
                            }
                            onDismiss()
                        }
                        .disabled(viewModel.selectedAuthor == nil || viewModel.isLoading)
                    }
                }
                .task { await viewModel.load() }
                .refreshable { await viewModel.load() }
        }
    }

    // MARK: - Content branches

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.authorOptions.isEmpty {
            ProgressView("Loading LinkedIn accounts…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("Accounts") {
                    ForEach(viewModel.authorOptions, id: \.id) { option in
                        authorRow(for: option)
                    }
                }

                if !viewModel.canPostAsOrganization {
                    Section {
                        lockedUpgradeRow
                    } footer: {
                        Text("Posting to company pages requires LinkedIn Marketing Developer Platform approval (1–5 business days).")
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    // MARK: - Rows

    private func authorRow(for option: LinkedInAuthorOption) -> some View {
        Button {
            viewModel.selectedAuthor = option
        } label: {
            HStack(spacing: 12) {
                avatar(for: option)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(option.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: viewModel.selectedAuthor == option
                      ? "largecircle.fill.circle"
                      : "circle")
                    .font(.title3)
                    .foregroundStyle(viewModel.selectedAuthor == option
                                     ? Color.accentColor
                                     : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(viewModel.selectedAuthor == option ? .isSelected : [])
    }

    private var lockedUpgradeRow: some View {
        Button {
            Task { await viewModel.upgradeToOrganizationScopes() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock company pages")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("Grants LinkedIn permission to post as your organizations.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
    }

    // MARK: - Avatar

    @ViewBuilder
    private func avatar(for option: LinkedInAuthorOption) -> some View {
        let diameter: CGFloat = 36
        switch option {
        case .member:
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: diameter, height: diameter)
                .foregroundStyle(Color.accentColor.opacity(0.8))
        case .organization:
            // Logo URN → HTTPS URL resolution is Phase 13; fall back to a
            // monogram tile until then so the row doesn't look broken.
            Image(systemName: "building.2.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: diameter, height: diameter)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LinkedInAuthorPickerView_Previews: PreviewProvider {
    static var previews: some View {
        LinkedInAuthorPickerView(
            onSelect: { _ in },
            onDismiss: { }
        )
        .previewDisplayName("LinkedIn — Author Picker")
    }
}
#endif
