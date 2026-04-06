import SwiftUI

/// A contextual coaching overlay that displays tips relevant to the current screen.
struct CoachingOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool
    let tips: [CoachingTip]

    @State private var currentIndex: Int = 0
    @State private var dismissedTipIDs: Set<UUID> = []

    private var visibleTips: [CoachingTip] {
        tips
            .filter { !dismissedTipIDs.contains($0.id) }
            .sorted { $0.priority > $1.priority }
    }

    private var currentTip: CoachingTip? {
        guard currentIndex < visibleTips.count else { return nil }
        return visibleTips[currentIndex]
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            if let tip = currentTip {
                tipCard(tip)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id(tip.id)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentIndex)
    }

    // MARK: - Tip Card

    private func tipCard(_ tip: CoachingTip) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.md) {
            // Header
            HStack {
                Image(systemName: tip.context.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .frame(width: 28, height: 28)
                    .background(ENVITheme.surfaceHigh(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))

                VStack(alignment: .leading, spacing: 1) {
                    Text(tip.title.uppercased())
                        .font(.spaceMono(13))
                        .tracking(0.5)
                        .foregroundColor(ENVITheme.text(for: colorScheme))

                    priorityLabel(tip.priority)
                }

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        .frame(width: 24, height: 24)
                }
            }

            // Message
            Text(tip.message)
                .font(.interRegular(14))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            // Navigation
            HStack {
                if visibleTips.count > 1 {
                    Text("\(currentIndex + 1) OF \(visibleTips.count)")
                        .font(.spaceMono(10))
                        .tracking(2)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }

                Spacer()

                HStack(spacing: ENVISpacing.sm) {
                    Button {
                        dismissCurrentTip()
                    } label: {
                        Text("DISMISS")
                            .font(.spaceMono(10))
                            .tracking(1.5)
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                            .padding(.horizontal, ENVISpacing.md)
                            .padding(.vertical, ENVISpacing.sm)
                            .background(ENVITheme.surfaceHigh(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                    }

                    if currentIndex < visibleTips.count - 1 {
                        Button {
                            withAnimation { currentIndex += 1 }
                        } label: {
                            Text("NEXT")
                                .font(.spaceMono(10))
                                .tracking(1.5)
                                .foregroundColor(ENVITheme.background(for: colorScheme))
                                .padding(.horizontal, ENVISpacing.md)
                                .padding(.vertical, ENVISpacing.sm)
                                .background(ENVITheme.text(for: colorScheme))
                                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                        }
                    }
                }
            }
        }
        .padding(ENVISpacing.lg)
        .background(ENVITheme.surfaceLow(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.xl)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
        )
        .padding(.horizontal, ENVISpacing.xxl)
    }

    // MARK: - Priority Label

    private func priorityLabel(_ priority: CoachingTip.Priority) -> some View {
        Text(priority.rawValue.uppercased())
            .font(.spaceMono(9))
            .tracking(1.5)
            .foregroundColor(priorityColor(priority))
    }

    private func priorityColor(_ priority: CoachingTip.Priority) -> Color {
        switch priority {
        case .high:   return ENVITheme.warning
        case .medium: return ENVITheme.textSecondary(for: colorScheme)
        case .low:    return ENVITheme.textSecondary(for: colorScheme).opacity(0.6)
        }
    }

    // MARK: - Actions

    private func dismissCurrentTip() {
        guard let tip = currentTip else { return }
        withAnimation {
            dismissedTipIDs.insert(tip.id)
            if currentIndex >= visibleTips.count {
                currentIndex = max(0, visibleTips.count - 1)
            }
            if visibleTips.isEmpty {
                dismiss()
            }
        }
    }

    private func dismiss() {
        withAnimation { isPresented = false }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        CoachingOverlayView(
            isPresented: .constant(true),
            tips: CoachingTip.mock
        )
    }
    .preferredColorScheme(.dark)
}
