import SwiftUI

/// Browsable folder list with nested navigation, pinned folders, and CRUD actions.
struct FolderBrowserView: View {
    @ObservedObject var viewModel: LibraryDAMViewModel
    @Environment(\.colorScheme) private var colorScheme

    /// Current parent folder ID; nil means root level.
    var parentID: UUID? = nil

    @State private var newFolderName = ""
    @State private var renameName = ""
    @State private var folderToDelete: ContentFolder?
    @State private var showDeleteConfirmation = false

    private var currentFolders: [ContentFolder] {
        viewModel.childFolders(of: parentID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            if parentID == nil {
                HStack {
                    Text("FOLDERS")
                        .font(.spaceMonoBold(18))
                        .tracking(-1)
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Spacer()

                    Button {
                        viewModel.isShowingCreateFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
                .padding(.bottom, ENVISpacing.md)
            }

            if viewModel.isLoadingFolders {
                HStack {
                    ProgressView()
                    Text("Loading folders...")
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
                .padding(.horizontal, ENVISpacing.xl)
            } else if currentFolders.isEmpty {
                Text("No folders yet")
                    .font(.interRegular(14))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.xl)
                    .padding(.vertical, ENVISpacing.lg)
            } else {
                LazyVStack(spacing: ENVISpacing.sm) {
                    ForEach(currentFolders) { folder in
                        FolderRow(
                            folder: folder,
                            colorScheme: colorScheme,
                            onPin: {
                                Task { await viewModel.togglePin(folder) }
                            },
                            onRename: {
                                renameName = folder.name
                                viewModel.folderToRename = folder
                            },
                            onDelete: {
                                folderToDelete = folder
                                showDeleteConfirmation = true
                            }
                        )
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.interRegular(12))
                    .foregroundColor(.red)
                    .padding(.horizontal, ENVISpacing.xl)
                    .padding(.top, ENVISpacing.sm)
            }
        }
        .sheet(isPresented: $viewModel.isShowingCreateFolder) {
            CreateFolderSheet(
                colorScheme: colorScheme,
                onSave: { name in
                    Task { await viewModel.createFolder(name: name, parentID: parentID) }
                }
            )
            .presentationDetents([.height(220)])
        }
        .sheet(item: $viewModel.folderToRename) { folder in
            RenameFolderSheet(
                currentName: folder.name,
                colorScheme: colorScheme,
                onSave: { newName in
                    Task { await viewModel.renameFolder(folder, to: newName) }
                }
            )
            .presentationDetents([.height(220)])
        }
        .alert("Delete Folder", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let folder = folderToDelete {
                    Task { await viewModel.deleteFolder(folder) }
                }
            }
        } message: {
            Text("This will permanently remove the folder and its contents.")
        }
    }
}

// MARK: - Folder Row

private struct FolderRow: View {
    let folder: ContentFolder
    let colorScheme: ColorScheme
    let onPin: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        NavigationLink {
            FolderDetailDestination(folder: folder)
        } label: {
            HStack(spacing: ENVISpacing.md) {
                // Color dot
                Circle()
                    .fill(folderColor)
                    .frame(width: 10, height: 10)

                Image(systemName: "folder.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: ENVISpacing.xs) {
                        Text(folder.name)
                            .font(.interMedium(15))
                            .foregroundColor(ENVITheme.text(for: colorScheme))

                        if folder.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9))
                                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        }
                    }

                    Text("\(folder.itemCount) items")
                        .font(.interRegular(12))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
            .padding(.vertical, ENVISpacing.md)
            .padding(.horizontal, ENVISpacing.md)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
        .contextMenu {
            Button {
                onPin()
            } label: {
                Label(folder.isPinned ? "Unpin" : "Pin", systemImage: folder.isPinned ? "pin.slash" : "pin")
            }

            Button {
                onRename()
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var folderColor: Color {
        if let hex = folder.color {
            return Color(hex: hex)
        }
        return ENVITheme.textSecondary(for: colorScheme)
    }
}

// MARK: - Folder Detail (nested navigation destination)

private struct FolderDetailDestination: View {
    let folder: ContentFolder
    @StateObject private var viewModel = LibraryDAMViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                FolderBrowserView(viewModel: viewModel, parentID: folder.id)

                Text("\(folder.itemCount) assets in this folder")
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.xl)
            }
            .padding(.top, ENVISpacing.lg)
        }
        .background(ENVITheme.background(for: colorScheme))
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Create Folder Sheet

private struct CreateFolderSheet: View {
    let colorScheme: ColorScheme
    let onSave: (String) -> Void
    @State private var name = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: ENVISpacing.lg) {
            Text("NEW FOLDER")
                .font(.spaceMonoBold(16))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            TextField("Folder name", text: $name)
                .font(.interRegular(15))
                .padding(.horizontal, ENVISpacing.md)
                .padding(.vertical, ENVISpacing.sm)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))

            HStack(spacing: ENVISpacing.md) {
                Button("Cancel") {
                    dismiss()
                }
                .font(.interMedium(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Spacer()

                Button("Create") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(trimmed)
                    dismiss()
                }
                .font(.interSemiBold(14))
                .foregroundColor(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? ENVITheme.textSecondary(for: colorScheme)
                    : ENVITheme.text(for: colorScheme))
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(ENVISpacing.xl)
        .background(ENVITheme.background(for: colorScheme))
    }
}

// MARK: - Rename Folder Sheet

private struct RenameFolderSheet: View {
    let currentName: String
    let colorScheme: ColorScheme
    let onSave: (String) -> Void
    @State private var name: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: ENVISpacing.lg) {
            Text("RENAME FOLDER")
                .font(.spaceMonoBold(16))
                .tracking(-0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            TextField("Folder name", text: $name)
                .font(.interRegular(15))
                .padding(.horizontal, ENVISpacing.md)
                .padding(.vertical, ENVISpacing.sm)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))

            HStack(spacing: ENVISpacing.md) {
                Button("Cancel") {
                    dismiss()
                }
                .font(.interMedium(14))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Spacer()

                Button("Save") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(trimmed)
                    dismiss()
                }
                .font(.interSemiBold(14))
                .foregroundColor(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? ENVITheme.textSecondary(for: colorScheme)
                    : ENVITheme.text(for: colorScheme))
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(ENVISpacing.xl)
        .background(ENVITheme.background(for: colorScheme))
        .onAppear { name = currentName }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            FolderBrowserView(viewModel: LibraryDAMViewModel())
        }
    }
    .preferredColorScheme(.dark)
}
