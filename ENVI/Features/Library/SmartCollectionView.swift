import SwiftUI

/// Displays smart collections with a rule builder for creating new ones.
struct SmartCollectionView: View {
    @ObservedObject var viewModel: LibraryDAMViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("SMART COLLECTIONS")
                    .font(.spaceMonoBold(18))
                    .tracking(-1)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                Button {
                    viewModel.isShowingCreateCollection = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }
            }
            .padding(.horizontal, ENVISpacing.xl)
            .padding(.bottom, ENVISpacing.md)

            if viewModel.isLoadingCollections {
                HStack {
                    ProgressView()
                    Text("Loading collections...")
                        .font(.interRegular(13))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
                .padding(.horizontal, ENVISpacing.xl)
            } else if viewModel.smartCollections.isEmpty {
                Text("No smart collections yet")
                    .font(.interRegular(14))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.xl)
                    .padding(.vertical, ENVISpacing.lg)
            } else {
                LazyVStack(spacing: ENVISpacing.sm) {
                    ForEach(viewModel.smartCollections) { collection in
                        SmartCollectionRow(
                            collection: collection,
                            colorScheme: colorScheme,
                            onDelete: {
                                Task { await viewModel.deleteSmartCollection(collection) }
                            }
                        )
                    }
                }
                .padding(.horizontal, ENVISpacing.xl)
            }
        }
        .sheet(isPresented: $viewModel.isShowingCreateCollection) {
            SmartCollectionBuilderSheet(colorScheme: colorScheme) { name, rules in
                Task { await viewModel.createSmartCollection(name: name, rules: rules) }
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Collection Row

private struct SmartCollectionRow: View {
    let collection: SmartCollection
    let colorScheme: ColorScheme
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(ENVITheme.accent(for: colorScheme))

                Text(collection.name)
                    .font(.interMedium(15))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                Text("\(collection.itemCount)")
                    .font(.spaceMono(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.sm)
                    .padding(.vertical, ENVISpacing.xs)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }

            // Rule pills
            if !collection.rules.isEmpty {
                FlowLayout(spacing: ENVISpacing.xs) {
                    ForEach(collection.rules) { rule in
                        RulePill(rule: rule, colorScheme: colorScheme)
                    }
                }
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Collection", systemImage: "trash")
            }
        }
    }
}

// MARK: - Rule Pill

private struct RulePill: View {
    let rule: FilterRule
    let colorScheme: ColorScheme

    var body: some View {
        Text("\(rule.field.displayName) \(rule.op.displayName) \(rule.value)")
            .font(.interRegular(11))
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            .padding(.horizontal, ENVISpacing.sm)
            .padding(.vertical, ENVISpacing.xs)
            .background(ENVITheme.surfaceHigh(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
    }
}

// FlowLayout removed — uses shared FlowLayout from ChatExplore/Shared/FlowLayout.swift

// MARK: - Builder Sheet

private struct SmartCollectionBuilderSheet: View {
    let colorScheme: ColorScheme
    let onSave: (String, [FilterRule]) -> Void

    @State private var name = ""
    @State private var rules: [FilterRule] = [
        FilterRule(field: .platform, op: .equals, value: "")
    ]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.lg) {
                    // Name field
                    VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                        Text("Collection Name")
                            .font(.interMedium(13))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                        TextField("e.g. Top Performers", text: $name)
                            .font(.interRegular(15))
                            .padding(.horizontal, ENVISpacing.md)
                            .padding(.vertical, ENVISpacing.sm)
                            .background(ENVITheme.surfaceLow(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                    }

                    // Rules
                    VStack(alignment: .leading, spacing: ENVISpacing.sm) {
                        Text("Rules")
                            .font(.interMedium(13))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                        ForEach(rules.indices, id: \.self) { index in
                            RuleEditorRow(
                                rule: $rules[index],
                                colorScheme: colorScheme,
                                onRemove: rules.count > 1 ? {
                                    rules.remove(at: index)
                                } : nil
                            )
                        }

                        Button {
                            rules.append(FilterRule(field: .platform, op: .equals, value: ""))
                        } label: {
                            HStack(spacing: ENVISpacing.xs) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Add Rule")
                                    .font(.interMedium(13))
                            }
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                        }
                    }
                }
                .padding(ENVISpacing.xl)
            }
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle("New Smart Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.interMedium(14))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let validRules = rules.filter { !$0.value.isEmpty }
                        onSave(trimmed, validRules)
                        dismiss()
                    }
                    .font(.interSemiBold(14))
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Rule Editor Row

private struct RuleEditorRow: View {
    @Binding var rule: FilterRule
    let colorScheme: ColorScheme
    let onRemove: (() -> Void)?

    @State private var selectedField: FilterRule.Field
    @State private var selectedOp: FilterRule.Operator
    @State private var value: String

    init(rule: Binding<FilterRule>, colorScheme: ColorScheme, onRemove: (() -> Void)?) {
        self._rule = rule
        self.colorScheme = colorScheme
        self.onRemove = onRemove
        self._selectedField = State(initialValue: rule.wrappedValue.field)
        self._selectedOp = State(initialValue: rule.wrappedValue.op)
        self._value = State(initialValue: rule.wrappedValue.value)
    }

    var body: some View {
        HStack(spacing: ENVISpacing.sm) {
            Menu {
                ForEach(FilterRule.Field.allCases) { field in
                    Button(field.displayName) {
                        selectedField = field
                        syncRule()
                    }
                }
            } label: {
                Text(selectedField.displayName)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.sm)
                    .padding(.vertical, ENVISpacing.xs)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }

            Menu {
                ForEach(FilterRule.Operator.allCases) { op in
                    Button(op.displayName) {
                        selectedOp = op
                        syncRule()
                    }
                }
            } label: {
                Text(selectedOp.displayName)
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.sm)
                    .padding(.vertical, ENVISpacing.xs)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }

            TextField("Value", text: $value)
                .font(.interRegular(13))
                .padding(.horizontal, ENVISpacing.sm)
                .padding(.vertical, ENVISpacing.xs)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                .onChange(of: value) { _ in syncRule() }

            if let onRemove {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }
        }
    }

    private func syncRule() {
        rule = FilterRule(id: rule.id, field: selectedField, op: selectedOp, value: value)
    }
}

#Preview {
    ScrollView {
        SmartCollectionView(viewModel: LibraryDAMViewModel())
    }
    .preferredColorScheme(.dark)
}
