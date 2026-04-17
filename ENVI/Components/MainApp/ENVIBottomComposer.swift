import SwiftUI

struct ENVIBottomComposer: View {
    @Binding var text: String
    var lightMode: Bool
    var isPlusMenuOpen: Binding<Bool>
    var onPlusTap: () -> Void
    var onVoiceTap: () -> Void
    var onCompassTap: () -> Void
    var onSendTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Plus (+) button
            Button(action: onPlusTap) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(lightMode ? .black.opacity(0.5) : .white.opacity(0.5))
                    .rotationEffect(.degrees(isPlusMenuOpen.wrappedValue ? 45 : 0))
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

            // Text input
            HStack(spacing: 0) {
                TextField("", text: $text, prompt:
                    Text("Ask ENVI to edit, analyze, or create...")
                        .font(.spaceMono(12))
                        .foregroundColor(lightMode ? .black.opacity(0.25) : .white.opacity(0.25))
                )
                .font(.spaceMono(12))
                .foregroundColor(lightMode ? .black.opacity(0.8) : .white.opacity(0.8))
                .onSubmit {
                    onSendTap()
                }

                // Send arrow
                Button(action: onSendTap) {
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
            Button(action: onVoiceTap) {
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

            // Compass button
            Button(action: onCompassTap) {
                CompassIcon(lightMode: lightMode)
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
}

private struct CompassIcon: View {
    var lightMode: Bool
    
    var body: some View {
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
}
