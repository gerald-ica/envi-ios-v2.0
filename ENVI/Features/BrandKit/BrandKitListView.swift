import SwiftUI

/// Grid of brand kit cards with create action.
struct BrandKitListView: View {
    @ObservedObject var viewModel: BrandKitViewModel
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: ENVISpacing.md),
        GridItem(.flexible(), spacing: ENVISpacing.md),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header

                if viewModel.isLoadingBrandKits {
                    ENVILoadingState()
                } else if viewModel.brandKits.isEmpty {
                    emptyState
                } else {
                    brandKitGrid
                }

                if let error = viewModel.brandKitError {
                    Text(error)
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.error)
                        .padding(.horizontal, ENVISpacing.xl)
                }
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .sheet(isPresented: $viewModel.isShowingBrandKitEditor) {
            if let kit = viewModel.editingBrandKit {
                BrandKitEditorView(
                    brandKit: kit,
                    onSave: { updated in
                        Task { await viewModel.saveBrandKit(updated) }
                    },
                    onCancel: {
                        viewModel.isShowingBrandKitEditor = false
                        viewModel.editingBrandKit = nil
                    }
                )
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text("BRAND KITS")
                    .font(.spaceMonoBold(17))
                    .tracking(-0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("\(viewModel.brandKits.count) kits")
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            Button(action: { viewModel.startCreatingBrandKit() }) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .frame(width: 36, height: 36)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                            .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Grid

    private var brandKitGrid: some View {
        LazyVGrid(columns: columns, spacing: ENVISpacing.md) {
            ForEach(viewModel.brandKits) { kit in
                BrandKitCardView(brandKit: kit)
                    .onTapGesture { viewModel.startEditingBrandKit(kit) }
                    .contextMenu {
                        Button("Edit") { viewModel.startEditingBrandKit(kit) }
                        Button("Delete", role: .destructive) {
                            Task { await viewModel.deleteBrandKit(kit) }
                        }
                    }
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ENVISpacing.md) {
            Image(systemName: "paintpalette")
                .font(.system(size: 32))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("No brand kits yet")
                .font(.interMedium(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Create a brand kit to define your visual identity and content style.")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)

            ENVIButton("Create Brand Kit", variant: .secondary, isFullWidth: false) {
                viewModel.startCreatingBrandKit()
            }
        }
        .padding(ENVISpacing.xxxl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Brand Kit Card

private struct BrandKitCardView: View {
    let brandKit: BrandKit
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            // Color strip preview
            HStack(spacing: 0) {
                Rectangle().fill(Color(hex: brandKit.primaryColor))
                Rectangle().fill(Color(hex: brandKit.secondaryColor))
                Rectangle().fill(Color(hex: brandKit.accentColor))
                Rectangle().fill(Color(hex: brandKit.backgroundColor))
            }
            .frame(height: 40)
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))

            // Name
            Text(brandKit.name)
                .font(.interSemiBold(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .lineLimit(1)

            // Voice tone
            Text(brandKit.voiceTone.uppercased())
                .font(.spaceMono(10))
                .tracking(1.0)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            // Hashtags preview
            if !brandKit.hashtags.isEmpty {
                Text(brandKit.hashtags.prefix(3).joined(separator: " "))
                    .font(.interRegular(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .lineLimit(1)
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
}

#Preview {
    BrandKitListView(viewModel: BrandKitViewModel())
        .preferredColorScheme(.dark)
}
