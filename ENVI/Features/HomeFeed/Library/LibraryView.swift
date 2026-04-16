import SwiftUI
import PhotosUI

/// Main Library screen — matches Sketch artboard "12 - Library" (393×852).
///
/// Header: Search pill + "For you / Gallery" segmented switch + Content
/// Calendar icon (same pattern as the Feed tab). Body: two named
/// sections — "SAVED TEMPLATES" (carousel) and "SOCIAL MEDIA ARSENAL"
/// (masonry grid of approved items). A floating upload FAB at the
/// bottom-right opens PHPicker. Tapping the search icon presents an
/// inline dark search sheet ("Try 'OOTD short form video'").
struct LibraryView: View {

    @StateObject private var viewModel = LibraryViewModel()
    @State private var showMediaPicker = false
    @State private var showCalendar = false
    @State private var showSearch = false
    @State private var segmentIndex = 0

    @Environment(\.colorScheme) private var colorScheme

    private let segments = ["For You", "Gallery"]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AppBackground(imageName: "library-bg")

            VStack(spacing: 0) {
                header
                    .padding(.top, ENVISpacing.sm)
                    .padding(.horizontal, 16)
                    .padding(.bottom, ENVISpacing.sm)

                ScrollView {
                    VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                        savedTemplates
                        socialMediaArsenal
                    }
                    .padding(.top, ENVISpacing.md)
                    .padding(.bottom, 120)
                }
            }

            uploadFAB
                .padding(.trailing, 24)
                .padding(.bottom, 96)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showMediaPicker) {
            MediaPickerView { assetIdentifiers in
                guard !assetIdentifiers.isEmpty else { return }
                ContentPieceAssembler.shared.enqueueForAssembly(mediaIDs: assetIdentifiers)
            }
        }
        .sheet(isPresented: $showSearch) {
            LibrarySearchSheet(query: $viewModel.searchQuery)
        }
        .fullScreenCover(isPresented: $showCalendar) {
            ContentCalendarFullView()
        }
        .sheet(item: $viewModel.templateToApply) { template in
            ExportSheetView(composer: ExportComposerFactory.make(template: template))
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: ENVISpacing.md) {
            MainAppSearchPill { showSearch = true }

            Spacer(minLength: 0)

            MainAppTopSegmentSwitch(
                options: segments,
                selectedIndex: segmentIndex
            ) { idx in
                withAnimation(.easeInOut(duration: 0.2)) { segmentIndex = idx }
            }

            Spacer(minLength: 0)

            MainAppContentCalendarIcon { showCalendar = true }
        }
    }

    // MARK: - Sections

    private var savedTemplates: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("SAVED TEMPLATES")
                .padding(.horizontal, 20)

            TemplateCarousel(
                templates: viewModel.templates,
                onApply: { viewModel.applyTemplate($0) },
                onDuplicate: { t in Task { await viewModel.duplicateTemplate(t) } },
                onDelete: { t in Task { await viewModel.deleteTemplate(t) } }
            )
        }
    }

    private var socialMediaArsenal: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("SOCIAL MEDIA ARSENAL")
                .padding(.horizontal, 20)

            MasonryGridView(items: viewModel.filteredItems)
                .padding(.horizontal, 20)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.spaceMonoBold(11))
            .tracking(2.0)
            .foregroundColor(.white.opacity(0.55))
    }

    // MARK: - Upload FAB

    private var uploadFAB: some View {
        Button(action: { showMediaPicker = true }) {
            Image(systemName: "arrow.up.to.line")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 56, height: 56)
                .background(Color.white)
                .clipShape(Circle())
                .enviElevatedShadow()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search sheet

private struct LibrarySearchSheet: View {
    @Binding var query: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))

                    TextField(
                        "",
                        text: $query,
                        prompt: Text("Try \"OOTD short form video\"")
                            .foregroundColor(.white.opacity(0.4))
                    )
                    .font(.interRegular(14))
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                    Button("Cancel") { dismiss() }
                        .font(.spaceMonoBold(11))
                        .tracking(1.2)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color(hex: "#191919"))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - PHPicker wrapper

/// UIViewControllerRepresentable wrapping PHPickerViewController for importing media.
struct MediaPickerView: UIViewControllerRepresentable {
    let onPick: ([String]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 10
        config.filter = .any(of: [.images, .videos])
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: ([String]) -> Void

        init(onPick: @escaping ([String]) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            let identifiers = results.compactMap(\.assetIdentifier)
            onPick(identifiers)
        }
    }
}

#Preview {
    LibraryView()
        .preferredColorScheme(.dark)
}
