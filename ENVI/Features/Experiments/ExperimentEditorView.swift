import SwiftUI

/// Editor for creating and editing experiments with hypothesis, variants, and platform picker.
struct ExperimentEditorView: View {
    @State var experiment: Experiment
    let onSave: (Experiment) -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.lg) {
                    editorField("Name", text: $experiment.name)
                    hypothesisField
                    dateFields

                    // MARK: - Variants
                    variantSection

                    // Add variant
                    Button(action: addVariant) {
                        HStack(spacing: ENVISpacing.sm) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 14))
                            Text("ADD VARIANT")
                                .font(.spaceMono(11))
                                .tracking(0.5)
                        }
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        .padding(.vertical, ENVISpacing.sm)
                    }
                }
                .padding(ENVISpacing.xl)
            }
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle(experiment.name.isEmpty ? "New Experiment" : "Edit Experiment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(experiment) }
                        .disabled(experiment.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Hypothesis

    private var hypothesisField: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text("HYPOTHESIS")
                .font(.spaceMono(10))
                .tracking(1.0)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            TextEditor(text: $experiment.hypothesis)
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.md)
                        .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                )
        }
    }

    // MARK: - Date Fields

    private var dateFields: some View {
        HStack(spacing: ENVISpacing.lg) {
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text("START DATE")
                    .font(.spaceMono(10))
                    .tracking(1.0)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                DatePicker("", selection: $experiment.startDate, displayedComponents: .date)
                    .labelsHidden()
            }

            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text("END DATE")
                    .font(.spaceMono(10))
                    .tracking(1.0)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                DatePicker("", selection: $experiment.endDate, displayedComponents: .date)
                    .labelsHidden()
            }
        }
    }

    // MARK: - Variant Section

    private var variantSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("VARIANTS")
                .font(.spaceMono(10))
                .tracking(1.0)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            ForEach(experiment.variants.indices, id: \.self) { index in
                variantCard(at: index)
            }
        }
    }

    private func variantCard(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Variant header with name + delete
            HStack {
                Text(experiment.variants[index].name.uppercased())
                    .font(.spaceMonoBold(12))
                    .tracking(0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                if experiment.variants.count > 2 {
                    Button(action: { experiment.variants.remove(at: index) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }
                }
            }

            // Caption
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text("CAPTION")
                    .font(.spaceMono(9))
                    .tracking(0.5)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                TextField("Enter caption", text: $experiment.variants[index].caption)
                    .font(.interRegular(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .padding(ENVISpacing.sm)
                    .background(ENVITheme.background(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                            .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                    )
            }

            // Media asset ID
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text("MEDIA ASSET")
                    .font(.spaceMono(9))
                    .tracking(0.5)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                TextField("Asset ID (optional)", text: Binding(
                    get: { experiment.variants[index].mediaAssetID ?? "" },
                    set: { experiment.variants[index].mediaAssetID = $0.isEmpty ? nil : $0 }
                ))
                    .font(.interRegular(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .padding(ENVISpacing.sm)
                    .background(ENVITheme.background(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.sm)
                            .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                    )
            }

            // Platform picker
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text("PLATFORM")
                    .font(.spaceMono(9))
                    .tracking(0.5)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ENVISpacing.sm) {
                        ForEach(SocialPlatform.allCases) { platform in
                            platformChip(
                                platform: platform,
                                isSelected: experiment.variants[index].platform == platform
                            ) {
                                experiment.variants[index].platform = platform
                            }
                        }
                    }
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

    // MARK: - Platform Chip

    private func platformChip(platform: SocialPlatform, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ENVISpacing.xs) {
                Image(systemName: platform.iconName)
                    .font(.system(size: 10))
                Text(platform.rawValue)
                    .font(.spaceMono(10))
                    .tracking(0.3)
            }
            .foregroundColor(isSelected ? ENVITheme.text(for: colorScheme) : ENVITheme.textSecondary(for: colorScheme))
            .padding(.horizontal, ENVISpacing.md)
            .padding(.vertical, ENVISpacing.sm)
            .background(isSelected ? ENVITheme.surfaceHigh(for: colorScheme) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.sm)
                    .strokeBorder(isSelected ? ENVITheme.text(for: colorScheme).opacity(0.3) : ENVITheme.border(for: colorScheme), lineWidth: 1)
            )
        }
    }

    // MARK: - Helpers

    private func addVariant() {
        let letter = Character(UnicodeScalar(65 + experiment.variants.count)!)
        experiment.variants.append(
            ExperimentVariant(name: "Variant \(letter)")
        )
    }

    private func editorField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.xs) {
            Text(label.uppercased())
                .font(.spaceMono(10))
                .tracking(1.0)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            TextField(label, text: text)
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .padding(ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.md)
                        .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                )
        }
    }
}

#Preview {
    ExperimentEditorView(
        experiment: Experiment(
            name: "",
            variants: [
                ExperimentVariant(name: "Variant A"),
                ExperimentVariant(name: "Variant B"),
            ]
        ),
        onSave: { _ in },
        onCancel: {}
    )
    .preferredColorScheme(.dark)
}
