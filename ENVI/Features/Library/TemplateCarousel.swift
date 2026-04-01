import SwiftUI

/// Horizontal template carousel for the Library screen.
struct TemplateCarousel: View {
    let templates: [TemplateItem]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if !templates.isEmpty {
            VStack(alignment: .leading, spacing: ENVISpacing.md) {
                Text("SAVED TEMPLATES")
                    .font(.spaceMono(11))
                    .tracking(0.88)
                    .foregroundColor(ENVITheme.textLight(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.xl)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ENVISpacing.md) {
                        ForEach(templates) { template in
                            TemplateCardView(template: template)
                        }
                    }
                    .padding(.horizontal, ENVISpacing.xl)
                }
            }
        }
    }
}

private struct TemplateCardView: View {
    let template: TemplateItem
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Image(template.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 140, height: 190)
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))

            Text(template.title)
                .font(.spaceMonoBold(13))
                .tracking(0.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text(template.category.uppercased())
                .font(.spaceMono(10))
                .foregroundColor(ENVITheme.textLight(for: colorScheme))
        }
        .frame(width: 140)
    }
}
