import SwiftUI

/// Brief template editor with approval workflow.
struct BriefEditorView: View {
    @State var brief: CreativeBrief
    let onSave: (CreativeBrief) -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.xl) {
                    approvalSection
                    templateSection
                    clientNotesSection
                }
                .padding(ENVISpacing.xl)
            }
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle("Creative Brief")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(brief) }
                        .disabled(brief.template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: - Approval Status

    private var approvalSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("APPROVAL STATUS")
                .font(.spaceMono(10))
                .tracking(1.0)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            HStack(spacing: ENVISpacing.sm) {
                ForEach(BriefApprovalStatus.allCases, id: \.rawValue) { status in
                    approvalChip(status)
                }
            }

            // Status description
            Text(approvalDescription)
                .font(.interRegular(12))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    private func approvalChip(_ status: BriefApprovalStatus) -> some View {
        let isSelected = brief.approvalStatus == status

        return Button {
            brief.approvalStatus = status
        } label: {
            Text(status.displayName)
                .font(.spaceMono(10))
                .tracking(0.3)
                .foregroundColor(isSelected ? chipForeground(status) : ENVITheme.textSecondary(for: colorScheme))
                .padding(.horizontal, ENVISpacing.md)
                .padding(.vertical, ENVISpacing.sm)
                .background(isSelected ? chipColor(status).opacity(0.15) : ENVITheme.surfaceHigh(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .strokeBorder(isSelected ? chipColor(status).opacity(0.4) : Color.clear, lineWidth: 1)
                )
        }
    }

    private var approvalDescription: String {
        switch brief.approvalStatus {
        case .pending:           return "Brief is awaiting review and approval."
        case .approved:          return "Brief has been approved. Production can begin."
        case .revisionRequested: return "Changes have been requested. Please update and resubmit."
        case .rejected:          return "Brief was rejected. Review feedback in client notes."
        }
    }

    // MARK: - Template

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack {
                Text("BRIEF TEMPLATE")
                    .font(.spaceMono(10))
                    .tracking(1.0)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Spacer()

                Menu {
                    Button("Campaign Brief") { applyTemplate(.campaign) }
                    Button("Social Media Brief") { applyTemplate(.social) }
                    Button("Video Brief") { applyTemplate(.video) }
                    Button("Email Brief") { applyTemplate(.email) }
                } label: {
                    HStack(spacing: ENVISpacing.xs) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 11))
                        Text("Templates")
                            .font(.spaceMono(11))
                    }
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.md)
                    .padding(.vertical, ENVISpacing.sm)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                }
            }

            TextEditor(text: $brief.template)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 300)
                .padding(ENVISpacing.md)
                .background(ENVITheme.surfaceLow(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.md)
                        .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                )

            Text("\(brief.template.count) characters")
                .font(.spaceMono(10))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Client Notes

    private var clientNotesSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("CLIENT NOTES")
                .font(.spaceMono(10))
                .tracking(1.0)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            TextEditor(text: $brief.clientNotes)
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

    // MARK: - Helpers

    private func chipColor(_ status: BriefApprovalStatus) -> Color {
        switch status {
        case .approved:          return ENVITheme.success
        case .pending:           return ENVITheme.warning
        case .revisionRequested: return ENVITheme.info
        case .rejected:          return ENVITheme.error
        }
    }

    private func chipForeground(_ status: BriefApprovalStatus) -> Color {
        chipColor(status)
    }

    // MARK: - Template Presets

    private enum BriefTemplate {
        case campaign, social, video, email
    }

    private func applyTemplate(_ template: BriefTemplate) {
        switch template {
        case .campaign:
            brief.template = """
            ## Campaign Brief

            **Objective:**

            **Target Audience:**

            **Key Deliverables:**
            -
            -
            -

            **Timeline:**

            **Budget:**

            **Brand Guidelines:**

            **Success Metrics:**
            """

        case .social:
            brief.template = """
            ## Social Media Brief

            **Platform(s):**

            **Content Type:** Post / Reel / Story / Carousel

            **Objective:**

            **Key Message:**

            **Hashtags:**

            **Posting Schedule:**

            **Visual Direction:**

            **CTA:**
            """

        case .video:
            brief.template = """
            ## Video Brief

            **Format:** Short-form / Long-form

            **Duration:**

            **Concept:**

            **Script Outline:**
            1.
            2.
            3.

            **Visual References:**

            **Music / Audio:**

            **Deliverables:**
            - Raw footage
            - Edited cut
            - Subtitled version
            """

        case .email:
            brief.template = """
            ## Email Brief

            **Campaign:**

            **Subject Line Options:**
            1.
            2.

            **Preview Text:**

            **Body Copy:**

            **CTA Button:**

            **Audience Segment:**

            **Send Date:**
            """
        }
    }
}

#Preview {
    BriefEditorView(
        brief: .mock,
        onSave: { _ in },
        onCancel: { }
    )
    .preferredColorScheme(.dark)
}
