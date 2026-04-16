//
//  TemplateCategoryRow.swift
//  ENVI
//
//  Phase 5 — Template Tab v1 (Task 2).
//
//  Horizontal scrolling row of `TemplateCardView`s with a section
//  header. Matches the visual rhythm of
//  `ENVI/Features/Library/TemplateCarousel.swift`:
//    - SpaceMono 11 / tracking 0.88 section title in textSecondary
//    - ScrollView(.horizontal) with LazyHStack (spacing = md)
//    - Horizontal padding `xl` on inner content, shown via a leading
//      spacer so the first card aligns with the screen's gutter.
//
//  The row is deliberately dumb: all decisions (ordering, hiding,
//  duplication) are pushed up via the callbacks. The parent
//  `TemplateTabView` (Task 1) wires these into `TemplateTabViewModel`.
//

import SwiftUI

struct TemplateCategoryRow: View {
    let title: String
    let templates: [PopulatedTemplate]
    let onSelect: (PopulatedTemplate) -> Void
    var onDuplicate: ((PopulatedTemplate) -> Void)? = nil
    var onHide: ((PopulatedTemplate) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text(title.uppercased())
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .padding(.horizontal, ENVISpacing.xl)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: ENVISpacing.md) {
                    ForEach(templates) { populated in
                        TemplateCardView(
                            populated: populated,
                            onTap: { onSelect(populated) },
                            onDuplicate: { onDuplicate?(populated) },
                            onHide: { onHide?(populated) }
                        )
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("TemplateCategoryRow — For You") {
    // All 5 mock templates, no matched assets (preview renders placeholder tiles).
    let templates: [PopulatedTemplate] = VideoTemplate.mockLibrary.map { template in
        let slots = template.slots.map { FilledSlot(slot: $0, matchedAsset: nil) }
        return PopulatedTemplate(
            template: template,
            filledSlots: slots,
            fillRate: 0.0,
            overallScore: Double(template.popularity) / 100.0
        )
    }

    return ScrollView {
        VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
            TemplateCategoryRow(
                title: "For You",
                templates: templates,
                onSelect: { _ in },
                onDuplicate: { _ in },
                onHide: { _ in }
            )
            TemplateCategoryRow(
                title: "GRWM",
                templates: Array(templates.prefix(3)),
                onSelect: { _ in }
            )
        }
        .padding(.vertical, ENVISpacing.xl)
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}
#endif
