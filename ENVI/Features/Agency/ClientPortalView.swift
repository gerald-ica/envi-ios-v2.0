import SwiftUI

/// Portal settings view with share URL, permissions toggles, and last-viewed info.
struct ClientPortalView: View {
    @ObservedObject var viewModel: AgencyViewModel
    let clientID: UUID
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                if viewModel.isLoadingPortal {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let portal = viewModel.portal {
                    shareLinkSection(portal)
                    permissionsSection(portal)
                    lastViewedSection(portal)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.error)
                        .padding(.horizontal, ENVISpacing.xl)
                }
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .task { await viewModel.loadPortal(for: clientID) }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text("CLIENT PORTAL")
                .font(.spaceMonoBold(17))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Manage portal access and permissions")
                .font(.spaceMono(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Share Link

    private func shareLinkSection(_ portal: ClientPortal) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("SHARE LINK")
                .font(.spaceMonoBold(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            VStack(spacing: ENVISpacing.md) {
                HStack {
                    Text(portal.shareURL)
                        .font(.spaceMono(12))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button {
                        viewModel.copyPortalLink()
                    } label: {
                        HStack(spacing: ENVISpacing.xs) {
                            Image(systemName: viewModel.portalLinkCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 12))
                            Text(viewModel.portalLinkCopied ? "Copied" : "Copy")
                                .font(.interMedium(12))
                        }
                        .foregroundColor(viewModel.portalLinkCopied ? ENVITheme.success : ENVITheme.text(for: colorScheme))
                        .padding(.horizontal, ENVISpacing.md)
                        .padding(.vertical, ENVISpacing.sm)
                        .background(ENVITheme.surfaceLow(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                        )
                    }
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
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Permissions

    private func permissionsSection(_ portal: ClientPortal) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("PERMISSIONS")
                .font(.spaceMonoBold(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            VStack(spacing: 0) {
                ForEach(PortalPermission.allCases) { permission in
                    permissionRow(permission, isEnabled: portal.permissions.contains(permission))

                    if permission != PortalPermission.allCases.last {
                        Divider()
                            .background(ENVITheme.border(for: colorScheme))
                    }
                }
            }
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
            )

            Button {
                Task { await viewModel.savePortal() }
            } label: {
                Text("Save Permissions")
                    .font(.interSemiBold(14))
                    .foregroundColor(ENVITheme.background(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ENVISpacing.md)
                    .background(ENVITheme.text(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func permissionRow(_ permission: PortalPermission, isEnabled: Bool) -> some View {
        Button {
            viewModel.togglePermission(permission)
        } label: {
            HStack(spacing: ENVISpacing.md) {
                Image(systemName: permission.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .frame(width: 24)

                Text(permission.displayName)
                    .font(.interRegular(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isEnabled ? ENVITheme.success : ENVITheme.textSecondary(for: colorScheme))
            }
            .padding(.horizontal, ENVISpacing.lg)
            .padding(.vertical, ENVISpacing.md)
        }
    }

    // MARK: - Last Viewed

    private func lastViewedSection(_ portal: ClientPortal) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("ACTIVITY")
                .font(.spaceMonoBold(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            HStack(spacing: ENVISpacing.md) {
                Image(systemName: "eye")
                    .font(.system(size: 14))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                if let lastViewed = portal.lastViewed {
                    VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                        Text("Last viewed")
                            .font(.interRegular(13))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                        Text(lastViewed, style: .relative)
                            .font(.spaceMono(13))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            + Text(" ago")
                            .font(.spaceMono(13))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                    }
                } else {
                    Text("Never viewed")
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                Spacer()
            }
            .padding(ENVISpacing.lg)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
            )
        }
        .padding(.horizontal, ENVISpacing.xl)
    }
}
