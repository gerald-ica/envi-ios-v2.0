import SwiftUI

/// Editor for creating and editing content templates.
struct TemplateEditorView: View {
    @State private var template: ContentTemplate
    let brandKits: [BrandKit]
    let onSave: (ContentTemplate) -> Void
    let onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var newHashtag = ""
    @State private var currentHashtagSetIndex = 0

    init(
        template: ContentTemplate,
        brandKits: [BrandKit],
        onSave: @escaping (ContentTemplate) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _template = State(initialValue: template)
        self.brandKits = brandKits
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                    nameSection
                    categorySection
                    captionSection
                    hashtagSection
                    platformSection
                    aspectRatioSection
                    brandKitSection
                    hookAndCTASection
                    previewSection
                }
                .padding(ENVISpacing.xl)
            }
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle(template.name.isEmpty ? "New Template" : "Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .font(.interMedium(15))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(template) }
                        .font(.interSemiBold(15))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .disabled(template.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Name

    private var nameSection: some View {
        ENVIInput(
            label: "Template Name",
            placeholder: "Instagram Reel Hook",
            text: $template.name
        )
    }

    // MARK: - Category

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Category")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.sm) {
                    ForEach(TemplateCategory.allCases, id: \.self) { category in
                        ENVIChip(
                            title: category.displayName,
                            isSelected: template.category == category
                        ) {
                            template.category = category
                        }
                    }
                }
            }
        }
    }

    // MARK: - Caption Template

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Caption Template")

            // Token hint
            HStack(spacing: ENVISpacing.sm) {
                tokenBadge("{hook}")
                tokenBadge("{body}")
                tokenBadge("{cta}")
            }

            TextEditor(text: $template.captionTemplate)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .padding(ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.md)
                        .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                )
        }
    }

    private func tokenBadge(_ token: String) -> some View {
        Button(action: {
            template.captionTemplate += template.captionTemplate.isEmpty ? token : "\n\(token)"
        }) {
            Text(token)
                .font(.spaceMono(11))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .padding(.horizontal, ENVISpacing.sm)
                .padding(.vertical, ENVISpacing.xs)
                .background(ENVITheme.surfaceHigh(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
        }
    }

    // MARK: - Hashtag Sets

    private var hashtagSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            HStack {
                sectionLabel("Hashtag Sets")

                Spacer()

                Button(action: {
                    template.hashtagSets.append([])
                    currentHashtagSetIndex = template.hashtagSets.count - 1
                }) {
                    Text("+ SET")
                        .font(.spaceMonoBold(10))
                        .tracking(1.0)
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }
            }

            if !template.hashtagSets.isEmpty {
                // Set selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ENVISpacing.sm) {
                        ForEach(template.hashtagSets.indices, id: \.self) { index in
                            ENVIChip(
                                title: "Set \(index + 1)",
                                isSelected: currentHashtagSetIndex == index
                            ) {
                                currentHashtagSetIndex = index
                            }
                        }
                    }
                }

                // Current set hashtags
                if currentHashtagSetIndex < template.hashtagSets.count {
                    let tags = template.hashtagSets[currentHashtagSetIndex]

                    if !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: ENVISpacing.xs) {
                                ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                                    HStack(spacing: ENVISpacing.xs) {
                                        Text(tag)
                                            .font(.spaceMono(11))
                                            .foregroundColor(ENVITheme.text(for: colorScheme))

                                        Button(action: {
                                            template.hashtagSets[currentHashtagSetIndex].removeAll { $0 == tag }
                                        }) {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                                        }
                                    }
                                    .padding(.horizontal, ENVISpacing.sm)
                                    .padding(.vertical, ENVISpacing.xs)
                                    .background(ENVITheme.surfaceLow(for: colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                                            .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }

                    // Add hashtag to current set
                    HStack(spacing: ENVISpacing.sm) {
                        TextField("#hashtag", text: $newHashtag)
                            .font(.interRegular(14))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            .padding(.horizontal, ENVISpacing.md)
                            .padding(.vertical, ENVISpacing.sm)
                            .background(ENVITheme.surfaceLow(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: ENVIRadius.md)
                                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                            )
                            .onSubmit { addHashtagToCurrentSet() }

                        Button(action: addHashtagToCurrentSet) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(ENVITheme.text(for: colorScheme))
                                .frame(width: 32, height: 32)
                                .background(ENVITheme.surfaceLow(for: colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                        }
                        .disabled(newHashtag.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private func addHashtagToCurrentSet() {
        var tag = newHashtag.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, currentHashtagSetIndex < template.hashtagSets.count else { return }
        if !tag.hasPrefix("#") { tag = "#\(tag)" }
        if !template.hashtagSets[currentHashtagSetIndex].contains(tag) {
            template.hashtagSets[currentHashtagSetIndex].append(tag)
        }
        newHashtag = ""
    }

    // MARK: - Platform Selector

    private var platformSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Platforms")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.sm) {
                    ForEach(SocialPlatform.allCases) { platform in
                        ENVIChip(
                            title: platform.rawValue,
                            isSelected: template.suggestedPlatforms.contains(platform)
                        ) {
                            if template.suggestedPlatforms.contains(platform) {
                                template.suggestedPlatforms.removeAll { $0 == platform }
                            } else {
                                template.suggestedPlatforms.append(platform)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Aspect Ratio

    private var aspectRatioSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Aspect Ratio")

            HStack(spacing: ENVISpacing.sm) {
                ForEach(ContentTemplate.aspectRatios, id: \.self) { ratio in
                    ENVIChip(
                        title: ratio,
                        isSelected: template.aspectRatio == ratio
                    ) {
                        template.aspectRatio = ratio
                    }
                }
            }
        }
    }

    // MARK: - Brand Kit Association

    private var brandKitSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Brand Kit")

            Menu {
                Button("None") { template.brandKitID = nil }
                ForEach(brandKits) { kit in
                    Button(kit.name) { template.brandKitID = kit.id }
                }
            } label: {
                HStack {
                    Text(selectedBrandKitName)
                        .font(.interRegular(14))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
                .padding(.horizontal, ENVISpacing.lg)
                .padding(.vertical, ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.md)
                        .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                )
            }
        }
    }

    private var selectedBrandKitName: String {
        guard let id = template.brandKitID,
              let kit = brandKits.first(where: { $0.id == id }) else {
            return "None"
        }
        return kit.name
    }

    // MARK: - Hook & CTA Style

    private var hookAndCTASection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.lg) {
            // Hook style
            VStack(alignment: .leading, spacing: ENVISpacing.md) {
                sectionLabel("Hook Style")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ENVISpacing.sm) {
                        ENVIChip(
                            title: "None",
                            isSelected: template.hookStyle == nil
                        ) {
                            template.hookStyle = nil
                        }

                        ForEach(ContentTemplate.hookStyles, id: \.self) { style in
                            ENVIChip(
                                title: style,
                                isSelected: template.hookStyle == style
                            ) {
                                template.hookStyle = style
                            }
                        }
                    }
                }
            }

            // CTA style
            VStack(alignment: .leading, spacing: ENVISpacing.md) {
                sectionLabel("CTA Style")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ENVISpacing.sm) {
                        ENVIChip(
                            title: "None",
                            isSelected: template.ctaStyle == nil
                        ) {
                            template.ctaStyle = nil
                        }

                        ForEach(ContentTemplate.ctaStyles, id: \.self) { style in
                            ENVIChip(
                                title: style,
                                isSelected: template.ctaStyle == style
                            ) {
                                template.ctaStyle = style
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Preview")

            VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                // Header row
                HStack {
                    Image(systemName: template.category.iconName)
                        .font(.system(size: 14))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    Text(template.category.displayName.uppercased())
                        .font(.spaceMonoBold(10))
                        .tracking(1.0)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    Spacer()

                    Text(template.aspectRatio)
                        .font(.spaceMono(10))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                // Populated caption preview
                Text(populatedCaption)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineLimit(8)

                // Hashtags preview
                if let firstSet = template.hashtagSets.first, !firstSet.isEmpty {
                    Text(firstSet.joined(separator: " "))
                        .font(.interRegular(12))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                // Platforms
                HStack(spacing: ENVISpacing.sm) {
                    ForEach(template.suggestedPlatforms) { platform in
                        HStack(spacing: ENVISpacing.xs) {
                            Image(systemName: platform.iconName)
                                .font(.system(size: 10))
                            Text(platform.rawValue)
                                .font(.spaceMono(10))
                        }
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
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
    }

    private var populatedCaption: String {
        var caption = template.captionTemplate
        if caption.isEmpty { caption = "{hook}\n\n{body}\n\n{cta}" }

        let hookExample = template.hookStyle ?? "Question"
        let hookMap: [String: String] = [
            "Question": "Did you know most creators miss this?",
            "Bold Statement": "This changed everything for me.",
            "Statistic": "90% of creators don't do this.",
            "Story": "Last week something happened that blew my mind.",
            "Controversy": "Unpopular opinion: consistency is overrated.",
        ]

        caption = caption.replacingOccurrences(of: "{hook}", with: hookMap[hookExample] ?? "Your hook here")
        caption = caption.replacingOccurrences(of: "{body}", with: "Here's what I've learned from creating content every day for the past year.")
        caption = caption.replacingOccurrences(of: "{cta}", with: template.ctaStyle ?? "Follow for more")

        return caption
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.spaceMonoBold(11))
            .tracking(2.5)
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
    }
}

#Preview {
    TemplateEditorView(
        template: ContentTemplate.mockList[0],
        brandKits: BrandKit.mockList,
        onSave: { _ in },
        onCancel: {}
    )
    .preferredColorScheme(.dark)
}
