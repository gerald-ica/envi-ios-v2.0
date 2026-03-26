import SwiftUI

/// Waterfall/masonry grid layout with 2 columns.
struct MasonryGridView: View {
    let items: [LibraryItem]

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

            // Gradient + title
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )

            Text(item.title)
                .font(.interSemiBold(13))
                .foregroundColor(.white)
                .padding(ENVISpacing.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
    }
}
