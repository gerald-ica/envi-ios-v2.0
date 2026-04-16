//
//  PageSelectorView.swift
//  ENVI
//
//  Phase 10 — Meta Family Connector, Facebook Page selector modal.
//
//  Presented as a sheet after the Facebook OAuth flow resolves, BEFORE the
//  broker-side connection is finalized. The user picks which Page they
//  want to publish as; selection posts to `/oauth/facebook/select-page`
//  and the broker encrypts + stores the per-Page access token.
//
//  States
//  ------
//  - loading — skeleton rows, no interaction
//  - loaded — list of Pages with selectable rows
//  - empty — "You don't have any Pages" + help link to Meta's create-page URL
//  - error — inline error banner + retry button
//

import SwiftUI

/// Sheet content that lets the user choose the Facebook Page ENVI will
/// publish to. Paired with `PageSelectorViewModel`.
struct PageSelectorView: View {

    // MARK: - Dependencies

    @StateObject private var viewModel: PageSelectorViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    /// Callback invoked with the user's choice outcome. `true` means the
    /// broker accepted the Page; caller typically also refreshes the
    /// connection list.
    private let onComplete: (Bool) -> Void

    // MARK: - Init

    init(
        viewModel: PageSelectorViewModel = PageSelectorViewModel(),
        onComplete: @escaping (Bool) -> Void
    ) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.onComplete = onComplete
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                content
            }
            .background(ENVITheme.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Choose a Facebook Page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onComplete(false)
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                continueBar
            }
            .task {
                await viewModel.loadPages()
            }
        }
    }

    // MARK: - Content State Machine

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            loadingList
        case .loaded(let pages):
            pageList(pages)
        case .empty:
            emptyState
        case .error(let message):
            errorState(message)
        }
    }

    // MARK: - Loading Skeleton

    private var loadingList: some View {
        VStack(spacing: ENVISpacing.sm) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .fill(ENVITheme.surfaceLow(for: colorScheme))
                    .frame(height: 68)
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.lg)
                            .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                    )
                    .redacted(reason: .placeholder)
            }
        }
        .padding(.horizontal, ENVISpacing.lg)
        .padding(.top, ENVISpacing.lg)
    }

    // MARK: - Page List

    private func pageList(_ pages: [MetaPageItem]) -> some View {
        ScrollView {
            VStack(spacing: ENVISpacing.sm) {
                ForEach(pages) { page in
                    pageRow(page)
                }

                // Always show the create-page link even when the user HAS
                // Pages — maybe they want to add a new brand Page.
                noPageLink
                    .padding(.top, ENVISpacing.lg)
            }
            .padding(.horizontal, ENVISpacing.lg)
            .padding(.top, ENVISpacing.lg)
            .padding(.bottom, ENVISpacing.xxxl)
        }
    }

    private func pageRow(_ page: MetaPageItem) -> some View {
        let isSelected = viewModel.selectedPageID == page.pageID
        let canPublish = page.canPublish

        return Button {
            guard canPublish else { return }
            viewModel.selectedPageID = page.pageID
        } label: {
            HStack(spacing: ENVISpacing.md) {
                Image(systemName: "f.square.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#1877F2"))
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(page.pageName)
                        .font(.spaceMonoBold(14))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    if let category = page.category {
                        Text(category)
                            .font(.spaceMono(11))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }

                    if !canPublish {
                        Text("Publishing permission not granted")
                            .font(.spaceMono(10))
                            .foregroundColor(ENVITheme.error)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(
                        isSelected
                            ? ENVITheme.primary(for: colorScheme)
                            : ENVITheme.textSecondary(for: colorScheme)
                    )
            }
            .padding(ENVISpacing.md)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(
                        isSelected
                            ? ENVITheme.primary(for: colorScheme)
                            : ENVITheme.border(for: colorScheme),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .opacity(canPublish ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!canPublish)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.lg) {
            Spacer()

            Image(systemName: "rectangle.stack.badge.person.crop")
                .font(.system(size: 42))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("No Facebook Pages Found")
                .font(.spaceMonoBold(16))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("You need a Facebook Page to publish with ENVI.")
                .font(.spaceMono(12))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)

            noPageLink

            Spacer()
        }
        .padding(ENVISpacing.lg)
    }

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        VStack(spacing: ENVISpacing.lg) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(ENVITheme.error)

            Text(message)
                .font(.spaceMono(12))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.loadPages() }
            } label: {
                Text("Retry")
                    .font(.spaceMonoBold(13))
                    .tracking(0.5)
                    .padding(.horizontal, ENVISpacing.xl)
                    .padding(.vertical, ENVISpacing.sm)
                    .background(ENVITheme.primary(for: colorScheme))
                    .foregroundColor(ENVITheme.background(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
            }

            Spacer()
        }
        .padding(ENVISpacing.lg)
    }

    // MARK: - Shared Helpers

    private var noPageLink: some View {
        Link(
            destination: URL(string: "https://www.facebook.com/pages/create")!
        ) {
            HStack(spacing: ENVISpacing.xs) {
                Image(systemName: "plus.circle")
                Text("I don't have a Page")
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 10))
            }
            .font(.spaceMono(12))
            .foregroundColor(ENVITheme.primary(for: colorScheme))
        }
    }

    // MARK: - Continue Bar

    private var continueBar: some View {
        VStack(spacing: ENVISpacing.sm) {
            if let error = viewModel.continueError {
                Text(error)
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.error)
            }

            Button {
                Task {
                    await viewModel.continueWithSelection { success in
                        if success { dismiss() }
                    }
                }
            } label: {
                HStack {
                    if viewModel.isContinuing {
                        ProgressView()
                            .tint(ENVITheme.background(for: colorScheme))
                    }
                    Text("Continue")
                        .font(.spaceMonoBold(14))
                        .tracking(0.5)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ENVISpacing.md)
                .background(
                    viewModel.selectedPageID == nil
                        ? ENVITheme.surfaceHigh(for: colorScheme)
                        : ENVITheme.primary(for: colorScheme)
                )
                .foregroundColor(
                    viewModel.selectedPageID == nil
                        ? ENVITheme.textSecondary(for: colorScheme)
                        : ENVITheme.background(for: colorScheme)
                )
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            }
            .disabled(viewModel.selectedPageID == nil || viewModel.isContinuing)
        }
        .padding(.horizontal, ENVISpacing.lg)
        .padding(.bottom, ENVISpacing.md)
        .padding(.top, ENVISpacing.sm)
        .background(
            ENVITheme.background(for: colorScheme)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
