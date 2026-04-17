import SwiftUI

enum MainAppSketch {
    static let screenWidth: CGFloat = 393
    static let screenInset: CGFloat = 24
    static let contentInset: CGFloat = 16
    static let tabPillWidth: CGFloat = 164
    static let tabPillHeight: CGFloat = 64
    static let activeTabSize: CGFloat = 45
    static let topSwitchWidth: CGFloat = 220
    static let topSwitchHeight: CGFloat = 40
    static let topSwitchActiveWidth: CGFloat = 100
    static let topSwitchActiveHeight: CGFloat = 32
    static let searchBarWidth: CGFloat = 324
    static let searchBarHeight: CGFloat = 48
    static let feedCardHeight: CGFloat = 480
    static let profileRowHeight: CGFloat = 40
    static let subscriptionHeight: CGFloat = 50
    static let kpiCardHeight: CGFloat = 99
    static let kpiCardWidth: CGFloat = 111

    static let background = Color(hex: "#000000")
    static let surfaceLow = Color(hex: "#1A1A1A")
    static let surfaceHigh = Color(hex: "#2A2A2A")
    static let tabTint = Color(hex: "#4A60B2")
    static let text = Color.white
    static let textLight = Color.white.opacity(0.5)
    static let textSecondary = Color.white.opacity(0.7)
    static let border = Color.white.opacity(0.12)
    static let divider = Color.white.opacity(0.46)
    static let subtleDivider = Color.white.opacity(0.08)
}

struct MainAppMonoLabel: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.spaceMonoBold(11))
            .tracking(0.88)
            .foregroundColor(MainAppSketch.textSecondary)
    }
}

struct MainAppTopSegmentSwitch: View {
    let options: [String]
    let selectedIndex: Int
    let action: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, title in
                Button {
                    action(index)
                } label: {
                    Text(title)
                        .font(.spaceMonoBold(13))
                        .tracking(1.4)
                        .foregroundColor(index == selectedIndex ? .black : MainAppSketch.textSecondary)
                        .frame(width: MainAppSketch.topSwitchActiveWidth, height: MainAppSketch.topSwitchActiveHeight)
                        .background(index == selectedIndex ? Color.white : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .frame(width: MainAppSketch.topSwitchWidth, height: MainAppSketch.topSwitchHeight)
        .background(MainAppSketch.surfaceLow)
        .overlay(
            Capsule()
                .stroke(MainAppSketch.border, lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

struct MainAppUtilityChatPill: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 34, height: 32)

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Sketch "Search Icon" symbol — 34×32 white pill with a black magnifier glass.
struct MainAppSearchPill: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 34, height: 32)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#0D0D0D"))
            }
        }
        .buttonStyle(.plain)
    }
}

/// Sketch "Content Calendar icon" — 24×24 custom glyph with two top binding tabs.
/// Uses a SwiftUI Canvas-style composition to match the Sketch geometry.
struct MainAppContentCalendarIcon: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .top) {
                // Two 1×3 binding tabs at the top (Sketch x≈6 and x≈15 of 24)
                HStack(spacing: 8) {
                    Capsule().fill(Color.white).frame(width: 1.5, height: 4)
                    Capsule().fill(Color.white).frame(width: 1.5, height: 4)
                }
                .offset(y: -1)

                VStack(spacing: 0) {
                    // 18×4 header stripe (days-of-week bar) — white solid
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 18, height: 4)
                    // 18×11 body — outlined rectangle
                    Rectangle()
                        .stroke(Color.white, lineWidth: 1.5)
                        .frame(width: 18, height: 11)
                        .offset(y: -0.75)
                }
                .offset(y: 4)
            }
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
    }
}

struct MainAppUtilityIcon: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(MainAppSketch.text)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
    }
}

