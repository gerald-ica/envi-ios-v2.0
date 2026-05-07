import SwiftUI

// MARK: - Approval Flow View
/// Card-based swipe interface for approving/rejecting ENVI edits.
/// Swipe right = approve, left = reject, up = save for later.
@MainActor
public struct ApprovalFlowView: View {
    @State private var isApproved: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            if isApproved {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                    Text("Edit approved!")
                        .font(.title2.weight(.semibold))
                    Button("Edit Another") {
                        isApproved = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 24) {
                    Spacer()
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 72))
                        .foregroundStyle(.secondary)
                    Text("Your edit is ready for review")
                        .font(.title3.weight(.semibold))
                    HStack(spacing: 24) {
                        Button {
                            // Reject
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.red)
                        }
                        Button {
                            isApproved = true
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.green)
                        }
                    }
                    Spacer()
                }
            }
        }
        .navigationTitle("Approval")
    }
}

// MARK: - Preview

#Preview {
    ApprovalFlowView()
}
