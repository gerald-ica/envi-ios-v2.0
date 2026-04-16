//
//  ConnectAccountEmptyStateView.swift
//  ENVI — Phase 13 (analytics insights read-path).
//
//  Shown by the Analytics / Advanced / Benchmark views when
//  `FeatureFlags.shared.connectorsInsightsLive == true` AND the user
//  has either (a) zero connected providers or (b) no 30-day data yet.
//
//  Deep-links to the Phase 12 `ConnectedAccountsView` via a callback so
//  this view stays decoupled from the parent navigation stack.
//
import SwiftUI

struct ConnectAccountEmptyStateView: View {

    /// Invoked when the user taps the primary CTA. Callers route to the
    /// Phase 12 `ConnectedAccountsView`.
    let onConnect: () -> Void

    /// Optional secondary copy used for the Advanced + Benchmark screens
    /// (e.g. "Connect to see competitive benchmarks"). Defaults to the
    /// Analytics copy.
    var subtitle: String = "We’ll sync your stats nightly once an account is connected. Most creators see their first insights within 24 hours."

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.25),
                                Color.accentColor.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 132, height: 132)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("Connect an account to see insights")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button(action: onConnect) {
                Text("Connect an Account")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .accessibilityHint("Opens the Connected Accounts screen")

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }
}

#if DEBUG
#Preview("Analytics empty state") {
    ConnectAccountEmptyStateView(onConnect: {})
}
#endif
