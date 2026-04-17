import SwiftUI

/// Editor for creating and editing brand kits.
struct BrandKitEditorView: View {
    @State private var brandKit: BrandKit
    let onSave: (BrandKit) -> Void
    let onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var newHashtag = ""

    init(brandKit: BrandKit, onSave: @escaping (BrandKit) -> Void, onCancel: @escaping () -> Void) {
        _brandKit = State(initialValue: brandKit)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                    nameSection
                    colorSection
                    fontSection
                    voiceToneSection
                    hashtagSection
                    ctaSection
                    previewSection
                }
                .padding(ENVISpacing.xl)
            }
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle(brandKit.name.isEmpty ? "New Brand Kit" : "Edit Brand Kit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .font(.interMedium(15))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(brandKit) }
                        .font(.interSemiBold(15))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .disabled(brandKit.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Name

    private var nameSection: some View {
        ENVIInput(
            label: "Name",
            placeholder: "My Brand",
            text: $brandKit.name
        )
    }

    // MARK: - Colors

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Colors")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ENVISpacing.md) {
                colorPickerRow(label: "Primary", hex: $brandKit.primaryColor)
                colorPickerRow(label: "Secondary", hex: $brandKit.secondaryColor)
                colorPickerRow(label: "Accent", hex: $brandKit.accentColor)
                colorPickerRow(label: "Background", hex: $brandKit.backgroundColor)
            }
        }
    }

    private func colorPickerRow(label: String, hex: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text(label.uppercased())
                .font(.spaceMono(10))
                .tracking(1.5)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            HStack(spacing: ENVISpacing.sm) {
                ColorPicker("", selection: colorBinding(hex: hex))
                    .labelsHidden()
                    .frame(width: 32, height: 32)

                Text(hex.wrappedValue.uppercased())
                    .font(.spaceMono(12))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
            }
            .padding(.horizontal, ENVISpacing.md)
            .padding(.vertical, ENVISpacing.sm)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.sm)
                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
            )
        }
    }

    private func colorBinding(hex: Binding<String>) -> Binding<Color> {
        Binding<Color>(
            get: { Color(hex: hex.wrappedValue) },
            set: { newColor in
                hex.wrappedValue = newColor.toHex()
            }
        )
    }

    // MARK: - Fonts

    private var fontSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Fonts")

            fontPicker(label: "Heading Font", selection: $brandKit.headingFont)
            fontPicker(label: "Body Font", selection: $brandKit.bodyFont)
        }
    }

    private func fontPicker(label: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text(label.uppercased())
                .font(.spaceMono(10))
                .tracking(1.5)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Menu {
                ForEach(BrandKit.availableFonts, id: \.self) { fontName in
                    Button(action: { selection.wrappedValue = fontName }) {
                        HStack {
                            Text(fontName)
                            if selection.wrappedValue == fontName {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue)
                        .font(.custom(selection.wrappedValue, size: 14))
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

    // MARK: - Voice Tone

    private var voiceToneSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Voice Tone")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ENVISpacing.sm) {
                    ForEach(BrandKit.voiceTones, id: \.self) { tone in
                        ENVIChip(
                            title: tone,
                            isSelected: brandKit.voiceTone == tone
                        ) {
                            brandKit.voiceTone = tone
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hashtags

    private var hashtagSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Hashtags")

            // Existing hashtags
            FlowLayoutCompat(spacing: ENVISpacing.sm) {
                ForEach(brandKit.hashtags, id: \.self) { tag in
                    HStack(spacing: ENVISpacing.xs) {
                        Text(tag)
                            .font(.spaceMono(12))
                            .foregroundColor(ENVITheme.text(for: colorScheme))

                        Button(action: {
                            brandKit.hashtags.removeAll { $0 == tag }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        }
                    }
                    .padding(.horizontal, ENVISpacing.md)
                    .padding(.vertical, ENVISpacing.sm)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                            .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                    )
                }
            }

            // Add hashtag
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
                    .onSubmit { addHashtag() }

                Button(action: addHashtag) {
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

    private func addHashtag() {
        var tag = newHashtag.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty else { return }
        if !tag.hasPrefix("#") { tag = "#\(tag)" }
        if !brandKit.hashtags.contains(tag) {
            brandKit.hashtags.append(tag)
        }
        newHashtag = ""
    }

    // MARK: - CTA

    private var ctaSection: some View {
        ENVIInput(
            label: "Default CTA",
            placeholder: "Follow for more",
            text: Binding(
                get: { brandKit.defaultCTA ?? "" },
                set: { brandKit.defaultCTA = $0.isEmpty ? nil : $0 }
            )
        )
    }

    // MARK: - Live Preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Preview")

            VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                // Color strip
                HStack(spacing: 0) {
                    Rectangle().fill(Color(hex: brandKit.primaryColor))
                    Rectangle().fill(Color(hex: brandKit.secondaryColor))
                    Rectangle().fill(Color(hex: brandKit.accentColor))
                }
                .frame(height: 6)
                .clipShape(Capsule())

                Text(brandKit.name.isEmpty ? "Brand Name" : brandKit.name)
                    .font(.custom(brandKit.headingFont, size: 18))
                    .foregroundColor(Color(hex: brandKit.primaryColor))

                Text("This is how your body text will look with the selected font and color palette.")
                    .font(.custom(brandKit.bodyFont, size: 14))
                    .foregroundColor(Color(hex: brandKit.secondaryColor))

                if let cta = brandKit.defaultCTA, !cta.isEmpty {
                    Text(cta)
                        .font(.custom(brandKit.headingFont, size: 13))
                        .foregroundColor(Color(hex: brandKit.accentColor))
                }
            }
            .padding(ENVISpacing.lg)
            .background(Color(hex: brandKit.backgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
            )
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.spaceMonoBold(11))
            .tracking(2.5)
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
    }
}

// MARK: - FlowLayout Compat (simple wrap layout)

private struct FlowLayoutCompat: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { break }
            let position = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

// MARK: - Color Hex Conversion

private extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}

#Preview {
    BrandKitEditorView(
        brandKit: .mock,
        onSave: { _ in },
        onCancel: {}
    )
    .preferredColorScheme(.dark)
}
