import SwiftUI

/// Displays a list of tutorial cards with progress indicators and category filtering.
struct TutorialListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var tutorials: [Tutorial] = Tutorial.mock
    @State private var selectedCategory: Tutorial.Category?
    @State private var learningPaths: [LearningPath] = LearningPath.mock

    private var filteredTutorials: [Tutorial] {
        guard let category = selectedCategory else { return tutorials }
        return tutorials.filter { $0.category == category }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: ENVISpacing.lg) {
                header
                categoryFilter
                learningPathsSection
                tutorialsSection
            }
            .padding(ENVISpacing.lg)
        }
        .background(ENVITheme.background(for: colorScheme).ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("LEARN")
                .font(.spaceMono(22))
                .tracking(-1)
                .foregroundColor(ENVITheme.text(for: colorScheme))

            Text("Master ENVI with guided tutorials")
                .font(.interRegular(13))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                categoryChip(title: "ALL", category: nil)
                ForEach(Tutorial.Category.allCases) { category in
                    categoryChip(title: category.displayName.uppercased(), category: category)
                }
            }
        }
    }

    private func categoryChip(title: String, category: Tutorial.Category?) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            Text(title)
                .font(.spaceMono(10))
                .tracking(2)
                .foregroundColor(
                    selectedCategory == category
                        ? ENVITheme.background(for: colorScheme)
                        : ENVITheme.text(for: colorScheme)
                )
                .padding(.horizontal, ENVISpacing.md)
                .padding(.vertical, ENVISpacing.sm)
                .background(
                    selectedCategory == category
                        ? ENVITheme.text(for: colorScheme)
                        : ENVITheme.surfaceLow(for: colorScheme)
                )
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
        }
    }

    // MARK: - Learning Paths

    private var learningPathsSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("LEARNING PATHS")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            ForEach(learningPaths) { path in
                learningPathCard(path)
            }
        }
    }

    private func learningPathCard(_ path: LearningPath) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack {
                Text(path.name.uppercased())
                    .font(.spaceMono(13))
                    .tracking(0.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Spacer()

                Text("\(path.completedTutorials)/\(path.totalTutorials)")
                    .font(.interRegular(12))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            ProgressView(value: path.progress)
                .tint(ENVITheme.text(for: colorScheme))

            Text("\(path.tutorials.count) tutorials")
                .font(.interRegular(11))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Tutorials

    private var tutorialsSection: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("TUTORIALS")
                .font(.spaceMono(11))
                .tracking(0.88)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            ForEach(filteredTutorials) { tutorial in
                tutorialCard(tutorial)
            }
        }
    }

    private func tutorialCard(_ tutorial: Tutorial) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            HStack(alignment: .top) {
                Image(systemName: tutorial.category.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .frame(width: 28, height: 28)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text(tutorial.title.uppercased())
                        .font(.spaceMono(13))
                        .tracking(0.5)
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    Text(tutorial.category.displayName)
                        .font(.interRegular(11))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                Spacer()

                if tutorial.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ENVITheme.success)
                } else {
                    Text("\(tutorial.completedSteps)/\(tutorial.steps.count)")
                        .font(.spaceMono(11))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }

            ProgressView(value: tutorial.completionRate)
                .tint(tutorial.isCompleted ? ENVITheme.success : ENVITheme.text(for: colorScheme))

            // Steps preview
            HStack(spacing: ENVISpacing.xs) {
                ForEach(tutorial.steps.prefix(4)) { step in
                    HStack(spacing: 2) {
                        Image(systemName: step.actionType.iconName)
                            .font(.system(size: 8))
                        Text(step.title)
                            .font(.interRegular(9))
                    }
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
            }
        }
        .padding(ENVISpacing.md)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
    }
}

#Preview {
    TutorialListView()
        .preferredColorScheme(.dark)
}
