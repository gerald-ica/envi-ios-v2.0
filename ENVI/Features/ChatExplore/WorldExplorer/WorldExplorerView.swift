import SwiftUI
import SceneKit
import PhotosUI

// MARK: - Future Migration Note
// TODO: Migrate from SceneKit → RealityKit when targeting iOS 18+.
// RealityKit provides better performance, native visionOS support, and modern rendering.
// The HelixSceneController should be rewritten as a RealityKit Entity hierarchy.
// Key migration points:
// - Replace SCNView/SCNScene with RealityView
// - Replace SCNNode with Entity + ModelComponent
// - Replace SCNMaterial with PhysicallyBasedMaterial or UnlitMaterial
// - Replace SCNSceneRendererDelegate with RealityKit System for frame updates
// - Replace SCNBillboardConstraint with BillboardComponent

// MARK: - Content Library

/// Static content library matching the React original's CONTENT_PIECES and CONTENT_IMAGES.
enum ContentLibrary {

    /// Reuse the same placeholder image pool shown on the For You feed.
    static let imageNames: [String] = FeedViewModel.imageNames

    /// Force helix content to use the For You placeholder set.
    static let pieces: [ContentPiece] = ContentPiece.sampleLibrary.enumerated().map { index, piece in
        let replacementImage = imageNames[index % imageNames.count]
        return ContentPiece(
            id: piece.id,
            title: piece.title,
            type: piece.type,
            platform: piece.platform,
            description: piece.description,
            aiScore: piece.aiScore,
            createdAt: piece.createdAt,
            tags: piece.tags,
            metrics: piece.metrics,
            aiSuggestion: piece.aiSuggestion,
            imageName: replacementImage,
            source: piece.source,
            predictedEngagement: piece.predictedEngagement,
            confidenceScore: piece.confidenceScore,
            aiExplanation: piece.aiExplanation
        )
    }
    static let futurePieces: [ContentPiece] = ContentPiece.futurePieces
    static let pastPieces: [ContentPiece] = ContentPiece.pastPieces

    static func piece(for id: String) -> ContentPiece? {
        pieces.first { $0.id == id }
    }
}

// MARK: - WorldExplorerView

/// Full-screen SwiftUI view wrapping an SCNView with a 3D helix of content pieces.
/// Includes all HUD overlays from the React original: header, content types legend,
/// time scrubber, bottom bar with suggestion chips, input, plus menu, voice widget,
/// and content detail overlay.
struct WorldExplorerView: View {

    var onNodeClick: ((String) -> Void)?
    var onSuggestionClick: ((String) -> Void)?

    // MARK: - State (matches React's full state set)

    @State private var selectedContent: ContentPiece?
    @State private var selectedContentId: String?
    @State private var sceneReady: Bool = false
    @State private var viewMode: ExplorerViewMode = .stream
    @State private var plusMenuOpen: Bool = false
    @State private var activeTypeFilter: ContentType?
    @State private var lightMode: Bool = false
    @State private var voiceActive: Bool = false
    @State private var voiceClosing: Bool = false
    @State private var voiceSeconds: Int = 0
    @State private var timePosition: CGFloat = 0.5
    @State private var zoomLevel: ExplorerZoomLevel = .month
    @State private var showSettings: Bool = false
    @State private var editingContent: ContentPiece?
    @State private var explorerPrompt = ""
    @State private var explorerNotice: ExplorerNotice?

    /// Reference to the scene controller for state sync
    @State private var sceneController: HelixSceneController?

    /// PHPicker presentation
    @State private var showPhotoPicker: Bool = false

    /// Content assembly observation
    @StateObject private var assembler = ContentPieceAssembler.shared

    /// Voice timer
    @State private var voiceTimer: Timer?

