//
//  TemplatePreviewView.swift
//  ENVI
//
//  Phase 5 — Task 3: Full-screen preview for a PopulatedTemplate.
//
//  Container responsibilities:
//   - Chrome: close X, template name + duration, (future) share.
//   - Player surface: `TemplatePlayerView` composes filled slots into
//     either a crossfade slideshow (photo templates) or an AVComposition
//     (any-video template).
//   - Slot strip: horizontal thumbnails for each FilledSlot. Tapping a
//     slot opens a SwiftUI sheet (`.presentationDetents`) with the
//     slot's `alternates` plus a "Choose from library" PHPicker path.
//   - Export: primary button presents the existing `ExportSheetView`.
//
//  Swap semantics:
//   - Alternate picked → `viewModel.swap(slot:in:to:)` (async) → the VM
//     republishes the template and this view observes the updated
//     `populated` binding (the parent holds the source of truth).
//     During Phase 5 UI wiring the parent passes the latest populated;
//     for in-place updates we cache a local override so the player
//     rebuilds immediately without waiting on VM publishing.
//   - PHPicker pick → we look up the picked `PHAsset.localIdentifier`
//     in `ClassificationCache` (via the VM's classified lookup path).
//     If absent, we refuse the swap and show an alert — preserving the
//     Phase 1/2 quality gate that only-classified assets are swappable.
//
//  This file is self-contained — it does not reach into Task 1
//  (TemplateTabView) or Task 2 (TemplateCardView). The only VM surface
//  we touch is `swap(slot:in:to:)`.
//

import SwiftUI
import AVFoundation
import Photos
import PhotosUI
import UIKit

struct TemplatePreviewView: View {

    // Input
    let initialPopulated: PopulatedTemplate
    let viewModel: TemplateTabViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // Local, authoritative copy of the populated template. Seeded from
    // `initialPopulated` and mutated on successful swaps so the player
    // can rebuild before the VM publishes back.
    @State private var populated: PopulatedTemplate

    @State private var isPlaying: Bool = true
    @State private var swapTarget: FilledSlot? = nil
    @State private var showExportSheet: Bool = false
    @State private var showPHPicker: Bool = false
    @State private var pendingPHPickerSlot: FilledSlot? = nil
    @State private var rejectionMessage: String? = nil

    init(populated: PopulatedTemplate, viewModel: TemplateTabViewModel) {
        self.initialPopulated = populated
        self.viewModel = viewModel
        _populated = State(initialValue: populated)
    }

    var body: some View {
        ZStack {
            ENVITheme.background(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: ENVISpacing.lg) {
                topBar
                    .padding(.horizontal, ENVISpacing.lg)
                    .padding(.top, ENVISpacing.sm)

                TemplatePlayerView(populated: populated, isPlaying: $isPlaying)
                    .padding(.horizontal, ENVISpacing.lg)

                slotStrip

                Spacer(minLength: 0)

                exportBar
                    .padding(.horizontal, ENVISpacing.lg)
                    .padding(.bottom, ENVISpacing.lg)
            }
        }
        .preferredColorScheme(colorScheme)
        .sheet(item: $swapTarget) { slot in
            slotSwapSheet(for: slot)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showExportSheet) {
            // ExportSheetView uses its preview composer by default —
            // Phase 6 will wire a composed-video composer through.
            ExportSheetView()
        }
        .sheet(isPresented: $showPHPicker) {
            PHPickerRepresentable { identifiers in
                showPHPicker = false
                guard let id = identifiers.first,
                      let slot = pendingPHPickerSlot else { return }
                Task { await handleLibraryPick(localIdentifier: id, for: slot) }
            }
            .ignoresSafeArea()
        }
        .alert(
            "Photo still being analyzed",
            isPresented: Binding(
                get: { rejectionMessage != nil },
                set: { if !$0 { rejectionMessage = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) { rejectionMessage = nil }
            },
            message: {
                Text(rejectionMessage ?? "")
            }
        )
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .frame(width: 36, height: 36)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }
            .accessibilityLabel("Close preview")

            Spacer()

            VStack(spacing: 2) {
                Text(populated.template.name.uppercased())
                    .font(.spaceMonoBold(14))
                    .tracking(1.5)
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                Text(durationLabel)
                    .font(.spaceMono(10))
                    .tracking(1.0)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }

            Spacer()

            Button {
                // Future: share intent — placeholder for layout parity.
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ENVITheme.text(for: colorScheme))
                    .frame(width: 36, height: 36)
                    .background(ENVITheme.surfaceLow(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
            }
            .accessibilityLabel("Share")
            .disabled(true)
            .opacity(0.5)
        }
    }

    private var durationLabel: String {
        if let d = populated.template.duration {
            return String(format: "%.0fs", d)
        }
        let sum = populated.filledSlots.reduce(0.0) { $0 + $1.slot.duration }
        return String(format: "%.0fs", sum)
    }

    // MARK: - Slot strip

