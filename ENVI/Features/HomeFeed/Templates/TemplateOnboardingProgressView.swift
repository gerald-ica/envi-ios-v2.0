//
//  TemplateOnboardingProgressView.swift
//  ENVI
//
//  Phase 5 — Task 4: Onboarding progress UI shown immediately after the
//  user grants full Photos access. Runs `MediaScanCoordinator.scanOnboardingBatch()`
//  on the most recent 500 assets, surfaces a progress ring + thumbnail
//  mosaic of recently-classified photos, and lets the user tap "Skip" to
//  continue onboarding while the remainder of the library finishes
//  classifying in the background via `scheduleBackgroundScan()`.
//
//  Auto-advances when the scan phase transitions to `.completed` /
//  `.idle` (success) by calling `onContinue`.
//

import SwiftUI
import Photos
import UIKit
import Combine

struct TemplateOnboardingProgressView: View {

    // MARK: - Dependencies

    @ObservedObject var scanner: MediaScanCoordinator
    let onContinue: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Local state

    @State private var hasStartedScan: Bool = false
    @State private var recentThumbnails: [UIImage] = []
    @State private var thumbnailTick: Int = 0
    @State private var hasContinued: Bool = false

    /// 1Hz mosaic refresh. We read cached local identifiers on tick, so
    /// the grid reflects whatever Task 5's classifier has written so far
    /// without moving SwiftData model instances across actor boundaries.
    private let mosaicTimer = Timer
        .publish(every: 1.0, on: .main, in: .common)
        .autoconnect()

    // MARK: - Derived

    private var fractionComplete: Double {
        let total = scanner.progress.total
        guard total > 0 else { return 0 }
        return min(1.0, Double(scanner.progress.completed) / Double(total))
    }

    private var statusLabel: String {
        let progress = scanner.progress
        switch progress.phase {
        case .completed, .idle:
            return "Done"
        default:
            if progress.total > 0 {
                return "\(progress.completed) / \(progress.total)"
            }
            return "Starting…"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: ENVISpacing.xxl) {
            header

            Spacer(minLength: 0)

            ENVIProgressRing(progress: fractionComplete, size: 140)

            Text(statusLabel)
                .font(.spaceMono(11))
                .tracking(1.5)
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))

            thumbnailMosaic

            Spacer(minLength: 0)

            skipButton
        }
        .padding(.horizontal, ENVISpacing.xl)
        .padding(.vertical, ENVISpacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ENVITheme.background(for: colorScheme).ignoresSafeArea())
        .onAppear {
            startScanIfNeeded()
            Task { await refreshThumbnails() }
        }
        .onReceive(mosaicTimer) { _ in
            thumbnailTick &+= 1
            Task { await refreshThumbnails() }
        }
        .onChange(of: scanner.progress.phase) { _, newPhase in
            handlePhaseChange(newPhase)
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: ENVISpacing.sm) {
            Text("Analyzing your content")
                .font(.interSemiBold(28))
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("We're finding templates that fit your recent photos and videos")
                .font(.interRegular(15))
                .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var thumbnailMosaic: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: ENVISpacing.xs),
            count: 3
        )
        return LazyVGrid(columns: columns, spacing: ENVISpacing.xs) {
            ForEach(0..<9, id: \.self) { index in
                mosaicCell(at: index)
            }
        }
        .frame(maxWidth: 240)
    }

    @ViewBuilder
    private func mosaicCell(at index: Int) -> some View {
        let image = index < recentThumbnails.count ? recentThumbnails[index] : nil
        ZStack {
            RoundedRectangle(cornerRadius: ENVIRadius.sm)
                .fill(ENVITheme.surfaceLow(for: colorScheme))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
        .animation(.easeInOut(duration: 0.3), value: image != nil)
    }

    private var skipButton: some View {
        ENVIButton("Skip", variant: .secondary) {
            scanner.scheduleBackgroundScan()
            continueOnce()
        }
    }

    // MARK: - Logic

    private func startScanIfNeeded() {
        guard !hasStartedScan else { return }
        hasStartedScan = true
        switch scanner.progress.phase {
        case .onboarding, .background, .lazy, .incremental:
            return  // already running
        default:
            break
        }
        Task {
            _ = await scanner.scanOnboardingBatch()
        }
    }

    private func handlePhaseChange(_ phase: MediaScanProgress.Phase) {
        switch phase {
        case .completed, .idle:
            // Only auto-advance if we actually ran a scan and hit the end.
            if hasStartedScan {
                continueOnce()
            }
        default:
            break
        }
    }

    private func continueOnce() {
        guard !hasContinued else { return }
        hasContinued = true
        onContinue()
    }

    // MARK: - Thumbnails

    /// Reads the most recently-classified assets from the shared
    /// `ClassificationCache` and turns their local identifiers into
    /// 80x80 UIImages for the mosaic.
    private func refreshThumbnails() async {
        guard let cache = try? ClassificationCache() else { return }
        let identifiers: [String]
        do {
            let allIdentifiers = try await cache.fetchAllLocalIdentifiers()
            identifiers = Array(allIdentifiers.suffix(9))
        } catch {
            return
        }
        guard !identifiers.isEmpty else { return }

        let size = CGSize(width: 160, height: 160)
        var images: [UIImage] = []
        for id in identifiers {
            if let image = await AssetThumbnailLoader.shared.thumbnail(for: id, size: size) {
                images.append(image)
            }
        }
        await MainActor.run {
            self.recentThumbnails = images
        }
    }
}
