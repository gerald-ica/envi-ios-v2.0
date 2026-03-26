import SwiftUI
import Combine

/// ViewModel for the Video Editor screen.
final class EditorViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 30.0
    @Published var showExportSheet = false

    let tools = ["Trim", "Adjust", "Text", "Audio", "Filters", "Crop"]
    let toolIcons = ["scissors", "slider.horizontal.3", "textformat", "waveform", "camera.filters", "crop"]

    func togglePlayback() { isPlaying.toggle() }
    func exportVideo() { showExportSheet = true }
}