    var body: some View {
        ZStack {
            // Background — kept transparent so the SceneKit 3D helix renders through
            Color.clear
                .ignoresSafeArea()

            // 3D Scene
            HelixSceneRepresentable(
                onNodeTapped: { contentId in
                    if let piece = ContentLibrary.piece(for: contentId) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            selectedContent = piece
                            selectedContentId = contentId
                        }
                        onNodeClick?(contentId)
                    }
                },
                onSceneReady: {
                    withAnimation(.easeIn(duration: 0.8)) {
                        sceneReady = true
                    }
                },
                onControllerReady: { controller in
                    sceneController = controller
                },
                lightMode: lightMode,
                activeTypeFilter: activeTypeFilter,
                selectedContentId: selectedContentId,
                timePosition: Float(timePosition),
                zoomLevel: zoomLevel,
                viewMode: viewMode
            )
            .ignoresSafeArea()
            .opacity(sceneReady ? 1 : 0)

            // Loading state
            if !sceneReady {
                loadingView
            }

            // Top-left: ENVI AI header
            if sceneReady && selectedContent == nil {
                topLeftHeader
            }

            // Top-right: CONTENT TYPES legend
            if sceneReady && selectedContent == nil {
                topRightContentTypes
            }

            // Right side: Vertical time scrubber + zoom buttons
            if sceneReady && selectedContent == nil {
                rightSideScrubber
            }

            // Content detail overlay
            if let content = selectedContent {
                ContentNodeView(
                    content: content,
                    lightMode: lightMode,
                    onClose: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            selectedContent = nil
                            selectedContentId = nil
                            sceneController?.resetCamera()
                        }
                    },
                    onNavigateToContent: { newContent in
                        withAnimation(.easeOut(duration: 0.25)) {
                            selectedContent = newContent
                            selectedContentId = newContent.id
                        }
                        onNodeClick?(newContent.id)
                    },
                    onEdit: { piece in
                        editingContent = piece
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Voice widget (bottom-right)
            if voiceActive {
                voiceWidget
            }

            // Bottom bar with suggestion chips + input
            if sceneReady && selectedContent == nil {
                bottomBar
            }
        }
        .preferredColorScheme(lightMode ? .light : .dark)
        .sheet(isPresented: $showSettings) {
            ContentLibrarySettingsView()
        }
        .fullScreenCover(item: $editingContent) { piece in
            EditorContainerView(contentPiece: piece)
                .preferredColorScheme(.dark)
        }
        .alert(item: $explorerNotice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPickerView { identifiers in
                guard !identifiers.isEmpty else { return }
                assembler.enqueueForAssembly(mediaIDs: identifiers)
            }
        }
        .overlay(alignment: .top) {
            if case .uploading(let progress) = assembler.state {
                assemblyProgressBanner(progress: progress)
            } else if case .assembling(let count) = assembler.state, count > 0 {
                assemblyProgressBanner(progress: assembler.progress)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: ENVISpacing.lg) {
            Circle()
                .fill(lightMode ? Color.black.opacity(0.4) : Color.white.opacity(0.6))
                .frame(width: 6, height: 6)
                .modifier(PulseModifier())
            Text("LOADING CONTENT TIMELINE")
                .font(.spaceMonoBold(11))
                .tracking(2.5)
                .foregroundColor(lightMode ? .black.opacity(0.4) : .white.opacity(0.4))
        }
    }

    // MARK: - Top-Left Header

