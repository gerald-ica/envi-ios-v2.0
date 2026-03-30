import SwiftUI

/// Waterfall/masonry grid layout with 2 columns.
struct MasonryGridView: View {
    let items: [LibraryItem]
    var onTap: ((LibraryItem) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    private var columns: [[LibraryItem]] {
        var col1: [LibraryItem] = []
        var col2: [LibraryItem] = []
        var height1: CGFloat = 0
        var height2: CGFloat = 0

        for item in items {
            if height1 <= height2 {
                col1.append(item)
                height1 += item.height
            } else {
                col2.append(item)
                height2 += item.height
            }
        }
        return [col1, col2]
    }

    var body: some View {
        HStack(alignment: .top, spacing: ENVISpacing.md) {
            ForEach(0..<2, id: \.self) { colIndex in
                LazyVStack(spacing: ENVISpacing.md) {
                    ForEach(columns[colIndex]) { item in
                        MasonryItemView(item: item)
                            .onTapGesture { onTap?(item) }
                    }
                }
            }
        }
    }
}

private struct MasonryItemView: View {
    let item: LibraryItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Image
            Image(item.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: item.height)
                .clipped()

            // Bottom-only gradient overlay
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: item.height)

            // Video play indicator
            if item.type == .videos {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Text(item.title.uppercased())
                .font(.spaceMonoBold(11))
                .tracking(1.5)
                .foregroundColor(.white)
                .padding(ENVISpacing.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(item.type.rawValue.lowercased())")
        .accessibilityAddTraits(item.type == .videos ? [.isButton, .startsMediaSession] : .isButton)
    }
}
