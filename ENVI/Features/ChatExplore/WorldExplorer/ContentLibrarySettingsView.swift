import SwiftUI

// MARK: - Content Library Settings View

/// A sheet/modal presented from the plus menu for configuring content sources,
/// connected accounts, and content type filters.
struct ContentLibrarySettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - State

    @State private var contentSource: SourceOption = .contentLibrary
    @State private var autoCreateContent: Bool = true
    @State private var showPhotos: Bool = true
    @State private var showVideos: Bool = true
    @State private var showCarousels: Bool = true
    @State private var showStories: Bool = true
    @State private var showReels: Bool = true

    /// Local picker option — maps to ContentSource without shadowing it.
    enum SourceOption: String, CaseIterable {
        case photoLibrary = "Photo Library"
        case contentLibrary = "Content Timeline"

        var description: String {
            switch self {
            case .photoLibrary:
                return "Access your camera roll directly. ENVI will scan and organize your photos and videos."
            case .contentLibrary:
                return "ENVI's curated timeline of already-edited content pieces assembled from your camera roll."
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: - Content Source Section
                    sectionHeader("CONTENT SOURCE")

                    VStack(spacing: ENVISpacing.sm) {
                        ForEach(SourceOption.allCases, id: \.rawValue) { source in
                            Button {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    contentSource = source
                                }
                            } label: {
                                HStack(spacing: ENVISpacing.md) {
                                    Image(systemName: source == .photoLibrary ? "photo.on.rectangle" : "square.stack.3d.up")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(contentSource == source ? ENVITheme.text(for: colorScheme) : ENVITheme.textSecondary(for: colorScheme))
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(source.rawValue.uppercased())
                                            .font(.spaceMonoBold(11))
                                            .tracking(2.0)
                                            .foregroundColor(contentSource == source ? ENVITheme.text(for: colorScheme) : ENVITheme.textSecondary(for: colorScheme))

                                        Text(source.description)
                                            .font(.spaceMono(10))
                                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                                            .lineSpacing(2)
                                    }

                                    Spacer()

                                    if contentSource == source {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(ENVITheme.accent(for: colorScheme))
                                    }
                                }
                                .padding(ENVISpacing.lg)
                                .background(
                                    RoundedRectangle(cornerRadius: ENVIRadius.lg)
                                        .fill(contentSource == source
                                            ? ENVITheme.border(for: colorScheme)
                                            : Color.clear
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: ENVIRadius.lg)
                                        .strokeBorder(
                                            contentSource == source
                                                ? ENVITheme.border(for: colorScheme)
                                                : ENVITheme.border(for: colorScheme),
                                            lineWidth: 0.5
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, ENVISpacing.xxl)

                    // Info text
                    Text("Content pieces are assembled from your camera roll. ENVI automatically edits and creates short-form media from your photos and videos.")
                        .font(.spaceMono(10))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        .lineSpacing(3)
                        .padding(.bottom, ENVISpacing.xxxl)

                    divider

                    // MARK: - Auto-Create Toggle
                    sectionHeader("AUTO-CREATE")

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AUTO-CREATE CONTENT")
                                .font(.spaceMonoBold(11))
                                .tracking(2.0)
                                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                            Text("ENVI will automatically generate short-form content from new camera roll items")
                                .font(.spaceMono(10))
                                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                                .lineSpacing(2)
                        }
                        Spacer()
                        Toggle("", isOn: $autoCreateContent)
                            .labelsHidden()
                            .tint(ENVITheme.accent(for: colorScheme))
                    }
                    .padding(ENVISpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: ENVIRadius.lg)
                            .fill(ENVITheme.surfaceLow(for: colorScheme).opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ENVIRadius.lg)
                            .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 0.5)
                    )
                    .padding(.bottom, ENVISpacing.xxxl)

                    divider

                    // MARK: - Connected Accounts
                    sectionHeader("CONNECTED ACCOUNTS")

                    VStack(spacing: ENVISpacing.sm) {
                        connectedAccountRow(platform: "Instagram", icon: "camera", connected: true)
                        connectedAccountRow(platform: "TikTok", icon: "music.note", connected: true)
                        connectedAccountRow(platform: "YouTube", icon: "play.rectangle", connected: false)
                        connectedAccountRow(platform: "X / Twitter", icon: "bubble.left", connected: false)
                        connectedAccountRow(platform: "LinkedIn", icon: "briefcase", connected: false)
                    }
                    .padding(.bottom, ENVISpacing.xxxl)

                    divider

                    // MARK: - Content Types
                    sectionHeader("CONTENT TYPES")

                    Text("Choose which content types to display in the explorer")
                        .font(.spaceMono(10))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        .padding(.bottom, ENVISpacing.md)

                    VStack(spacing: ENVISpacing.sm) {
                        contentTypeToggle(label: "PHOTO", isOn: $showPhotos)
                        contentTypeToggle(label: "VIDEO", isOn: $showVideos)
                        contentTypeToggle(label: "CAROUSEL", isOn: $showCarousels)
                        contentTypeToggle(label: "STORY", isOn: $showStories)
                        contentTypeToggle(label: "REEL", isOn: $showReels)
                    }
                    .padding(.bottom, ENVISpacing.xxxl)
                }
                .padding(.horizontal, ENVISpacing.xxl)
                .padding(.vertical, ENVISpacing.xl)
            }
            .background(ENVITheme.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SETTINGS")
                        .font(.spaceMonoBold(12))
                        .tracking(2.5)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("DONE")
                            .font(.spaceMonoBold(11))
                            .tracking(2.0)
                            .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: ENVISpacing.md) {
            Text(title)
                .font(.spaceMonoBold(10))
                .tracking(2.5)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            Rectangle()
                .fill(ENVITheme.border(for: colorScheme))
                .frame(height: 0.5)
        }
        .padding(.bottom, ENVISpacing.lg)
    }

    private var divider: some View {
        Rectangle()
            .fill(ENVITheme.border(for: colorScheme))
            .frame(height: 0.5)
            .padding(.bottom, ENVISpacing.xxl)
    }

    private func connectedAccountRow(platform: String, icon: String, connected: Bool) -> some View {
        HStack(spacing: ENVISpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(connected ? ENVITheme.textSecondary(for: colorScheme) : ENVITheme.textSecondary(for: colorScheme).opacity(0.5))
                .frame(width: 20)

            Text(platform.uppercased())
                .font(.spaceMonoBold(11))
                .tracking(2.0)
                .foregroundColor(connected ? ENVITheme.textSecondary(for: colorScheme) : ENVITheme.textSecondary(for: colorScheme).opacity(0.5))

            Spacer()

            if connected {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "#4ADE80"))
                        .frame(width: 6, height: 6)
                    Text("CONNECTED")
                        .font(.spaceMono(9))
                        .tracking(1.0)
                        .foregroundColor(Color(hex: "#4ADE80").opacity(0.7))
                }
            } else {
                Button {} label: {
                    Text("CONNECT")
                        .font(.spaceMonoBold(9))
                        .tracking(1.5)
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        .padding(.horizontal, ENVISpacing.sm)
                        .padding(.vertical, ENVISpacing.xs)
                        .overlay(
                            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 0.5)
                        )
                }
            }
        }
        .padding(.vertical, ENVISpacing.md)
        .padding(.horizontal, ENVISpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .fill(ENVITheme.surfaceLow(for: colorScheme).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 0.5)
        )
    }

    private func contentTypeToggle(label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.spaceMonoBold(11))
                .tracking(2.0)
                .foregroundColor(isOn.wrappedValue ? ENVITheme.textSecondary(for: colorScheme) : ENVITheme.textSecondary(for: colorScheme).opacity(0.5))

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(ENVITheme.accent(for: colorScheme))
        }
        .padding(.vertical, ENVISpacing.sm)
        .padding(.horizontal, ENVISpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .fill(ENVITheme.surfaceLow(for: colorScheme).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 0.5)
        )
    }
}

#if DEBUG
struct ContentLibrarySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ContentLibrarySettingsView()
    }
}
#endif