    private var topLeftHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: ENVISpacing.md) {
                Text("[01]")
                    .font(.spaceMono(11))
                    .foregroundColor(lightMode ? .black.opacity(0.35) : .white.opacity(0.4))
                Text("ENVI AI")
                    .font(.spaceMonoBold(11))
                    .tracking(2.5)
                    .foregroundColor(lightMode ? .black : .white)
            }
            .padding(.bottom, ENVISpacing.xl)

            Text("YOUR CONTENT\nTIMELINE")
                .font(.spaceMonoBold(28))
                .tracking(-0.5)
                .lineSpacing(0)
                .foregroundColor(lightMode ? .black : .white)
                .textCase(.uppercase)
                .padding(.bottom, ENVISpacing.md)

            Text("Browse your content assets across time. Tap any piece to preview, review AI suggestions, and edit.")
                .font(.spaceMono(11))
                .lineSpacing(4)
                .foregroundColor(lightMode ? .black.opacity(0.45) : .white.opacity(0.4))
        }
        .frame(maxWidth: 320, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, ENVISpacing.lg)
        .padding(.leading, ENVISpacing.xxl)
    }

    // MARK: - Top-Right Content Types

    private var topRightContentTypes: some View {
        MainAppContentTypeLegend(
            items: [
                (ContentType.photo.label, typeFilterDotColor(.photo)),
                (ContentType.video.label, typeFilterDotColor(.video)),
                (ContentType.carousel.label, typeFilterDotColor(.carousel)),
                (ContentType.reel.label, typeFilterDotColor(.reel)),
                (ContentType.story.label, typeFilterDotColor(.story))
            ],
            selectedLabel: activeTypeFilter?.label
        ) { label in
            guard let tappedType = [ContentType.photo, .video, .carousel, .reel, .story].first(where: { $0.label == label }) else {
                return
            }
            let isActive = activeTypeFilter == tappedType
            withAnimation(.easeOut(duration: 0.15)) {
                activeTypeFilter = isActive ? nil : tappedType
                sceneController?.activeTypeFilter = activeTypeFilter
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, ENVISpacing.lg)
        .padding(.trailing, ENVISpacing.xxl)
    }

    private func typeFilterDotColor(_ type: ContentType) -> Color {
        switch type {
        case .video, .reel: return Color(hex: "#30217C")
        case .carousel:     return Color(hex: "#A0A0A0")
        default:            return Color(hex: "#E0E0E0")
        }
    }

    // MARK: - Right-Side Time Scrubber

    private var rightSideScrubber: some View {
        // Previously wrapped in a VStack + unconstrained GeometryReader, which
        // made the reader claim the full screen width — so `.alignment:
        // .trailing` on the outer frame was a no-op and the 41-wide scrubber
        // column rendered on the LEFT edge. Pinning the GeometryReader to its
        // intrinsic 41×433 before expanding with trailing alignment is what
        // actually parks the rail on the right side of the screen.
        GeometryReader { geo in
            ZStack {
                MainAppScrubber(
                    month: scrubDateLabel,
                    zoom: ExplorerZoomLevel.allCases.map(\.shortLabel),
                    selectedZoom: zoomLevel.shortLabel
                ) { shortLabel in
                    guard let level = ExplorerZoomLevel.allCases.first(where: { $0.shortLabel == shortLabel }) else {
                        return
                    }
                    zoomLevel = level
                    sceneController?.zoomLevel = level
                }

                HStack(spacing: 6) {
                    Text(scrubDateLabel)
                        .font(.spaceMono(9))
                        .tracking(1.5)
                        .foregroundColor(lightMode ? .black.opacity(0.6) : .white.opacity(0.7))
                        .fixedSize()

                    Circle()
                        .fill(lightMode ? Color(hex: "#222222") : .white)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .strokeBorder(lightMode ? Color.black.opacity(0.4) : Color.white.opacity(0.6), lineWidth: 1.5)
                        )
                        .shadow(color: lightMode ? .black.opacity(0.2) : .white.opacity(0.4), radius: 3)
                }
                // Center the HStack so the dot sits on the rail (rail is the
                // 1pt vertical line centered in the 41pt column, i.e. x ≈ 20).
                // The date label floats to the left of the dot naturally.
                .position(x: 20.5, y: geo.size.height * timePosition)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newPos = max(0, min(1, value.location.y / geo.size.height))
                        timePosition = newPos
                        sceneController?.timePosition = Float(newPos)
                        sceneController?.isPaused = true
                        sceneController?.userControlling = true
                        sceneController?.isScrubbing = true
                    }
                    .onEnded { _ in
                        sceneController?.isScrubbing = false
                    }
            )
        }
        // Lock the GeometryReader to the scrubber's intrinsic size FIRST.
        .frame(width: 41, height: 433)
        // Then expand into the containing ZStack and pin to the trailing edge
        // — this is what actually puts the rail on the right side.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .padding(.trailing, ENVISpacing.xxl)
    }

    private var scrubDateLabel: String {
        let tlStart = Foundation.Date(timeIntervalSince1970: 1772870400) // 2026-03-05
        let tlEnd = Foundation.Date(timeIntervalSince1970: 1774857600)   // 2026-03-28
        let range = tlEnd.timeIntervalSince(tlStart)
        let ti = tlStart.timeIntervalSince1970 + range * Double(timePosition)
        let current = Foundation.Date(timeIntervalSince1970: ti)
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: current).uppercased()
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 0) {
                MainAppSuggestionPanel(
                    title: "EXPLORE MORE",
                    longItems: [
                        "How am I balancing my content?",
                        "What should I create next?",
                        "What patterns do you see in my engagement?"
                    ],
                    shortItems: ["Strategy", "Calendar", "Repurpose"]
                ) { prompt in
                    explorerPrompt = prompt
                    submitExplorerPrompt()
                }
                .padding(.horizontal, ENVISpacing.xxl)
                .padding(.bottom, ENVISpacing.lg)

                // Input row
                ZStack(alignment: .bottomLeading) {
                    ENVIBottomComposer(
                        text: $explorerPrompt,
                        lightMode: lightMode,
                        isPlusMenuOpen: $plusMenuOpen,
                        onPlusTap: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                plusMenuOpen.toggle()
                            }
                        },
                        onVoiceTap: { openVoice() },
                        onCompassTap: { resetView() },
                        onSendTap: { submitExplorerPrompt() }
                    )
                    
                    if plusMenuOpen {
                        plusMenu
                            .offset(x: ENVISpacing.xxl, y: -60)
                            .transition(.scale(scale: 0.8, anchor: .bottomLeading).combined(with: .opacity))
                    }
                }
            }
            .padding(.top, ENVISpacing.xxxl)
            .padding(.bottom, ENVISpacing.xl)
            .background(
                LinearGradient(
                    colors: lightMode
                        ? [Color(hex: "#F0F0F0").opacity(0.85), Color(hex: "#F0F0F0").opacity(0.6), .clear]
                        : [.black.opacity(0.85), .black.opacity(0.6), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .ignoresSafeArea()
            )
        }
    }

    // MARK: - Plus Menu

    private var plusMenu: some View {
        VStack(alignment: .leading, spacing: 2) {
            plusMenuItem(icon: "paperclip", label: "ATTACH") {
                showPhotoPicker = true
                plusMenuOpen = false
            }
            plusMenuItem(icon: "clock", label: "TIMELINE") {
                explorerNotice = ExplorerNotice(
                    title: "Content Timeline",
                    message: "You are already in your Content Timeline. Tap a piece or ask ENVI what to repurpose next."
                )
                plusMenuOpen = false
            }
            plusMenuItem(
                icon: viewMode == .stream ? "line.3.horizontal" : "tornado",
                label: viewMode == .stream ? "SPIRAL VIEW" : "STREAM VIEW"
            ) {
                let next: ExplorerViewMode = viewMode == .stream ? .spiral : .stream
                viewMode = next
                sceneController?.setViewMode(next)
                plusMenuOpen = false
            }
            plusMenuItem(
                icon: lightMode ? "sun.max" : "moon",
                label: lightMode ? "DARK MODE" : "LIGHT MODE"
            ) {
                lightMode.toggle()
                sceneController?.lightMode = lightMode
                plusMenuOpen = false
            }

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 0.5)
                .padding(.vertical, 2)

            plusMenuItem(icon: "gearshape", label: "CONNECTORS") {
                showSettings = true
                plusMenuOpen = false
            }
        }
        .padding(ENVISpacing.sm)
        .frame(minWidth: 160)
        .background(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .fill(Color.black.opacity(0.9))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    private func plusMenuItem(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ENVISpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 14)
                Text(label)
                    .font(.spaceMono(10))
                    .tracking(1.0)
            }
            .foregroundColor(.white.opacity(0.6))
            .padding(.horizontal, ENVISpacing.md)
            .padding(.vertical, ENVISpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Compass Icon

    private var compassIcon: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let color = lightMode ? Color.black.opacity(0.5) : Color.white.opacity(0.5)

            // Outer ring
            var ring = Path()
            ring.addArc(center: center, radius: 10, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
            context.stroke(ring, with: .color(color.opacity(0.2)), lineWidth: 0.8)

            // North pointer (bright)
            var north = Path()
            north.move(to: CGPoint(x: center.x, y: center.y - 10))
            north.addLine(to: CGPoint(x: center.x + 3, y: center.y))
            north.addLine(to: CGPoint(x: center.x, y: center.y + 1.5))
            north.addLine(to: CGPoint(x: center.x - 3, y: center.y))
            north.closeSubpath()
            context.fill(north, with: .color(color.opacity(0.9)))

            // South pointer (dim)
            var south = Path()
            south.move(to: CGPoint(x: center.x, y: center.y + 10))
            south.addLine(to: CGPoint(x: center.x + 3, y: center.y))
            south.addLine(to: CGPoint(x: center.x, y: center.y - 1.5))
            south.addLine(to: CGPoint(x: center.x - 3, y: center.y))
            south.closeSubpath()
            context.fill(south, with: .color(color.opacity(0.3)))

            // Center dot
            var dot = Path()
            dot.addArc(center: center, radius: 1.5, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
            context.fill(dot, with: .color(color.opacity(0.5)))
        }
    }

    // MARK: - Voice Widget

    private var voiceWidget: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ZStack {
                    // Glow behind pill
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "#3C64C8").opacity(0.35),
                                    Color(hex: "#30217C").opacity(0.2),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .blur(radius: 15)

                    // Pill
                    HStack(spacing: ENVISpacing.md) {
                        // ENVI AI Orb (4x4 dot grid)
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color(hex: "#6EB4FF").opacity(0.7),
                                            Color(hex: "#3C78F0").opacity(0.5),
                                            Color(hex: "#285AD2").opacity(0.3),
                                            .clear
                                        ],
                                        center: UnitPoint(x: 0.38, y: 0.38),
                                        startRadius: 0,
                                        endRadius: 25
                                    )
                                )
                                .frame(width: 48, height: 48)

                            // 4x4 dot grid
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(3.5), spacing: 2.5), count: 4), spacing: 2.5) {
                                ForEach(0..<16, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(Color.white.opacity(0.88))
                                        .frame(width: 3.5, height: 3.5)
                                }
                            }
                            .frame(width: 22, height: 22)
                        }
                        .frame(width: 42, height: 42)

                        // Info
                        VStack(alignment: .leading, spacing: 1) {
                            // Waveform bars
                            HStack(alignment: .bottom, spacing: 2) {
                                ForEach([5, 10, 14, 8, 5], id: \.self) { h in
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(Color.white.opacity(0.75))
                                        .frame(width: 2.5, height: CGFloat(h))
                                }
                            }
                            .frame(height: 14)

                            Text("ENVI listening…")
                                .font(.interMedium(12))
                                .tracking(-0.1)
                                .foregroundColor(.white)

                            Text(voiceTimerLabel)
                                .font(.spaceMono(10))
                                .foregroundColor(.white.opacity(0.4))
                                .monospacedDigit()
                        }

                        // End button
                        Button {
                            closeVoice()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(Color(red: 220/255, green: 50/255, blue: 50/255).opacity(0.8))
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.leading, 10)
                    .padding(.trailing, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#190C32").opacity(0.8))
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 16, y: 4)
                }
            }
            .padding(.trailing, ENVISpacing.xxl)
            .padding(.bottom, ENVISpacing.xxl)
        }
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    private var voiceTimerLabel: String {
        let m = String(format: "%02d", voiceSeconds / 60)
        let s = String(format: "%02d", voiceSeconds % 60)
        return "\(m):\(s)"
    }

    // MARK: - Voice Control

    private func openVoice() {
        voiceActive = true
        voiceClosing = false
        voiceSeconds = 0
        plusMenuOpen = false
        voiceTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            voiceSeconds += 1
        }
    }

    private func closeVoice() {
        voiceClosing = true
        voiceTimer?.invalidate()
        voiceTimer = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            voiceActive = false
            voiceClosing = false
            voiceSeconds = 0
        }
    }

    // MARK: - Reset View

    private func resetView() {
        withAnimation(.easeOut(duration: 0.3)) {
            selectedContent = nil
            selectedContentId = nil
            timePosition = 0.5
        }
        sceneController?.resetCamera()
        sceneController?.timePosition = 0.5
    }

    // MARK: - Assembly Progress Banner

    private func assemblyProgressBanner(progress: Double) -> some View {
        HStack(spacing: ENVISpacing.md) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(Color(hex: "#3C64C8"))
                .frame(maxWidth: 160)

            Text("ASSEMBLING \(assembler.queueCount) PIECE\(assembler.queueCount == 1 ? "" : "S")")
                .font(.spaceMonoBold(10))
                .tracking(1.5)
                .foregroundColor(lightMode ? .black.opacity(0.6) : .white.opacity(0.7))
        }
        .padding(.horizontal, ENVISpacing.xl)
        .padding(.vertical, ENVISpacing.md)
        .background(
            Capsule()
                .fill(lightMode ? Color.white.opacity(0.9) : Color.black.opacity(0.85))
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        )
        .overlay(
            Capsule()
                .strokeBorder(lightMode ? Color.black.opacity(0.1) : Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .padding(.top, 60)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeOut(duration: 0.3), value: assembler.state)
    }

    private func submitExplorerPrompt() {
        let trimmed = explorerPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSuggestionClick?(trimmed)
        plusMenuOpen = false
        explorerPrompt = ""
    }
}