struct MainAppSearchBar: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(MainAppSketch.textLight)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .foregroundColor(MainAppSketch.text)
                .font(.interRegular(14))
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: MainAppSketch.searchBarHeight)
        .background(MainAppSketch.surfaceLow)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MainAppSketch.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct MainAppProfileStatBox: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.spaceMonoBold(24))
                .tracking(-0.8)
                .foregroundColor(MainAppSketch.text)
            Text(label)
                .font(.spaceMonoBold(10))
                .tracking(0.8)
                .foregroundColor(MainAppSketch.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .background(MainAppSketch.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct MainAppSubscriptionRow: View {
    let title: String
    let subtitle: String
    var isActive: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(MainAppSketch.text)
                    .frame(width: 35, height: 35)
                    .background(Circle().fill(Color.white.opacity(0.08)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.spaceMonoBold(11))
                        .tracking(0.88)
                        .foregroundColor(MainAppSketch.text)
                    Text(subtitle)
                        .font(.interRegular(14))
                        .foregroundColor(MainAppSketch.textSecondary)
                }

                Spacer()

                Text("›")
                    .font(.system(size: 21, weight: .regular))
                    .foregroundColor(MainAppSketch.textSecondary)
            }
            .padding(.horizontal, 12)
            .frame(height: MainAppSketch.subscriptionHeight)
            .background(MainAppSketch.surfaceLow.opacity(0.54))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct MainAppSettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(MainAppSketch.text)
                    .frame(width: 24)

                Text(title)
                    .font(.interRegular(15))
                    .foregroundColor(MainAppSketch.text)

                Spacer()

                Text("›")
                    .font(.system(size: 21, weight: .regular))
                    .foregroundColor(MainAppSketch.textSecondary)
            }
            .padding(.horizontal, 6)
            .frame(height: MainAppSketch.profileRowHeight)
        }
        .buttonStyle(.plain)
    }
}

struct MainAppConnectionRow: View {
    let icon: String
    let title: String
    let badge: String
    let badgeSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(MainAppSketch.text)
                    .frame(width: 32, height: 32)

                Text(title)
                    .font(.interSemiBold(15))
                    .foregroundColor(MainAppSketch.text)

                Spacer()

                Text(badge)
                    .font(.spaceMonoBold(10))
                    .tracking(0.8)
                    .foregroundColor(badgeSelected ? .black : MainAppSketch.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(badgeSelected ? Color.white : MainAppSketch.surfaceHigh)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 6)
            .frame(height: MainAppSketch.profileRowHeight)
        }
        .buttonStyle(.plain)
    }
}

struct MainAppContentTypeLegend: View {
    let items: [(String, Color)]
    var selectedLabel: String?
    var action: ((String) -> Void)? = nil

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("CONTENT TYPES")
                .font(.spaceMonoBold(11))
                .tracking(1.2)
                .foregroundColor(MainAppSketch.text)

            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let isSelected = selectedLabel == item.0
                Button {
                    action?(item.0)
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(item.1)
                            .frame(width: isSelected ? 10 : 8, height: isSelected ? 10 : 8)
                            .shadow(color: isSelected ? item.1.opacity(0.8) : .clear, radius: 4)
                        Text(item.0)
                            .font(.spaceMono(10))
                            .foregroundColor(isSelected ? MainAppSketch.text : MainAppSketch.textSecondary)
                    }
                    .opacity(selectedLabel == nil || isSelected ? 1 : 0.3)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct MainAppScrubber: View {
    let month: String
    let zoom: [String]
    let selectedZoom: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .center) {
                Rectangle()
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 1, height: 320)

                HStack(spacing: 4) {
                    Text(month)
                        .font(.spaceMono(10))
                        .foregroundColor(MainAppSketch.textSecondary)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                }
                .offset(y: -10)
            }

            VStack(spacing: 4) {
                ForEach(zoom, id: \.self) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        Text(option)
                            .font(.spaceMonoBold(10))
                            .foregroundColor(selectedZoom == option ? .black : MainAppSketch.text)
                            .frame(width: 24, height: 24)
                            .background(selectedZoom == option ? Color.white : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 41, height: 433)
    }
}

struct MainAppSuggestionPanel: View {
    let title: String
    let longItems: [String]
    let shortItems: [String]
    let action: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.spaceMonoBold(11))
                .tracking(1.0)
                .foregroundColor(MainAppSketch.text)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(longItems, id: \.self) { item in
                    Button { action(item) } label: {
                        HStack {
                            Text(item)
                                .font(.interRegular(13))
                                .foregroundColor(MainAppSketch.textSecondary)
                            Spacer()
                            Text("›")
                                .font(.system(size: 17))
                                .foregroundColor(MainAppSketch.textSecondary)
                        }
                        .padding(.vertical, 4)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 7) {
                ForEach(shortItems, id: \.self) { item in
                    Button { action(item) } label: {
                        Text(item)
                            .font(.spaceMonoBold(10))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 336, alignment: .leading)
    }
}

struct MainAppHeader: View {
    let selectedIndex: Int
    let onSegmentChange: (Int) -> Void
    let onSearch: () -> Void
    let onCalendar: () -> Void

    var body: some View {
        ZStack {
            HStack {
                MainAppSearchPill(action: onSearch)
                Spacer()
                MainAppContentCalendarIcon(action: onCalendar)
            }

            MainAppTopSegmentSwitch(
                options: ["For You", "Gallery"],
                selectedIndex: selectedIndex,
                action: onSegmentChange
            )
        }
        .frame(height: 48)
        .padding(.horizontal, MainAppSketch.screenInset)
    }
}
