import SwiftUI

/// Horizontal template carousel for the Library screen.
struct TemplateCarousel: View {
    let templates: [TemplateItem]
    let onApply: (TemplateItem) -> Void
    let onDuplicate: (TemplateItem) -> Void
    let onDelete: (TemplateItem) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SAVED TEMPLATES")
                .font(.spaceMonoBold(11))
                .tracking(2.0)
                .foregroundColor(.white.opacity(0.55))
                .padding(.horizontal, MainAppSketch.screenInset)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(templates) { template in
                        LibraryTemplateCardView(
                            template: template,
                            onApply: onApply,
                            onDuplicate: onDuplicate,
                            onDelete: onDelete
                        )
                    }
                }
                .padding(.horizontal, MainAppSketch.screenInset)
            }
        }
    }
}

private struct LibraryTemplateCardView: View {
    let template: TemplateItem
    let onApply: (TemplateItem) -> Void
    let onDuplicate: (TemplateItem) -> Void
    let onDelete: (TemplateItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(template.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                // 3-up sizing on 393pt screen (393 - 48 margins - 24 gaps = 321 / 3 = 107)
                .frame(width: 107, height: 148)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(template.title)
                    .font(.interSemiBold(13))
                    .foregroundColor(MainAppSketch.text)
                    .lineLimit(1)

                Text(template.category.uppercased())
                    .font(.spaceMono(10))
                    .foregroundColor(MainAppSketch.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 107)
        .onTapGesture { onApply(template) }
        .contextMenu {
            Button("Use Template") { onApply(template) }
            Button("Duplicate") { onDuplicate(template) }
            Button("Delete", role: .destructive) { onDelete(template) }
        }
    }
}
