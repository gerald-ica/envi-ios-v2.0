import UIKit

/// Multi-track horizontal timeline for the video editor.
/// Contains V1 (video), A1 (audio), T1 (text), FX (effects) lanes.
final class TimelineView: UIScrollView {

    struct Track {
        let name: String
        let color: UIColor
        let clips: [ClipData]
    }

    struct ClipData {
        let startNormalized: CGFloat  // 0–1
        let widthNormalized: CGFloat  // 0–1
    }

    private let playhead: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = ENVITheme.UIKit.backgroundDark
        showsHorizontalScrollIndicator = false
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(tracks: [Track], totalWidth: CGFloat) {
        subviews.forEach { $0.removeFromSuperview() }
        contentSize = CGSize(width: totalWidth, height: bounds.height)

        var yOffset: CGFloat = 0
        let trackHeight: CGFloat = 28
        let spacing: CGFloat = 4

        for track in tracks {
            for clip in track.clips {
                let clipView = UIView()
                clipView.backgroundColor = track.color.withAlphaComponent(0.6)
                clipView.layer.cornerRadius = 4
                clipView.frame = CGRect(
                    x: clip.startNormalized * totalWidth,
                    y: yOffset,
                    width: clip.widthNormalized * totalWidth,
                    height: trackHeight
                )
                addSubview(clipView)
            }
            yOffset += trackHeight + spacing
        }

        // Playhead
        addSubview(playhead)
        NSLayoutConstraint.activate([
            playhead.topAnchor.constraint(equalTo: topAnchor),
            playhead.bottomAnchor.constraint(equalTo: bottomAnchor),
            playhead.widthAnchor.constraint(equalToConstant: 2),
            playhead.leadingAnchor.constraint(equalTo: leadingAnchor, constant: totalWidth * 0.3),
        ])
    }
}