private struct ExplorerNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

// MARK: - PHPicker SwiftUI Wrapper

/// Wraps PHPickerViewController for selecting photos/videos to feed into the assembly pipeline.
struct PhotoPickerView: UIViewControllerRepresentable {

    var onSelection: ([String]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 0 // unlimited
        config.filter = .any(of: [.images, .videos])
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelection: onSelection)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onSelection: ([String]) -> Void

        init(onSelection: @escaping ([String]) -> Void) {
            self.onSelection = onSelection
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            let identifiers = results.compactMap(\.assetIdentifier)
            guard !identifiers.isEmpty else { return }
            onSelection(identifiers)
        }
    }
}

// MARK: - SCNView UIViewRepresentable

/// Bridges the SceneKit controller into SwiftUI with full state synchronization.
struct HelixSceneRepresentable: UIViewRepresentable {

    var onNodeTapped: ((String) -> Void)?
    var onSceneReady: (() -> Void)?
    var onControllerReady: ((HelixSceneController) -> Void)?
    var lightMode: Bool
    var activeTypeFilter: ContentType?
    var selectedContentId: String?
    var timePosition: Float
    var zoomLevel: ExplorerZoomLevel
    var viewMode: ExplorerViewMode

    func makeCoordinator() -> HelixSceneController {
        let controller = HelixSceneController(onNodeTapped: onNodeTapped, onSceneReady: onSceneReady)
        DispatchQueue.main.async {
            onControllerReady?(controller)
        }
        return controller
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .black
        scnView.antialiasingMode = .multisampling4X
        scnView.allowsCameraControl = true // OrbitControls equivalent
        scnView.autoenablesDefaultLighting = false
        scnView.isJitteringEnabled = false
        scnView.defaultCameraController.interactionMode = .orbitTurntable
        scnView.defaultCameraController.minimumVerticalAngle = -60
        scnView.defaultCameraController.maximumVerticalAngle = 60
        scnView.isAccessibilityElement = false
        scnView.accessibilityElementsHidden = true
        scnView.shouldGroupAccessibilityChildren = false

        context.coordinator.setupScene(in: scnView)

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(HelixSceneController.handleTap(_:))
        )
        scnView.addGestureRecognizer(tapGesture)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        let controller = context.coordinator
        controller.lightMode = lightMode
        controller.activeTypeFilter = activeTypeFilter
        controller.selectedContentId = selectedContentId
        controller.timePosition = timePosition
        controller.zoomLevel = zoomLevel
        if controller.viewMode != viewMode {
            controller.setViewMode(viewMode)
        }
    }
}

// MARK: - Pulse Modifier

private struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 1.0 : 0.3)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

// MARK: - Number Formatting

extension Int {
    var formattedShort: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000)
        }
        return "\(self)"
    }
}

// MARK: - Score Color

func scoreColor(for score: Int) -> Color {
    if score >= 90 { return Color(hex: "#4ADE80") }
    if score >= 80 { return Color(hex: "#FBBF24") }
    if score >= 70 { return Color(hex: "#FB923C") }
    return Color(hex: "#F87171")
}

#if DEBUG
struct WorldExplorerView_Previews: PreviewProvider {
    static var previews: some View {
        WorldExplorerView()
    }
}
#endif
