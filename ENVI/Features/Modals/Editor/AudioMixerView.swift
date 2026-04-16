import SwiftUI

/// Audio mixer panel: manage audio tracks with volume, fades, mute/solo, and waveform visualization.
struct AudioMixerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AudioMixerViewModel()

    var body: some View {
        ZStack {
            ENVITheme.Dark.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                trackList
                addTrackSection
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $viewModel.showMusicLibrary) {
            MusicLibrarySheet(onSelect: { track in
                viewModel.addTrack(track)
                viewModel.showMusicLibrary = false
            })
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }

            Spacer()

            Text("AUDIO")
                .font(.spaceMonoBold(17))
                .foregroundColor(.white)
                .tracking(-1)

            Spacer()

            // Balance spacer
            Color.clear.frame(width: 18, height: 18)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    // MARK: - Track List

    private var trackList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach($viewModel.tracks) { $track in
                    AudioTrackRow(track: $track)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    // MARK: - Add Track

    private var addTrackSection: some View {
        VStack(spacing: 12) {
            Button {
                viewModel.showMusicLibrary = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                    Text("ADD MUSIC")
                        .font(.spaceMonoBold(13))
                        .tracking(1)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: ENVIRadius.lg)
                        .fill(ENVITheme.Dark.surfaceHigh)
                )
            }
        }
        .padding(16)
    }
}

// MARK: - Audio Track Row

private struct AudioTrackRow: View {
    @Binding var track: AudioTrackItem

    var body: some View {
        VStack(spacing: 8) {
            // Header: name, mute, solo
            HStack {
                Text(track.name.uppercased())
                    .font(.spaceMonoBold(11))
                    .foregroundColor(.white)
                    .tracking(1)
                    .lineLimit(1)

                Spacer()

                // Mute toggle
                Button {
                    track.isMuted.toggle()
                } label: {
                    Text("M")
                        .font(.spaceMonoBold(10))
                        .foregroundColor(track.isMuted ? .red : .white.opacity(0.5))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(track.isMuted ? Color.red.opacity(0.2) : ENVITheme.Dark.surfaceHigh)
                        )
                }

                // Solo toggle
                Button {
                    track.isSoloed.toggle()
                } label: {
                    Text("S")
                        .font(.spaceMonoBold(10))
                        .foregroundColor(track.isSoloed ? .yellow : .white.opacity(0.5))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(track.isSoloed ? Color.yellow.opacity(0.2) : ENVITheme.Dark.surfaceHigh)
                        )
                }
            }

            // Waveform visualization (bar approximation)
            WaveformBarsView(isMuted: track.isMuted)
                .frame(height: 32)

            // Volume slider
            HStack(spacing: 8) {
                Image(systemName: track.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 20)

                Slider(value: $track.volume, in: 0...1)
                    .tint(.white)

                Text("\(Int(track.volume * 100))%")
                    .font(.interRegular(11))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 36)
            }

            // Fade controls
            HStack(spacing: 16) {
                FadeControl(label: "FADE IN", value: $track.fadeInDuration)
                FadeControl(label: "FADE OUT", value: $track.fadeOutDuration)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .fill(ENVITheme.Dark.surfaceLow)
        )
    }
}

// MARK: - Fade Control

private struct FadeControl: View {
    let label: String
    @Binding var value: TimeInterval

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.spaceMonoBold(8))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1)

            Slider(value: $value, in: 0...5, step: 0.5)
                .tint(.white.opacity(0.6))

            Text(String(format: "%.1fs", value))
                .font(.interRegular(10))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 30)
        }
    }
}

// MARK: - Waveform Bars

/// Procedural waveform bar visualization.
private struct WaveformBarsView: View {
    let isMuted: Bool
    private let barCount = 40

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1.5) {
                ForEach(0..<barCount, id: \.self) { i in
                    let height = barHeight(index: i, total: barCount, containerHeight: geo.size.height)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isMuted ? Color.white.opacity(0.1) : Color.white.opacity(0.4))
                        .frame(width: max(2, (geo.size.width - CGFloat(barCount) * 1.5) / CGFloat(barCount)),
                               height: height)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
            }
        }
    }

    private func barHeight(index: Int, total: Int, containerHeight: CGFloat) -> CGFloat {
        // Deterministic pseudo-waveform using sine combinations
        let x = Double(index) / Double(total)
        let wave = abs(sin(x * .pi * 3.5)) * 0.6 + abs(sin(x * .pi * 7.2 + 1.3)) * 0.3 + 0.1
        return containerHeight * CGFloat(wave)
    }
}

// MARK: - Music Library Sheet

private struct MusicLibrarySheet: View {
    let onSelect: (AudioTrackItem) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ENVITheme.Dark.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("MUSIC LIBRARY")
                        .font(.spaceMonoBold(17))
                        .foregroundColor(.white)
                        .tracking(-1)

                    Spacer()

                    Button("Done") { dismiss() }
                        .font(.spaceMonoBold(14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(16)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(AudioTrackItem.builtInTracks) { track in
                            Button {
                                onSelect(track)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white.opacity(0.5))
                                        .frame(width: 36, height: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                                                .fill(ENVITheme.Dark.surfaceHigh)
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.name.uppercased())
                                            .font(.spaceMonoBold(13))
                                            .foregroundColor(.white)
                                            .tracking(0.5)
                                        Text("Built-in")
                                            .font(.interRegular(11))
                                            .foregroundColor(.white.opacity(0.4))
                                    }

                                    Spacer()

                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: ENVIRadius.lg)
                                        .fill(ENVITheme.Dark.surfaceLow)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - ViewModel

final class AudioMixerViewModel: ObservableObject {
    @Published var tracks: [AudioTrackItem] = [
        AudioTrackItem(name: "Original Audio", url: "original", volume: 0.8)
    ]
    @Published var showMusicLibrary = false

    func addTrack(_ track: AudioTrackItem) {
        tracks.append(track)
    }

    func removeTrack(at offsets: IndexSet) {
        tracks.remove(atOffsets: offsets)
    }
}
