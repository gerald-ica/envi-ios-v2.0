//
//  TikTokSandboxErrorView.swift
//  ENVI
//
//  Phase 08 — TikTok Sandbox Connector (v1.1 Real Social Connectors).
//
//  Presented as a sheet when `TikTokConnector.connect()` throws
//  `.sandboxUserNotAllowed`. Only surfaces in `staging` builds — the
//  sandbox allowlist no longer applies once the app is approved for
//  production TikTok access.
//
//  Copy lives here so Phase 11 (localization sweep) can migrate the
//  strings into the catalog without touching the connector layer.
//

import SwiftUI

/// Modal that explains why a tester's TikTok account couldn't connect and
/// offers a mailto: link to the support alias.
///
/// Designed to be instantiated from a `.sheet` modifier. Caller owns
/// presentation state; view dismisses itself via the injected environment
/// `dismiss` action on close / CTA tap.
struct TikTokSandboxErrorView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    /// Email address the support CTA targets. Matches the brand alias used
    /// elsewhere in the app (`gerald@weareinformal.com` / `support@...`).
    static let supportMailto = URL(
        string: "mailto:support@weareinformal.com?subject=TikTok%20Sandbox%20Access"
    )!

    var body: some View {
        ZStack {
            // Glass morphism backdrop for a premium sheet feel — consistent
            // with the rest of v1.1's modal sheets (Feed Detail, Paywall).
            ENVITheme.background(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 16)

                // MARK: - Icon

                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 96, height: 96)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                }
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

                // MARK: - Copy

                VStack(spacing: 12) {
                    Text("TikTok account not approved")
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(ENVITheme.text(for: colorScheme))

                    Text(
                        "Your TikTok account isn't yet approved for our sandbox. "
                        + "Contact support and we'll add you as a tester so you can connect."
                    )
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ENVITheme.textSecondary(for: colorScheme))
                    .padding(.horizontal, 24)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                // MARK: - CTAs

                VStack(spacing: 12) {
                    Button {
                        openURL(Self.supportMailto)
                        dismiss()
                    } label: {
                        Text("Contact Support")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(
                                LinearGradient(
                                    colors: [Color.accentColor, Color.accentColor.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .accessibilityIdentifier("tiktok_sandbox_contact_support")

                    Button("Close") {
                        dismiss()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ENVITheme.textSecondary(for: colorScheme))
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("tiktok_sandbox_close")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .padding(.top, 32)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview("TikTok Sandbox Not Allowed") {
    Color.black
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            TikTokSandboxErrorView()
        }
}
#endif
