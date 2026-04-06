import SwiftUI

/// Link-in-Bio editor with drag-to-reorder, theme picker, and live preview (ENVI-0691..0695).
struct LinkInBioEditorView: View {

    @StateObject private var viewModel = CommerceViewModel()
    @Environment(\.colorScheme) private var colorScheme

    @State private var showAddLink = false
    @State private var newLinkTitle = ""
    @State private var newLinkURL = ""

    var body: some View {
        ScrollView {
            VStack(spacing: ENVISpacing.xxl) {
                header
                statsStrip
                themePicker
                linkList
                previewSection
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .task { await viewModel.loadLinkInBio() }
        .sheet(isPresented: $showAddLink) { addLinkSheet }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: ENVISpacing.sm) {
            Text("LINK IN BIO")
                .font(.spaceMonoBold(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Drag to reorder, pick a theme, preview your page")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Stats

    private var statsStrip: some View {
        HStack(spacing: ENVISpacing.lg) {
            statPill(label: "LINKS", value: "\(viewModel.linkInBio?.links.count ?? 0)")
            statPill(label: "TOTAL CLICKS", value: "\(viewModel.totalBioClicks)")
            statPill(label: "THEME", value: (viewModel.linkInBio?.theme.displayName ?? "—").uppercased())
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: ENVISpacing.xs) {
            Text(label)
                .font(.spaceMono(9))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            Text(value)
                .font(.spaceMonoBold(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.sm)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }

    // MARK: - Theme Picker

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("THEME")
                .font(.spaceMonoBold(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .padding(.horizontal, ENVISpacing.xl)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.sm) {
                    ForEach(LinkInBioThemeName.allCases) { theme in
                        themeChip(theme)
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }
        }
    }

    private func themeChip(_ theme: LinkInBioThemeName) -> some View {
        let isSelected = viewModel.linkInBio?.theme == theme
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectTheme(theme)
            }
        } label: {
            Text(theme.displayName.uppercased())
                .font(.spaceMonoBold(11))
                .tracking(0.88)
                .foregroundColor(isSelected
                    ? ENVITheme.background(for: colorScheme)
                    : ENVITheme.text(for: colorScheme))
                .padding(.horizontal, ENVISpacing.lg)
                .padding(.vertical, ENVISpacing.sm)
                .background(isSelected
                    ? ENVITheme.text(for: colorScheme)
                    : ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
        }
    }

    // MARK: - Link List (Drag-to-Reorder)

    private var linkList: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack {
                Text("LINKS")
                    .font(.spaceMonoBold(11))
                    .tracking(0.88)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Spacer()

                Button {
                    showAddLink = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }
            }
            .padding(.horizontal, ENVISpacing.xl)

            if viewModel.isLoadingBio {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let links = viewModel.linkInBio?.links, !links.isEmpty {
                List {
                    ForEach(links) { link in
                        linkRow(link)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(
                                top: ENVISpacing.xs,
                                leading: ENVISpacing.xl,
                                bottom: ENVISpacing.xs,
                                trailing: ENVISpacing.xl
                            ))
                    }
                    .onMove { viewModel.moveBioLink(from: $0, to: $1) }
                    .onDelete { viewModel.deleteBioLink(at: $0) }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))
                .frame(minHeight: CGFloat(links.count) * 72)
                .scrollDisabled(true)
            } else {
                Text("No links yet. Tap + to add one.")
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .frame(maxWidth: .infinity, minHeight: 80)
            }

            // Save button
            Button {
                Task { await viewModel.saveLinkInBio() }
            } label: {
                HStack {
                    if viewModel.isSavingBio {
                        ProgressView()
                            .tint(ENVITheme.background(for: colorScheme))
                    }
                    Text("SAVE CHANGES")
                        .font(.spaceMonoBold(13))
                        .tracking(0.88)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ENVISpacing.md)
                .foregroundColor(ENVITheme.background(for: colorScheme))
                .background(ENVITheme.text(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            }
            .padding(.horizontal, ENVISpacing.xl)
            .disabled(viewModel.isSavingBio)
        }
    }

    private func linkRow(_ link: BioLink) -> some View {
        HStack(spacing: ENVISpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(link.title)
                    .font(.spaceMonoBold(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineLimit(1)
                Text(link.url)
                    .font(.interRegular(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .lineLimit(1)
            }

            Spacer()

            Text("\(link.clicks)")
                .font(.spaceMono(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Button {
                viewModel.toggleBioLink(link)
            } label: {
                Image(systemName: link.isActive ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 14))
                    .foregroundColor(link.isActive
                        ? ENVITheme.text(for: colorScheme)
                        : ENVITheme.textSecondary(for: colorScheme))
            }
            .buttonStyle(.plain)
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("PREVIEW")
                .font(.spaceMonoBold(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .padding(.horizontal, ENVISpacing.xl)

            VStack(spacing: ENVISpacing.sm) {
                if let links = viewModel.linkInBio?.links.filter({ $0.isActive }) {
                    ForEach(links) { link in
                        Text(link.title)
                            .font(.spaceMonoBold(13))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, ENVISpacing.md)
                            .background(ENVITheme.surfaceLow(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(ENVISpacing.lg)
            .background(ENVITheme.surfaceHigh(for: colorScheme).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.xl))
            .padding(.horizontal, ENVISpacing.xl)
        }
    }

    // MARK: - Add Link Sheet

    private var addLinkSheet: some View {
        NavigationStack {
            VStack(spacing: ENVISpacing.xl) {
                VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                    Text("TITLE")
                        .font(.spaceMonoBold(11))
                        .tracking(0.88)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    TextField("My Website", text: $newLinkTitle)
                        .font(.interRegular(15))
                        .padding(ENVISpacing.md)
                        .background(ENVITheme.surfaceLow(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                }

                VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                    Text("URL")
                        .font(.spaceMonoBold(11))
                        .tracking(0.88)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    TextField("https://", text: $newLinkURL)
                        .font(.interRegular(15))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .padding(ENVISpacing.md)
                        .background(ENVITheme.surfaceLow(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                }

                Spacer()
            }
            .padding(ENVISpacing.xl)
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle("Add Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddLink = false
                        newLinkTitle = ""
                        newLinkURL = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addBioLink(title: newLinkTitle, url: newLinkURL)
                        showAddLink = false
                        newLinkTitle = ""
                        newLinkURL = ""
                    }
                    .disabled(newLinkTitle.isEmpty || newLinkURL.isEmpty)
                }
            }
        }
    }
}

#Preview {
    LinkInBioEditorView()
        .preferredColorScheme(.dark)
}