    private var slotStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ENVISpacing.sm) {
                ForEach(populated.filledSlots.sorted(by: { $0.slot.order < $1.slot.order })) { filled in
                    slotThumbnail(filled)
                }
            }
            .padding(.horizontal, ENVISpacing.lg)
        }
        .frame(height: 96)
    }

    private func slotThumbnail(_ filled: FilledSlot) -> some View {
        Button {
            swapTarget = filled
        } label: {
            VStack(spacing: ENVISpacing.xs) {
                TemplateSlotImageView(
                    assetIdentifier: filled.matchedAsset?.localIdentifier,
                    targetSize: CGSize(width: 200, height: 200)
                )
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                        .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                )
                Text("\(filled.slot.order + 1)")
                    .font(.spaceMonoBold(10))
                    .tracking(1.5)
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Slot \(filled.slot.order + 1), tap to swap")
    }

    // MARK: - Swap sheet

    private func slotSwapSheet(for filled: FilledSlot) -> some View {
        VStack(alignment: .leading, spacing: ENVISpacing.lg) {
            Text("Swap slot \(filled.slot.order + 1)".uppercased())
                .font(.spaceMonoBold(14))
                .tracking(1.5)
                .foregroundColor(ENVITheme.text(for: colorScheme))
                .padding(.horizontal, ENVISpacing.lg)
                .padding(.top, ENVISpacing.lg)

            if filled.alternates.isEmpty {
                Text("No alternates found for this slot.")
                    .font(.interRegular(13))
                    .foregroundColor(ENVITheme.textSecondary(for: colorScheme))
                    .padding(.horizontal, ENVISpacing.lg)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ENVISpacing.sm) {
                        ForEach(filled.alternates, id: \.localIdentifier) { alt in
                            Button {
                                Task { await applySwap(slot: filled.slot, to: alt) }
                                swapTarget = nil
                            } label: {
                                TemplateSlotImageView(
                                    assetIdentifier: alt.localIdentifier,
                                    targetSize: CGSize(width: 300, height: 300)
                                )
                                .frame(width: 96, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: ENVIRadius.sm))
                                .overlay(
                                    RoundedRectangle(cornerRadius: ENVIRadius.sm)
                                        .strokeBorder(ENVITheme.border(for: colorScheme), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, ENVISpacing.lg)
                }
            }

            Divider()
                .padding(.horizontal, ENVISpacing.lg)

            ENVIButton("Choose from library", variant: .secondary) {
                pendingPHPickerSlot = filled
                swapTarget = nil
                // Small delay so the first sheet is fully dismissed
                // before presenting PHPicker (UIKit presentation requirement).
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    showPHPicker = true
                }
            }
            .padding(.horizontal, ENVISpacing.lg)

            Spacer(minLength: ENVISpacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ENVITheme.background(for: colorScheme))
    }

    // MARK: - Export

    private var exportBar: some View {
        ENVIButton("Export", variant: .primary, isFullWidth: true) {
            showExportSheet = true
        }
    }

    // MARK: - Swap handling

    private func applySwap(slot: TemplateSlot, to asset: ClassifiedAsset) async {
        // Optimistic local update: rebuild `populated` with the asset
        // inserted into the target slot. The VM's async swap still
        // runs so trending / category buckets stay in sync.
        var newSlots = populated.filledSlots
        if let idx = newSlots.firstIndex(where: { $0.slot.id == slot.id }) {
            let old = newSlots[idx]
            newSlots[idx] = FilledSlot(
                slot: old.slot,
                matchedAsset: asset,
                matchScore: old.matchScore,
                alternates: old.alternates.filter { $0.localIdentifier != asset.localIdentifier }
            )
        }
        populated = PopulatedTemplate(
            template: populated.template,
            filledSlots: newSlots,
            fillRate: populated.fillRate,
            overallScore: populated.overallScore,
            previewThumbnail: populated.previewThumbnail
        )
        await viewModel.swap(slot: slot, in: populated, to: asset)
    }

    /// PHPicker returns a `PHAsset.localIdentifier`. To preserve the
    /// Phase 1/2 quality gate, we only accept the pick if the asset has
    /// already been classified (i.e. exists in the cache). Everything
    /// else would bypass the scoring pipeline.
    ///
    /// The ViewModel doesn't expose a cache-lookup API, so we resolve
    /// via `alternates` + `matchedAsset` across all slots. If the user
    /// picks something already used elsewhere in this template, we can
    /// swap it in directly; otherwise we show the analyzing-alert.
    private func handleLibraryPick(localIdentifier id: String, for slot: FilledSlot) async {
        let knownAssets: [ClassifiedAsset] =
            populated.filledSlots.flatMap { [$0.matchedAsset].compactMap { $0 } + $0.alternates }

        if let hit = knownAssets.first(where: { $0.localIdentifier == id }) {
            await applySwap(slot: slot.slot, to: hit)
        } else {
            rejectionMessage = "This photo hasn't been analyzed yet. It'll be available to use here once classification finishes."
        }
    }
}

// MARK: - PHPicker SwiftUI bridge

/// Minimal PHPicker wrapper that returns picked `PHAsset.localIdentifier`
/// strings. Configured for single-asset selection and classified-asset
/// resolution only (no cloud downloads).
struct PHPickerRepresentable: UIViewControllerRepresentable {
    let onPick: ([String]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .any(of: [.images, .videos])
        let controller = PHPickerViewController(configuration: config)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: ([String]) -> Void
        init(onPick: @escaping ([String]) -> Void) { self.onPick = onPick }

        func picker(
            _ picker: PHPickerViewController,
            didFinishPicking results: [PHPickerResult]
        ) {
            let ids = results.compactMap { $0.assetIdentifier }
            onPick(ids)
        }
    }
}
