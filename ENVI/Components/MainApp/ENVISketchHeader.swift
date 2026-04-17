import SwiftUI

/// Shared top header for the ENVI app.
/// Matches Sketch "Main App" top row: left utility pill, centered segmented pill, right utility icon.
struct ENVISketchHeader<Leading: View, Trailing: View>: View {
    let options: [String]
    let selectedIndex: Int
    let onSegmentChange: (Int) -> Void
    @ViewBuilder let leadingView: Leading
    @ViewBuilder let trailingView: Trailing

    var body: some View {
        ZStack {
            HStack {
                leadingView
                Spacer()
                trailingView
            }

            MainAppTopSegmentSwitch(
                options: options,
                selectedIndex: selectedIndex,
                action: onSegmentChange
            )
        }
        .frame(height: 48)
        .padding(.horizontal, MainAppSketch.screenInset)
    }
}
