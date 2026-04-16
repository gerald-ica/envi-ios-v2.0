//
//  InstagramAccountTypeErrorView.swift
//  ENVI
//
//  Phase 10 — Meta Family Connector, Instagram account-type error view.
//
//  Shown when `InstagramConnector.detectAccountType()` throws either
//  `.personalAccount` or `.noLinkedPage`. IG Content Publishing is only
//  available to Business or Creator accounts linked to a Facebook Page;
//  this view walks the user through fixing their setup and retrying.
//
//  Variants
//  --------
//  - `.personalAccount` — user has a personal IG account.
//    Help URL: https://help.instagram.com/502981923235522
//  - `.noLinkedPage` — user has a Pro account but no linked FB Page.
//    Help URL: https://help.instagram.com/176235449218188
//

import SwiftUI

/// Full-screen error view surfaced when the connected Instagram account
/// cannot use Content Publishing. The two variants carry different help
/// URLs + body copy; "Try a Different Account" retriggers the OAuth flow
/// so the user doesn't have to hunt for the connect button again.
struct InstagramAccountTypeErrorView: View {

    // MARK: - Variant

    /// Which error triggered this view. Drives title / body / help URL.
    enum Variant {
        case personalAccount
        case noLinkedPage

        var title: String {
            switch self {
            case .personalAccount:
                return "Professional Instagram Account Required"
            case .noLinkedPage:
                return "Link Your Instagram to a Facebook Page"
            }
        }

        var message: String {
            switch self {
            case .personalAccount:
                return "To publish from ENVI, Instagram needs a Business or Creator account. You can switch inside Instagram's settings — your posts and followers stay the same."
            case .noLinkedPage:
                return "Instagram requires your Business or Creator account to be linked to a Facebook Page before ENVI can publish on your behalf."
            }
        }

        var actionTitle: String {
            switch self {
            case .personalAccount: return "Learn How to Switch"
            case .noLinkedPage:    return "Learn How to Link"
            }
        }

        var helpURL: URL {
            switch self {
            case .personalAccount:
                return URL(string: "https://help.instagram.com/502981923235522")!
            case .noLinkedPage:
                return URL(string: "https://help.instagram.com/176235449218188")!
            }
        }

        var iconSystemName: String {
            switch self {
            case .personalAccount: return "person.crop.circle.badge.exclamationmark"
            case .noLinkedPage:    return "link.badge.plus"
            }
        }
    }

    // MARK: - Dependencies

    let variant: Variant

    /// Invoked when the user taps "Try a Different Account" — caller
    /// typically disconnects the current session + retriggers OAuth.
    let onRetry: () -> Void

    /// Invoked when the user bails out — caller dismisses back to the
    /// Connect sheet.
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    var body: some View {
        VStack(spacing: ENVISpacing.xl) {
            Spacer()

            // Icon
            Image(systemName: variant.iconSystemName)
                .font(.system(size: 56, weight: .regular))
                .foregroundColor(ENVITheme.primary(for: colorScheme))

            // Title + message
            VStack(spacing: ENVISpacing.sm) {
                Text(variant.title)
                    .font(.spaceMonoBold(18))
                    .multilineTextAlignment(.center)
                    .foregroundColor(ENVITheme.text(for: colorScheme))

                Text(variant.message)
                    .font(.spaceMono(13))
                    .multilineTextAlignment(.center)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, ENVISpacing.lg)

            Spacer()

            // Actions
            VStack(spacing: ENVISpacing.sm) {
                Link(destination: variant.helpURL) {
                    HStack(spacing: ENVISpacing.xs) {
                        Text(variant.actionTitle)
                            .font(.spaceMonoBold(14))
                            .tracking(0.5)
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ENVISpacing.md)
                    .background(ENVITheme.primary(for: colorScheme))
                    .foregroundColor(ENVITheme.background(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                }

                Button {
                    onRetry()
                } label: {
                    Text("Try a Different Account")
                        .font(.spaceMonoBold(13))
                        .tracking(0.5)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ENVISpacing.md)
                        .background(ENVITheme.surfaceLow(for: colorScheme))
                        .foregroundColor(ENVITheme.text(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: ENVIRadius.lg)
                                .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                        )
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Not Now")
                        .font(.spaceMono(12))
                        .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                        .padding(.vertical, ENVISpacing.sm)
                }
            }
            .padding(.horizontal, ENVISpacing.lg)
            .padding(.bottom, ENVISpacing.lg)
        }
        .background(ENVITheme.background(for: colorScheme).ignoresSafeArea())
    }
}

#Preview("Personal Account") {
    InstagramAccountTypeErrorView(
        variant: .personalAccount,
        onRetry: {},
        onDismiss: {}
    )
}

#Preview("No Linked Page") {
    InstagramAccountTypeErrorView(
        variant: .noLinkedPage,
        onRetry: {},
        onDismiss: {}
    )
}
