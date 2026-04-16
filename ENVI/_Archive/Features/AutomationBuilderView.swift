import SwiftUI

/// Visual automation rule builder: trigger picker, condition fields,
/// action picker, and enable/disable toggle.
struct AutomationBuilderView: View {

    @ObservedObject var viewModel: NotificationViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var ruleName: String = ""
    @State private var selectedTrigger: AutomationTriggerType = .postPublished
    @State private var conditionKey: String = ""
    @State private var conditionValue: String = ""
    @State private var selectedActions: [AutomationActionType] = []
    @State private var isEnabled: Bool = true
    @State private var editingRule: AutomationRule?
    @State private var showingBuilder = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                header
                ruleList

                if viewModel.isLoadingRules {
                    HStack {
                        ProgressView()
                        Text("Loading rules...")
                            .font(.interRegular(13))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }
                    .padding(.horizontal, ENVISpacing.xl)
                }
            }
            .padding(.vertical, ENVISpacing.xl)
        }
        .background(ENVITheme.background(for: colorScheme))
        .sheet(isPresented: $showingBuilder) { builderSheet }
        .task { await viewModel.loadRules() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("AUTOMATIONS")
                .font(.spaceMonoBold(18))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Spacer()

            Button {
                resetBuilder()
                showingBuilder = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .frame(width: 36, height: 36)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }
        }
        .padding(.horizontal, ENVISpacing.xl)
    }

    // MARK: - Rule List

    private var ruleList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.automationRules.enumerated()), id: \.element.id) { index, rule in
                ruleRow(rule)

                if index < viewModel.automationRules.count - 1 {
                    Divider()
                        .background(ENVITheme.border(for: colorScheme))
                        .padding(.horizontal, ENVISpacing.md)
                }
            }
        }
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .padding(.horizontal, ENVISpacing.xl)
    }

    private func ruleRow(_ rule: AutomationRule) -> some View {
        HStack(spacing: ENVISpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                    .font(.interMedium(13))
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text(rule.trigger.type.displayName)
                    .font(.interRegular(12))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in Task { await viewModel.toggleRule(rule) } }
            ))
            .labelsHidden()
            .tint(ENVITheme.text(for: colorScheme))
        }
        .padding(.horizontal, ENVISpacing.md)
        .padding(.vertical, ENVISpacing.md)
        .contentShape(Rectangle())
        .onTapGesture {
            editingRule = rule
            populateBuilder(from: rule)
            showingBuilder = true
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                viewModel.deleteRule(rule)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Builder Sheet

    private var builderSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                    // Name
                    fieldSection(title: "RULE NAME") {
                        TextField("e.g. Retry failed posts", text: $ruleName)
                            .font(.interRegular(15))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            .padding(ENVISpacing.md)
                            .background(ENVITheme.surfaceLow(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                    }

                    // Trigger
                    fieldSection(title: "WHEN THIS HAPPENS") {
                        triggerPicker
                    }

                    // Condition
                    fieldSection(title: "CONDITIONS (OPTIONAL)") {
                        conditionFields
                    }

                    // Actions
                    fieldSection(title: "DO THIS") {
                        actionPicker
                    }

                    // Enable toggle
                    fieldSection(title: "STATUS") {
                        HStack {
                            Text("Enabled")
                                .font(.interRegular(15))
                                .foregroundColor(ENVITheme.text(for: colorScheme))
                            Spacer()
                            Toggle("", isOn: $isEnabled)
                                .labelsHidden()
                                .tint(ENVITheme.text(for: colorScheme))
                        }
                        .padding(ENVISpacing.md)
                        .background(ENVITheme.surfaceLow(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                    }
                }
                .padding(.vertical, ENVISpacing.xl)
                .padding(.horizontal, ENVISpacing.xl)
            }
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle(editingRule == nil ? "New Rule" : "Edit Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingBuilder = false }
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRule() }
                        .font(.interSemiBold(15))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .disabled(ruleName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Trigger Picker

    private var triggerPicker: some View {
        VStack(spacing: ENVISpacing.sm) {
            ForEach(AutomationTriggerType.allCases) { trigger in
                Button {
                    selectedTrigger = trigger
                } label: {
                    HStack {
                        Text(trigger.displayName)
                            .font(.interRegular(14))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                        Spacer()
                        if selectedTrigger == trigger {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(ENVITheme.text(for: colorScheme))
                        }
                    }
                    .padding(ENVISpacing.md)
                    .background(
                        selectedTrigger == trigger
                            ? ENVITheme.surfaceHigh(for: colorScheme)
                            : ENVITheme.surfaceLow(for: colorScheme)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                }
            }
        }
    }

    // MARK: - Condition Fields

    private var conditionFields: some View {
        VStack(spacing: ENVISpacing.sm) {
            TextField("Condition key", text: $conditionKey)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .padding(ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))

            TextField("Condition value", text: $conditionValue)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .padding(ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
        }
    }

    // MARK: - Action Picker

    private var actionPicker: some View {
        VStack(spacing: ENVISpacing.sm) {
            ForEach(AutomationActionType.allCases) { action in
                Button {
                    if selectedActions.contains(action) {
                        selectedActions.removeAll { $0 == action }
                    } else {
                        selectedActions.append(action)
                    }
                } label: {
                    HStack {
                        Text(action.displayName)
                            .font(.interRegular(14))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                        Spacer()
                        if selectedActions.contains(action) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(ENVITheme.text(for: colorScheme))
                        }
                    }
                    .padding(ENVISpacing.md)
                    .background(
                        selectedActions.contains(action)
                            ? ENVITheme.surfaceHigh(for: colorScheme)
                            : ENVITheme.surfaceLow(for: colorScheme)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                }
            }
        }
    }

    // MARK: - Helpers

    private func fieldSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text(title)
                .font(.spaceMonoBold(11))
                .tracking(1)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            content()
        }
    }

    private func resetBuilder() {
        editingRule = nil
        ruleName = ""
        selectedTrigger = .postPublished
        conditionKey = ""
        conditionValue = ""
        selectedActions = []
        isEnabled = true
    }

    private func populateBuilder(from rule: AutomationRule) {
        ruleName = rule.name
        selectedTrigger = rule.trigger.type
        if let firstCondition = rule.trigger.conditions.first {
            conditionKey = firstCondition.key
            conditionValue = firstCondition.value
        }
        selectedActions = rule.actions.map(\.type)
        isEnabled = rule.isEnabled
    }

    private func saveRule() {
        var conditions: [String: String] = [:]
        let trimmedKey = conditionKey.trimmingCharacters(in: .whitespaces)
        let trimmedValue = conditionValue.trimmingCharacters(in: .whitespaces)
        if !trimmedKey.isEmpty && !trimmedValue.isEmpty {
            conditions[trimmedKey] = trimmedValue
        }

        let trigger = AutomationTrigger(type: selectedTrigger, conditions: conditions)
        let actions = selectedActions.map { AutomationAction(type: $0) }
        let rule = AutomationRule(
            id: editingRule?.id ?? UUID(),
            name: ruleName.trimmingCharacters(in: .whitespaces),
            trigger: trigger,
            actions: actions,
            isEnabled: isEnabled
        )

        Task {
            if editingRule != nil {
                await viewModel.updateRule(rule)
            } else {
                await viewModel.createRule(rule)
            }
            showingBuilder = false
        }
    }
}
