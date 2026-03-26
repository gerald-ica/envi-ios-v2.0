import SwiftUI

/// Floating glass-morphic search bar for the World Explorer view.
/// Filters visible nodes by title/tags via a callback — not coupled to SceneKit.
struct ExplorerSearchBar: View {
    @Binding var searchText: String
    var onSearchChanged: ((String) -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: ENVISpacing.sm) {
            // Magnifying glass icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            // Text field
            TextField("", text: $searchText, prompt: searchPrompt)
                .font(.spaceMono(13))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isFocused)
                .onChange(of: searchText) { _, newValue in
                    onSearchChanged?(newValue)
                }

            // Clear button
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    onSearchChanged?("")
                    HapticManager.shared.lightImpact()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
                .buttonStyle(.plain)
                .transition(.opacity.animation(.enviEaseOut))
            }
        }
        .padding(.horizontal, ENVISpacing.md)
        .padding(.vertical, ENVISpacing.sm + 2)
        .background(glassMorphicBackground)
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.md)
                .stroke(ENVITheme.border(for: colorScheme), lineWidth: 0.5)
        )
        .enviCardShadow()
        .padding(.horizontal, ENVISpacing.lg)
    }

    // MARK: - Helpers

    private var searchPrompt: Text {
        Text("SEARCH CONTENT...")
            .font(.spaceMono(13))
            .foregroundColor(.white.opacity(0.35))
    }

    private var glassMorphicBackground: some ShapeStyle {
        .ultraThinMaterial.opacity(0.85)
    }
}

// MARK: - Preview

#if DEBUG
struct ExplorerSearchBar_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                ExplorerSearchBar(searchText: .constant(""))
                ExplorerSearchBar(searchText: .constant("climate"))
            }
        }
        .preferredColorScheme(.dark)
    }
}
#endif
