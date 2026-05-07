import SwiftUI

// MARK: - Approval Flow View
/// Card-based swipe interface for approving/rejecting ENVI edits.
/// Swipe right = approve, left = reject, up = save for later.
@MainActor
public struct ApprovalFlowView: View {
    @StateObject private var pipeline: ReverseEditingPipeline
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGSize = .zero
    @State private var cardRotation: Double = 0
    @State private var swipeDirection: SwipeDirection?
    @State private var isExpanded: Bool = false
    @State private var showBatchApprove: Bool = false

    private let haptics = UINotificationFeedbackGenerator()

    public init(pipeline: ReverseEditingPipeline) {
        _pipeline = StateObject(wrappedValue: pipeline)
    }

    public var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            // Card stack
            cardStack

            // Overlay controls
            if !isExpanded {
                overlayControls
            }

            // Expanded preview overlay
            if isExpanded, let output = pipeline.renderedOutput {
                FullPreviewView(output: output, isPresented: $isExpanded)
            }
        }
        .onChange(of: pipeline.state) { _, newState in
            handleStateChange(newState)
        }
    }

    // MARK: - Card Stack

    private var cardStack: some View {
        ZStack {
            ForEach(Array(pipeline.matchQueue.enumerated()), id: \1.self) { index, match in
                if index >= currentIndex && index < currentIndex + 3 {
                    ApprovalCard(
                        match: match,
                        output: index == currentIndex ? pipeline.renderedOutput : nil,
                        offset: cardOffset(for: index),
                        rotation: cardRotation(for: index),
                        scale: cardScale(for: index),
                        opacity: cardOpacity(for: index)
                    )
                    .gesture(
                        index == currentIndex ? dragGesture : nil
                    )
                    .onTapGesture {
                        if index == currentIndex {
                            withAnimation(.spring()) {
                                isExpanded.toggle()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Overlay Controls

    private var overlayControls: some View {
        VStack {
            Spacer()

            // Template info bar
            if let match = pipeline.currentMatch {
                TemplateInfoBar(match: match)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            // Action buttons
            HStack(spacing: 40) {
                ActionButton(
                    icon: "xmark.circle.fill",
                    color: .red,
                    action: { swipe(.left) }
                )

                ActionButton(
                    icon: "bookmark.circle.fill",
                    color: .blue,
                    action: { swipe(.up) }
                )

                ActionButton(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    action: { swipe(.right) }
                )
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
                cardRotation = Double(value.translation.width / 20)
                swipeDirection = detectDirection(value.translation)
            }
            .onEnded { value in
                let threshold: CGFloat = 100
                if abs(value.translation.width) > threshold {
                    if value.translation.width > 0 {
                        swipe(.right)
                    } else {
                        swipe(.left)
                    }
                } else if value.translation.height < -threshold {
                    swipe(.up)
                } else {
                    withAnimation(.spring()) {
                        dragOffset = .zero
                        cardRotation = 0
                    }
                }
            }
    }

    // MARK: - Swipe Actions

    private func swipe(_ direction: SwipeDirection) {
        haptics.prepare()

        withAnimation(.easeOut(duration: 0.3)) {
            switch direction {
            case .right:
                dragOffset = CGSize(width: 500, height: 0)
                cardRotation = 15
                haptics.notificationOccurred(.success)
                Task { await pipeline.approve() }

            case .left:
                dragOffset = CGSize(width: -500, height: 0)
                cardRotation = -15
                haptics.notificationOccurred(.error)
                Task { await pipeline.reject() }

            case .up:
                dragOffset = CGSize(width: 0, height: -500)
                haptics.notificationOccurred(.warning)
                // Save for later — not implemented in pipeline yet
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentIndex += 1
            dragOffset = .zero
            cardRotation = 0
            swipeDirection = nil
        }
    }

    // MARK: - Helpers

    private func cardOffset(for index: Int) -> CGSize {
        if index == currentIndex {
            return dragOffset
        }
        return CGSize(width: 0, height: CGFloat(index - currentIndex) * -20)
    }

    private func cardRotation(for index: Int) -> Double {
        if index == currentIndex {
            return cardRotation
        }
        return 0
    }

    private func cardScale(for index: Int) -> CGFloat {
        let offset = index - currentIndex
        if offset <= 0 { return 1.0 }
        return max(0.9 - CGFloat(offset) * 0.05, 0.8)
    }

    private func cardOpacity(for index: Int) -> Double {
        let offset = index - currentIndex
        if offset <= 0 { return 1.0 }
        return max(1.0 - Double(offset) * 0.2, 0.6)
    }

    private func detectDirection(_ translation: CGSize) -> SwipeDirection? {
        if abs(translation.width) > abs(translation.height) {
            return translation.width > 0 ? .right : .left
        } else if translation.height < -50 {
            return .up
        }
        return nil
    }

    private func handleStateChange(_ newState: ReverseEditingPipeline.PipelineState) {
        if newState == .approved || newState == .rejected {
            // Card already animated away by swipe action
        }
    }
}

// MARK: - Supporting Types

enum SwipeDirection {
    case left, right, up
}

// MARK: - Approval Card

struct ApprovalCard: View {
    let match: TemplateMatchingEngine.TemplateMatch
    let output: TemplateExecutionEngine.RenderedOutput?
    let offset: CGSize
    let rotation: Double
    let scale: CGFloat
    let opacity: Double

    var body: some View {
        ZStack {
            // Content preview
            if let output = output,
               let thumbURL = output.thumbnailURL,
               let image = UIImage(contentsOfFile: thumbURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Placeholder
                RoundedRectangle(cornerRadius: 16)
                    .fill(.quaternary)
                    .overlay(
                        VStack {
                            Image(systemName: match.template.archetype.format.iconName)
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text(match.template.archetype.displayName)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.separator, lineWidth: 1)
        )
        .offset(offset)
        .rotationEffect(.degrees(rotation))
        .scaleEffect(scale)
        .opacity(opacity)
        .shadow(radius: 8, y: 4)
    }

    private var aspectRatio: CGFloat {
        switch match.template.archetype.format {
        case .photo: return 4.0 / 5.0
        case .video, .story: return 9.0 / 16.0
        case .carousel: return 1.0
        case .newFormat: return 1.0
        }
    }
}

// MARK: - Template Info Bar

struct TemplateInfoBar: View {
    let match: TemplateMatchingEngine.TemplateMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(match.template.style.rawValue)
                    .font(.headline)
                Spacer()
                ScoreBadge(score: match.score)
            }

            HStack {
                TagView(text: match.template.archetype.displayName, color: .purple)
                TagView(text: match.template.niche.rawValue, color: .orange)
                if let ops = match.template.metadata?.operationsApplied {
                    TagView(text: "\(ops.count) ops", color: .blue)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Score Badge

struct ScoreBadge: View {
    let score: Double

    var body: some View {
        Text("\(Int(score * 100))%")
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(scoreColor.opacity(0.2))
            .foregroundStyle(scoreColor)
            .clipShape(Capsule())
    }

    private var scoreColor: Color {
        if score > 0.85 { return .green }
        if score > 0.6 { return .orange }
        return .red
    }
}

// MARK: - Tag View

struct TagView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(color)
                .frame(width: 64, height: 64)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
    }
}

// MARK: - Full Preview View

struct FullPreviewView: View {
    let output: TemplateExecutionEngine.RenderedOutput
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            if let thumbURL = output.thumbnailURL,
               let image = UIImage(contentsOfFile: thumbURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let pipeline = ReverseEditingPipeline()
    ApprovalFlowView(pipeline: pipeline)
}
