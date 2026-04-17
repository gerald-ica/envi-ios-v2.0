import SwiftUI

/// Script editor with segment list, drag-to-reorder, duration tracker, speaker notes, and text export.
struct ScriptEditorView: View {
    @ObservedObject var viewModel: AIWritingViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var editingSegmentID: UUID?
    @State private var editedText = ""
    @State private var editedNotes = ""
    @State private var editedDuration: Double = 5
    @State private var showExportSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ENVISpacing.xxl) {
                    if let script = viewModel.editingScript {
                        scriptHeaderSection(script)
                        generateInputSection
                        segmentListSection(script)
                        addSegmentSection
                    } else {
                        emptyStateSection
                        generateInputSection
                    }
                }
                .padding(ENVISpacing.xl)
            }
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle("Script Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(.interMedium(15))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }
                if viewModel.editingScript != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button(action: { exportScript() }) {
                                Label("Copy as Text", systemImage: "doc.on.doc")
                            }
                            Button(action: { saveScript() }) {
                                Label("Save Script", systemImage: "bookmark")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 16))
                                .foregroundColor(ENVITheme.text(for: colorScheme))
                        }
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                if let script = viewModel.editingScript {
                    exportPreviewSheet(script)
                }
            }
        }
    }

    // MARK: - Script Header

    private func scriptHeaderSection(_ script: VideoScript) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                    Text(script.title)
                        .font(.interSemiBold(18))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text(script.platform.rawValue)
                        .font(.spaceMono(11))
                        .tracking(1)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                Spacer()

                // Duration tracker
                VStack(alignment: .trailing, spacing: ENVISpacing.xs) {
                    Text(script.formattedDuration)
                        .font(.spaceMonoBold(22))
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text("TOTAL")
                        .font(.spaceMono(9))
                        .tracking(2)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }

            // Segment type breakdown
            HStack(spacing: ENVISpacing.sm) {
                ForEach(ScriptSegment.SegmentType.allCases) { type in
                    let count = script.segments.filter { $0.type == type }.count
                    if count > 0 {
                        HStack(spacing: ENVISpacing.xs) {
                            Image(systemName: type.iconName)
                                .font(.system(size: 10))
                            Text("\(count)")
                                .font(.spaceMono(10))
                        }
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        .padding(.horizontal, ENVISpacing.sm)
                        .padding(.vertical, ENVISpacing.xs)
                        .overlay(
                            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Generate Input

    private var generateInputSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Generate Script")

            ENVIInput(
                label: "Topic",
                placeholder: "e.g. Content creation tips for beginners",
                text: $viewModel.scriptTopic
            )

            HStack(spacing: ENVISpacing.md) {
                // Platform picker
                VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                    Text("PLATFORM")
                        .font(.spaceMono(10))
                        .tracking(1.5)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    Menu {
                        ForEach(SocialPlatform.allCases) { platform in
                            Button(action: { viewModel.scriptPlatform = platform }) {
                                HStack {
                                    Text(platform.rawValue)
                                    if viewModel.scriptPlatform == platform {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(viewModel.scriptPlatform.rawValue)
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

                // Duration stepper
                VStack(alignment: .leading, spacing: ENVISpacing.xs) {
                    Text("DURATION")
                        .font(.spaceMono(10))
                        .tracking(1.5)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                    HStack(spacing: ENVISpacing.sm) {
                        Button(action: { if viewModel.scriptDuration > 10 { viewModel.scriptDuration -= 5 } }) {
                            Image(systemName: "minus")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)

                        Text("\(Int(viewModel.scriptDuration))s")
                            .font(.spaceMonoBold(14))
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                            .frame(minWidth: 40)

                        Button(action: { if viewModel.scriptDuration < 300 { viewModel.scriptDuration += 5 } }) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.md)
                    .padding(.vertical, ENVISpacing.sm)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.md)
                            .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                    )
                }
            }

            Button(action: {
                Task { await viewModel.generateScript() }
            }) {
                HStack(spacing: ENVISpacing.sm) {
                    if viewModel.isGeneratingScript {
                        ProgressView()
                            .tint(colorScheme == .dark ? .black : .white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text("GENERATE SCRIPT")
                        .font(.spaceMonoBold(13))
                        .tracking(2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ENVISpacing.lg)
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .background(ENVITheme.text(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
            }
            .disabled(viewModel.scriptTopic.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isGeneratingScript)
            .opacity(viewModel.scriptTopic.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
        }
    }

    // MARK: - Segment List

    private func segmentListSection(_ script: VideoScript) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            sectionLabel("Segments")

            ForEach(Array(script.segments.enumerated()), id: \.element.id) { index, segment in
                segmentRow(segment, index: index, script: script)
            }
        }
    }

    private func segmentRow(_ segment: ScriptSegment, index: Int, script: VideoScript) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Segment header
            HStack {
                HStack(spacing: ENVISpacing.xs) {
                    Image(systemName: segment.type.iconName)
                        .font(.system(size: 11))
                    Text(segment.type.displayName.uppercased())
                        .font(.spaceMonoBold(10))
                        .tracking(1.5)
                }
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Spacer()

                Text("\(Int(segment.duration))s")
                    .font(.spaceMono(11))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                // Reorder buttons
                HStack(spacing: ENVISpacing.xs) {
                    Button(action: { moveSegment(in: script, from: index, direction: -1) }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .disabled(index == 0)

                    Button(action: { moveSegment(in: script, from: index, direction: 1) }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .disabled(index == script.segments.count - 1)
                }
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .buttonStyle(.plain)
            }

            // Editable text
            if editingSegmentID == segment.id {
                editingSegmentView(segment, script: script)
            } else {
                Text(segment.text)
                    .font(.interRegular(14))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .lineSpacing(4)
                    .onTapGesture { startEditing(segment) }

                if let notes = segment.speakerNotes, !notes.isEmpty {
                    HStack(spacing: ENVISpacing.xs) {
                        Image(systemName: "note.text")
                            .font(.system(size: 10))
                        Text(notes)
                            .font(.interRegular(12))
                    }
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .italic()
                }
            }

            // Actions
            HStack(spacing: ENVISpacing.md) {
                if editingSegmentID != segment.id {
                    Button(action: { startEditing(segment) }) {
                        Label("Edit", systemImage: "pencil")
                            .font(.spaceMono(10))
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button(action: { deleteSegment(segment, from: script) }) {
                    Label("Delete", systemImage: "trash")
                        .font(.spaceMono(10))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
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

    private func editingSegmentView(_ segment: ScriptSegment, script: VideoScript) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            TextEditor(text: $editedText)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(ENVISpacing.sm)
                .background(ENVITheme.surfaceHigh(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))

            TextField("Speaker notes (optional)", text: $editedNotes)
                .font(.interRegular(12))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .padding(.horizontal, ENVISpacing.md)
                .padding(.vertical, ENVISpacing.sm)
                .background(ENVITheme.surfaceHigh(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))

            HStack {
                Text("Duration:")
                    .font(.spaceMono(10))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

                Slider(value: $editedDuration, in: 1...120, step: 1)
                    .tint(ENVITheme.text(for: colorScheme))

                Text("\(Int(editedDuration))s")
                    .font(.spaceMonoBold(11))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .frame(width: 32, alignment: .trailing)
            }

            HStack(spacing: ENVISpacing.md) {
                Button(action: { commitEdit(for: segment, in: script) }) {
                    Text("SAVE")
                        .font(.spaceMonoBold(11))
                        .tracking(1.5)
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .padding(.horizontal, ENVISpacing.xl)
                        .padding(.vertical, ENVISpacing.sm)
                        .background(ENVITheme.text(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                }

                Button(action: { editingSegmentID = nil }) {
                    Text("CANCEL")
                        .font(.spaceMonoBold(11))
                        .tracking(1.5)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Add Segment

    private var addSegmentSection: some View {
        Group {
            if viewModel.editingScript != nil {
                Menu {
                    ForEach(ScriptSegment.SegmentType.allCases) { type in
                        Button(action: { addSegment(type: type) }) {
                            Label(type.displayName, systemImage: type.iconName)
                        }
                    }
                } label: {
                    HStack(spacing: ENVISpacing.sm) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("ADD SEGMENT")
                            .font(.spaceMonoBold(11))
                            .tracking(2)
                    }
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ENVISpacing.lg)
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.lg)
                            .strokeBorder(ENVITheme.border(for: colorScheme), style: StrokeStyle(lineWidth: 1, dash: [6]))
                    )
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateSection: some View {
        VStack(spacing: ENVISpacing.lg) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 32))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            Text("No script yet")
                .font(.interMedium(16))
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Generate a script from a topic or start building one from scratch.")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ENVISpacing.xxxxl)
    }

    // MARK: - Export Sheet

    private func exportPreviewSheet(_ script: VideoScript) -> some View {
        NavigationStack {
            ScrollView {
                Text(viewModel.exportScriptAsText(script))
                    .font(.spaceMono(12))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .textSelection(.enabled)
                    .padding(ENVISpacing.xl)
            }
            .background(ENVITheme.background(for: colorScheme))
            .navigationTitle("Export Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showExportSheet = false }
                        .font(.interMedium(15))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        UIPasteboard.general.string = viewModel.exportScriptAsText(script)
                        showExportSheet = false
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(ENVITheme.text(for: colorScheme))
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.spaceMonoBold(11))
            .tracking(2.5)
            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
    }

    private func startEditing(_ segment: ScriptSegment) {
        editingSegmentID = segment.id
        editedText = segment.text
        editedNotes = segment.speakerNotes ?? ""
        editedDuration = segment.duration
    }

    private func commitEdit(for segment: ScriptSegment, in script: VideoScript) {
        guard var updated = viewModel.editingScript else { return }
        if let index = updated.segments.firstIndex(where: { $0.id == segment.id }) {
            updated.segments[index].text = editedText
            updated.segments[index].speakerNotes = editedNotes.isEmpty ? nil : editedNotes
            updated.segments[index].duration = editedDuration
        }
        viewModel.updateScript(updated)
        editingSegmentID = nil
    }

    private func moveSegment(in script: VideoScript, from index: Int, direction: Int) {
        let newIndex = index + direction
        guard var updated = viewModel.editingScript,
              newIndex >= 0, newIndex < updated.segments.count else { return }
        updated.segments.swapAt(index, newIndex)
        viewModel.updateScript(updated)
    }

    private func deleteSegment(_ segment: ScriptSegment, from script: VideoScript) {
        guard var updated = viewModel.editingScript else { return }
        updated.segments.removeAll { $0.id == segment.id }
        viewModel.updateScript(updated)
    }

    private func addSegment(type: ScriptSegment.SegmentType) {
        guard var updated = viewModel.editingScript else { return }
        let segment = ScriptSegment(type: type, text: "New \(type.displayName.lowercased()) segment...", duration: 5)
        updated.segments.append(segment)
        viewModel.updateScript(updated)
        startEditing(segment)
    }

    private func exportScript() {
        showExportSheet = true
    }

    private func saveScript() {
        guard let script = viewModel.editingScript else { return }
        viewModel.saveScript(script)
    }
}

#Preview {
    ScriptEditorView(viewModel: {
        let vm = AIWritingViewModel()
        vm.editingScript = .mock
        return vm
    }())
    .preferredColorScheme(.dark)
}
