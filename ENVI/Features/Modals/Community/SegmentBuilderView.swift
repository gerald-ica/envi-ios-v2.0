import SwiftUI

/// Rule-based audience segment builder.
struct SegmentBuilderView: View {
    @ObservedObject var viewModel: CommunityViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private let fieldOptions = ["engagementScore", "lifetimeValue", "lastInteraction", "platform", "name"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                header
                nameField
                rulesSection
                addRuleButton
                saveButton
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                Text("NEW SEGMENT")
                    .font(.spaceMonoBold(17))
                    .tracking(-0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text("\(viewModel.newSegmentRules.count) rules")
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .frame(width: 32, height: 32)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Name Field

    private var nameField: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("Segment Name")
                .font(.spaceMono(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            TextField("e.g. Power Users", text: $viewModel.newSegmentName)
                .font(.interMedium(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .textFieldStyle(.plain)
                .padding(ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.md)
                        .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                )
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Rules

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            Text("Rules")
                .font(.spaceMono(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .padding(.horizontal, ENVISpacing.xl)

            if viewModel.newSegmentRules.isEmpty {
                Text("No rules added yet. Add a rule to define this segment.")
                    .font(.spaceMono(12))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                    .padding(.horizontal, ENVISpacing.xl)
            } else {
                ForEach(Array(viewModel.newSegmentRules.enumerated()), id: \.element.id) { index, rule in
                    ruleRow(index: index, rule: rule)
                }
            }
        }
    }

    private func ruleRow(index: Int, rule: SegmentRule) -> some View {
        VStack(spacing: ENVISpacing.sm) {
            if index > 0 {
                Text("AND")
                    .font(.spaceMonoBold(10))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            HStack(spacing: ENVISpacing.sm) {
                // Field picker
                Menu {
                    ForEach(fieldOptions, id: \.self) { field in
                        Button(field) {
                            viewModel.newSegmentRules[index].field = field
                        }
                    }
                } label: {
                    fieldLabel(rule.field)
                }

                // Operator picker
                Menu {
                    ForEach(SegmentOperator.allCases) { op in
                        Button(op.displayName) {
                            viewModel.newSegmentRules[index].op = op
                        }
                    }
                } label: {
                    fieldLabel(rule.op.displayName)
                }

                // Value
                TextField("value", text: Binding(
                    get: { viewModel.newSegmentRules[index].value },
                    set: { viewModel.newSegmentRules[index].value = $0 }
                ))
                .font(.spaceMono(12))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .textFieldStyle(.plain)
                .padding(.horizontal, ENVISpacing.sm)
                .padding(.vertical, ENVISpacing.sm)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                )

                // Delete
                Button {
                    viewModel.removeRule(rule)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(ENVITheme.error)
                }
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.spaceMono(11))
            .foregroundColor(ENVITheme.text(for: colorScheme))
            .padding(.horizontal, ENVISpacing.sm)
            .padding(.vertical, ENVISpacing.sm)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.sm)
                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
            )
    }

    // MARK: - Add Rule

    private var addRuleButton: some View {
        Button { viewModel.addRule() } label: {
            HStack(spacing: ENVISpacing.sm) {
                Image(systemName: "plus")
                    .font(.system(size: 12))
                Text("Add Rule")
                    .font(.interMedium(13))
            }
            .foregroundColor(ENVITheme.text(for: colorScheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, ENVISpacing.md)
            .background(ENVITheme.surfaceLow(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: ENVIRadius.lg)
                    .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
            )
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Save

    private var saveButton: some View {
        Button {
            Task {
                await viewModel.saveNewSegment()
                dismiss()
            }
        } label: {
            Text(viewModel.isSavingSegment ? "Saving..." : "Create Segment")
                .font(.interMedium(15))
                .foregroundColor(ENVITheme.background(for: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, ENVISpacing.lg)
                .background(canSave ? ENVITheme.text(for: colorScheme) : ENVITheme.textSecondary(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        }
        .disabled(!canSave || viewModel.isSavingSegment)
        .padding(.horizontal, ENVISpacing.xl)
    }

    private var canSave: Bool {
        !viewModel.newSegmentName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !viewModel.newSegmentRules.isEmpty &&
        viewModel.newSegmentRules.allSatisfy { !$0.value.isEmpty }
    }
}
