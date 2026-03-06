//
//  ProcessingReceiptsCard.swift
//  Scandalicious
//
//  Shows receipts being processed in the background with per-receipt status
//  and progress bars. The backend processes 2 receipts concurrently; queued
//  receipts show an "In queue" label with no progress movement.
//

import SwiftUI
import Combine

struct ProcessingReceiptsCard: View {
    @ObservedObject var manager: ReceiptProcessingManager
    let onClaimReceipt: (ProcessingReceipt) -> Void

    var body: some View {
        if !manager.processingReceipts.isEmpty {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 8) {
                    headerIcon

                    Text(headerTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    if manager.processingReceipts.count > 1 {
                        Text("\(manager.processingReceipts.count) receipts")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.35))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.06)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

                // Receipt rows
                ForEach(manager.processingReceipts) { receipt in
                    ProcessingReceiptRow(
                        receipt: receipt,
                        onDismiss: { manager.dismiss(receipt.id) },
                        onClaim: { onClaimReceipt(receipt) }
                    )
                    .transition(.asymmetric(
                        insertion: .push(from: .bottom).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
                }

                // "Tap Milo to play while you wait" hint when actively processing
                if manager.hasActiveProcessing {
                    HStack(spacing: 5) {
                        Text("Tap Milo to play while you wait")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.35))

                        Image(systemName: "arrow.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 10)
                }
            }
            .padding(.bottom, manager.hasActiveProcessing ? 0 : 10)
            .background(cardBackground)
            .overlay(completedBorder)
            .overlay(defaultBorder)
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        }
    }

    private var headerTitle: String {
        let active = manager.processingReceipts.filter { !$0.isTerminal }
        let completed = manager.processingReceipts.filter { $0.status == .completed || $0.status == .success }
        if active.isEmpty && !completed.isEmpty {
            return completed.count == 1 ? "Your reward is ready!" : "Your rewards are ready!"
        }
        if manager.processingReceipts.count == 1 {
            return "Processing your receipt..."
        }
        return "Processing receipts"
    }

    @ViewBuilder
    private var headerIcon: some View {
        if manager.hasActiveProcessing {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.blue)
                .symbolEffect(.rotate, isActive: true)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.4))
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(white: 0.08))
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // Green glow border when all are done
    @ViewBuilder
    private var completedBorder: some View {
        let allDone = !manager.hasActiveProcessing
            && manager.processingReceipts.contains(where: { $0.status == .completed || $0.status == .success })
        if allDone {
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.8, blue: 0.4).opacity(0.25),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    // Subtle default border
    @ViewBuilder
    private var defaultBorder: some View {
        let allDone = !manager.hasActiveProcessing
            && manager.processingReceipts.contains(where: { $0.status == .completed || $0.status == .success })
        if !allDone {
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
    }
}

// MARK: - Processing Receipt Row

struct ProcessingReceiptRow: View {
    let receipt: ProcessingReceipt
    let onDismiss: () -> Void
    let onClaim: () -> Void

    private let successGreen = Color(red: 0.2, green: 0.8, blue: 0.4)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                statusIndicator

                VStack(alignment: .leading, spacing: 3) {
                    Text(receipt.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                    statusLabel
                }

                Spacer(minLength: 4)

                rightContent
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Per-receipt progress bar — only when actively being processed
            if receipt.isActivelyProcessing {
                ReceiptProgressBar(processingStartedAt: receipt.processingStartedAt)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if receipt.status == .completed || receipt.status == .success {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onClaim()
            }
        }
    }

    @ViewBuilder
    private var rightContent: some View {
        if receipt.status == .completed || receipt.status == .success {
            HStack(spacing: 8) {
                if let amount = receipt.totalAmount {
                    Text(String(format: "\u{20AC}%.2f", amount))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(successGreen.opacity(0.6))
            }
        } else if receipt.status == .failed {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
        }
    }

    /// Use processingStartedAt as source of truth — the backend reports .processing
    /// for ALL receipts including queued ones, so we can't rely on status alone.
    private var isActiveOrProcessing: Bool {
        receipt.processingStartedAt != nil && !receipt.isTerminal
    }

    private var isQueued: Bool {
        receipt.processingStartedAt == nil && !receipt.isTerminal
    }

    @ViewBuilder
    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.15))
                .frame(width: 32, height: 32)

            if receipt.isTerminal {
                if receipt.status == .failed {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(successGreen)
                }
            } else if isActiveOrProcessing {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.blue)
                    .symbolEffect(.rotate, isActive: true)
            } else {
                // Queued
                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private var statusColor: Color {
        if receipt.isTerminal {
            return receipt.status == .failed ? .red : Color(red: 0.2, green: 0.8, blue: 0.4)
        }
        return isActiveOrProcessing ? .blue : Color.white.opacity(0.2)
    }

    @ViewBuilder
    private var statusLabel: some View {
        if receipt.isTerminal {
            if receipt.status == .failed {
                Text(receipt.errorMessage ?? "Processing failed")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red.opacity(0.7))
                    .lineLimit(1)
            } else {
                HStack(spacing: 4) {
                    Text("Tap to claim")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.4).opacity(0.8))
                    if let dateStr = receipt.formattedDate {
                        Text("\u{2022} \(dateStr)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
        } else if isActiveOrProcessing {
            Text("Processing...")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.blue.opacity(0.8))
        } else {
            Text("In queue")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))
        }
    }
}

// MARK: - Per-Receipt Progress Bar

/// Animated progress bar using a quadratic-exponential curve.
/// Only rendered when receipt is actively being processed.
private struct ReceiptProgressBar: View {
    let processingStartedAt: Date?

    private let processingDuration: Double = 23.0

    @State private var progress: Double = 0

    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.06))
            .frame(height: 3)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.3, green: 0.7, blue: 1.0),
                                Color(red: 0.45, green: 0.15, blue: 0.85)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(
                        x: max(0.01, progress),
                        y: 1,
                        anchor: .leading
                    )
            }
            .clipShape(Capsule())
            .onAppear { updateProgress() }
            .onReceive(Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()) { _ in
                updateProgress()
            }
    }

    private func updateProgress() {
        guard let start = processingStartedAt else {
            progress = 0
            return
        }
        let elapsed = Date().timeIntervalSince(start)
        let k = 2.303 / (processingDuration * processingDuration)
        withAnimation(.linear(duration: 0.15)) {
            progress = 1.0 - exp(-k * elapsed * elapsed)
        }
    }
}
