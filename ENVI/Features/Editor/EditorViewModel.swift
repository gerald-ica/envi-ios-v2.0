import SwiftUI
import Combine

/// ViewModel for the Video Editor screen.
final class EditorViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 30.0
    @Published var showExportSheet = false

    let tools = ["Trim", "Crop", "Filters", "Speed", "Rotate", "Adjust"]
    let toolIcons = ["scissors", "crop", "camera.filters", "gauge.with.needle", "rotate.right", "slider.horizontal.3"]

    func togglePlayback() { isPlaying.toggle() }
    func exportVideo() { showExportSheet = true }
}
