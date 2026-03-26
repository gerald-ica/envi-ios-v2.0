import SwiftUI
import SceneKit

// MARK: - Content Library

/// Static content library matching the React original's CONTENT_PIECES and CONTENT_IMAGES.
enum ContentLibrary {

    /// Image names mapping to resources in ENVI/Resources/Images/
    static let imageNames: [String] = [
        "Closer",           // content-1
        "studio-fashion",   // content-2
        "runway",           // content-3
        "fire-stunt",       // content-4
        "jacket",           // content-5
        "fashion-group",    // content-6
        "cyclist",          // content-7
        "red-silhouette",   // content-8
        "culture-food",     // content-9
        "subway",           // content-10
        "desert-car",       // content-11
        "chopsticks",       // content-12
        "parking-garage",   // content-13
        "industrial-girl",  // content-14
    ]

    static let pieces: [ContentPiece] = ContentPiece.sampleLibrary

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
    var onSuggestionClick: (() -> Void)?

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

    /// Reference to the scene controller for state sync
    @State private var sceneController: HelixSceneController?

    /// Voice timer
    @State private var voiceTimer: Timer?

    var body: some View {
        ZStack {
            // Background
            (lightMode ? Color(hex: "#F0F0F0") : Color.black)
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
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: ENVISpacing.lg) {
            Circle()
                .fill(lightMode ? Color.black.opacity(0.4) : Color.white.opacity(0.6))
                .frame(width: 6, height: 6)
                .modifier(PulseModifier())
            Text("LOADING CONTENT LIBRARY")
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

            Text("YOUR CONTENT\nLIBRARY")
                .font(.interBlack(28))
                .tracking(-0.5)
                .lineSpacing(0)
                .foregroundColor(lightMode ? .black : .white)
                .textCase(.uppercase)
                .padding(.bottom, ENVISpacing.md)

            Text("Browse your content assets. Click any piece to preview, review AI suggestions, and edit.")
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
        VStack(alignment: .trailing, spacing: 0) {
            HStack(spacing: ENVISpacing.md) {
                Text("[04]")
                    .font(.spaceMono(11))
                    .foregroundColor(lightMode ? .black.opacity(0.35) : .white.opacity(0.4))
                Text("CONTENT TYPES")
                    .font(.spaceMonoBold(11))
                    .tracking(2.5)
                    .foregroundColor(lightMode ? .black : .white)
            }
            .padding(.bottom, ENVISpacing.lg)

            VStack(alignment: .trailing, spacing: 6) {
                ForEach([ContentType.photo, .video, .carousel, .reel, .story], id: \.self) { type in
                    let isActive = activeTypeFilter == type
                    let dotColor = typeFilterDotColor(type)
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            activeTypeFilter = isActive ? nil : type
                            sceneController?.activeTypeFilter = activeTypeFilter
                        }
                    } label: {
                        HStack(spacing: ENVISpacing.sm) {
                            Text(type.label)
                                .font(.spaceMono(10))
                                .tracking(1.5)
                                .foregroundColor(
                                    isActive
                                        ? (lightMode ? .black : .white)
                                        : (lightMode ? .black.opacity(0.45) : .white.opacity(0.5))
                                )
                            Circle()
                                .fill(dotColor)
                                .frame(width: isActive ? 10 : 8, height: isActive ? 10 : 8)
                                .shadow(color: isActive ? dotColor.opacity(0.8) : .clear, radius: 4)
                        }
                        .opacity(activeTypeFilter == nil || isActive ? 1 : 0.3)
                    }
                }
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
        VStack(spacing: 0) {
            // Scrubber track
            GeometryReader { geo in
                ZStack {
                    // Vertical line
                    Rectangle()
                        .fill(lightMode ? Color.black.opacity(0.15) : Color.white.opacity(0.2))
                        .frame(width: 1)

                    // Draggable indicator
                    VStack(spacing: 0) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(lightMode ? Color(hex: "#222222") : .white)
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .strokeBorder(lightMode ? Color.black.opacity(0.4) : Color.white.opacity(0.6), lineWidth: 1.5)
                                )
                                .shadow(color: lightMode ? .black.opacity(0.2) : .white.opacity(0.4), radius: 3)

                            Text(scrubDateLabel)
                                .font(.spaceMono(9))
                                .tracking(1.5)
                                .foregroundColor(lightMode ? .black.opacity(0.6) : .white.opacity(0.7))
                        }
                    }
                    .position(x: 10, y: geo.size.height * timePosition)
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
            .frame(width: 80, height: UIScreen.main.bounds.height * 0.5)

            // Zoom level buttons
            VStack(spacing: 4) {
                ForEach(ExplorerZoomLevel.allCases, id: \.self) { level in
                    Button {
                        zoomLevel = level
                        sceneController?.zoomLevel = level
                    } label: {
                        Text(level.shortLabel)
                            .font(.spaceMono(10))
                            .foregroundColor(
                                zoomLevel == level
                                    ? (lightMode ? .black : .white)
                                    : (lightMode ? .black.opacity(0.3) : .white.opacity(0.3))
                            )
                            .frame(width: 24, height: 24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(
                                        zoomLevel == level
                                            ? (lightMode ? Color.black.opacity(0.4) : Color.white.opacity(0.5))
                                            : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                    }
                }
            }
            .padding(.top, ENVISpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .padding(.trailing, 64)
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
                // Suggestion chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ENVISpacing.sm) {
                        ForEach([
                            "What does my content say about me?",
                            "Optimize my latest post",
                            "What should I publish next?",
                            "Repurpose my top content",
                            "Analyze engagement trends",
                        ], id: \.self) { chip in
                            Button {
                                onSuggestionClick?()
                            } label: {
                                Text(chip.uppercased())
                                    .font(.spaceMono(11))
                                    .tracking(0.5)
                                    .foregroundColor(lightMode ? .black.opacity(0.6) : .white.opacity(0.7))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .strokeBorder(
                                                lightMode ? Color.black.opacity(0.15) : Color.white.opacity(0.2),
                                                lineWidth: 1
                                            )
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, ENVISpacing.xxl)
                }
                .padding(.bottom, ENVISpacing.lg)

                // Input row
                HStack(spacing: 10) {
                    // Plus (+) button
                    ZStack {
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                plusMenuOpen.toggle()
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(lightMode ? .black.opacity(0.5) : .white.opacity(0.5))
                                .rotationEffect(.degrees(plusMenuOpen ? 45 : 0))
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(lightMode ? Color.white.opacity(0.6) : Color.black.opacity(0.6))
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            lightMode ? Color.black.opacity(0.15) : Color.white.opacity(0.2),
                                            lineWidth: 1
                                        )
                                )
                        }

                        // Expanded menu
                        if plusMenuOpen {
                            plusMenu
                                .offset(y: -180)
                                .transition(.scale(scale: 0.8, anchor: .bottomLeading).combined(with: .opacity))
                        }
                    }

                    // Text input
                    HStack(spacing: 0) {
                        TextField("", text: .constant(""), prompt:
                            Text("Ask ENVI to edit, analyze, or create...")
                                .font(.spaceMono(12))
                                .foregroundColor(lightMode ? .black.opacity(0.25) : .white.opacity(0.25))
                        )
                        .font(.spaceMono(12))
                        .foregroundColor(lightMode ? .black.opacity(0.8) : .white.opacity(0.8))
                        .onTapGesture { plusMenuOpen = false }

                        // Send arrow
                        Button {} label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(lightMode ? .black.opacity(0.4) : .white.opacity(0.4))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(lightMode ? Color.black.opacity(0.15) : Color.white.opacity(0.2))
                            .frame(height: 0.5)
                    }

                    // Voice button
                    Button {
                        openVoice()
                    } label: {
                        Image(systemName: "mic")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(lightMode ? .black.opacity(0.5) : .white.opacity(0.5))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(lightMode ? Color.white.opacity(0.6) : Color.black.opacity(0.6))
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        lightMode ? Color.black.opacity(0.15) : Color.white.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                    }

                    // Compass reset button
                    Button {
                        resetView()
                    } label: {
                        compassIcon
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(lightMode ? Color.white.opacity(0.6) : Color.black.opacity(0.6))
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        lightMode ? Color.black.opacity(0.15) : Color.white.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                    }
                }
                .padding(.horizontal, ENVISpacing.xxl)
            }
            .padding(.top, ENVISpacing.xxxl)
            .padding(.bottom, ENVISpacing.xl)
            .background(
                LinearGradient(
                    colors: lightMode
                        ? [Color(hex: "#F0F0F0"), Color(hex: "#F0F0F0").opacity(0.8), .clear]
                        : [.black, .black.opacity(0.8), .clear],
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
            plusMenuItem(icon: "paperclip", label: "ATTACH") {}
            plusMenuItem(icon: "clock", label: "TIMELINE") {}
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
                                        .fill(Color.red.opacity(0.8))
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
