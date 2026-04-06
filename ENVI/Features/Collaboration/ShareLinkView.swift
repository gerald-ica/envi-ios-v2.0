import SwiftUI

/// View for generating share links with permission picker, expiry date, copy URL, and view count.
struct ShareLinkView: View {
    @ObservedObject var viewModel: CollaborationViewModel
    let contentID: UUID

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            header
            permissionPicker
            expiryPicker
            generateButton

            if let link = viewModel.generatedShareLink {
                linkResult(link)
            }

            Spacer()
        }
        .padding(ENVISpacing.xl)
        .background(ENVITheme.background(for: colorScheme))
        .navigationTitle("Share Link")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text("SHARE CONTENT")
                .font(.spaceMonoBold(17))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Generate a shareable link with custom permissions.")
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Permission Picker

    private var permissionPicker: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("PERMISSIONS")
                .font(.spaceMonoBold(11))
                .tracking(-0.3)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            HStack(spacing: ENVISpacing.sm) {
                ForEach(SharePermission.allCases) { permission in
                    permissionOption(permission)
                }
            }
        }
    }

    private func permissionOption(_ permission: SharePermission) -> some View {
        let isSelected = viewModel.sharePermission == permission
        return Button {
            viewModel.sharePermission = permission
        } label: {
            VStack(spacing: ENVISpacing.sm) {
                Image(systemName: permission.iconName)
                    .font(.system(size: 18))
                Text(permission.displayName)
                    .font(.interMedium(12))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ENVISpacing.lg)
            .foregroundColor(isSelected ? ENVITheme.background(for: colorScheme) : ENVITheme.text(for: colorScheme))
            .background(isSelected ? ENVITheme.text(for: colorScheme) : ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(isSelected ? Color.clear : ENVITheme.border(for: colorScheme), lineWidth: 1)
            )
        }
    }

    // MARK: - Expiry Picker

    private var expiryPicker: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("EXPIRES")
                .font(.spaceMonoBold(11))
                .tracking(-0.3)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            DatePicker(
                "Expiry date",
                selection: $viewModel.shareExpiryDate,
                in: Date()...,
                displayedComponents: [.date]
            )
            .font(.interRegular(14))
            .foregroundColor(ENVITheme.text(for: colorScheme))
            .labelsHidden()
            .padding(ENVISpacing.md)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.md)
                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
            )
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            Task { await viewModel.generateShareLink(for: contentID) }
        } label: {
            HStack(spacing: ENVISpacing.sm) {
                if viewModel.isGeneratingLink {
                    ProgressView()
                        .tint(ENVITheme.background(for: colorScheme))
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text("Generate Link")
                    .font(.interSemiBold(15))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ENVISpacing.lg)
            .foregroundColor(ENVITheme.background(for: colorScheme))
            .background(ENVITheme.text(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
        .disabled(viewModel.isGeneratingLink)
    }

    // MARK: - Link Result

    private func linkResult(_ link: ShareLink) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // URL display
            HStack {
                Text(link.url)
                    .font(.spaceMono(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button {
                    viewModel.copyLinkToClipboard()
                } label: {
                    Image(systemName: viewModel.linkCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(viewModel.linkCopied ? ENVITheme.success : ENVITheme.text(for: colorScheme))
                }
            }
            .padding(ENVISpacing.md)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.md)
                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
            )

            // Metadata
            HStack(spacing: ENVISpacing.lg) {
                Label {
                    Text(link.permissions.displayName)
                        .font(.spaceMono(11))
                } icon: {
                    Image(systemName: link.permissions.iconName)
                        .font(.system(size: 11))
                }

                if let expires = link.expiresAt {
                    Label {
                        Text(expires, style: .date)
                            .font(.spaceMono(11))
                    } icon: {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                    }
                }

                Label {
                    Text("\(link.viewCount) views")
                        .font(.spaceMono(11))
                } icon: {
                    Image(systemName: "eye")
                        .font(.system(size: 11))
                }

                Spacer()
            }
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
    }
}
