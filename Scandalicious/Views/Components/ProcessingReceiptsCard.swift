//
//  ProcessingReceiptsCard.swift
//  Scandalicious
//
//  Shows receipts being processed in the background with per-receipt status.
//  The backend processes 2 receipts concurrently; queued receipts show position.
//

import SwiftUI
import Combine

struct ProcessingReceiptsCard: View {
    @ObservedObject var manager: ReceiptProcessingManager
    let onClaimReceipt: (ProcessingReceipt) -> Void

    private var activeCount: Int {
        manager.processingReceipts.filter { !$0.isTerminal }.count
    }
    private var completedReceipts: [ProcessingReceipt] {
        manager.processingReceipts.filter { $0.status == .completed || $0.status == .success }
    }
    private var allDone: Bool {
        !manager.hasActiveProcessing && !completedReceipts.isEmpty
    }

    var body: some View {
        if !manager.processingReceipts.isEmpty {
            VStack(spacing: 0) {
                headerSection
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                // Receipt rows
                ForEach(manager.processingReceipts) { receipt in
                    ProcessingReceiptRow(
                        receipt: receipt,
                        queuePosition: queuePosition(for: receipt),
                        onDismiss: { manager.dismiss(receipt.id) },
                        onClaim: { onClaimReceipt(receipt) }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
                }

                // Play hint
                if manager.hasActiveProcessing {
                    HStack(spacing: 6) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 11, weight: .medium))
                        Text("Tap Milo to play while you wait")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
                }
            }
            .padding(.bottom, manager.hasActiveProcessing ? 0 : 12)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: allDone ? .green.opacity(0.15) : .clear, radius: 12, y: 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(borderGradient, lineWidth: allDone ? 1 : 0.5)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: allDone)
            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(headerIconBackground)
                    .frame(width: 32, height: 32)

                if allDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: allDone)
                } else {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.blue)
                        .symbolEffect(.pulse, isActive: manager.hasActiveProcessing)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(headerTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                if !allDone && manager.processingReceipts.count > 1 {
                    Text("\(activeCount) remaining")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Batch counter pill
            if manager.processingReceipts.count > 1 {
                Text("\(manager.processingReceipts.count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.quaternary))
            }
        }
    }

    private var headerTitle: String {
        if allDone {
            return completedReceipts.count == 1 ? "Receipt processed" : "All receipts processed"
        }
        if manager.processingReceipts.count == 1 {
            return "Processing receipt…"
        }
        return "Processing receipts…"
    }

    private var headerIconBackground: Color {
        if allDone { return .green.opacity(0.12) }
        return .blue.opacity(0.12)
    }

    private var borderGradient: LinearGradient {
        if allDone {
            return LinearGradient(
                colors: [.green.opacity(0.4), .green.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [Color.primary.opacity(0.1), Color.primary.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func queuePosition(for receipt: ProcessingReceipt) -> Int? {
        guard receipt.isQueued else { return nil }
        let queued = manager.processingReceipts.filter { $0.isQueued }
        guard let idx = queued.firstIndex(where: { $0.id == receipt.id }) else { return nil }
        return idx + 1
    }
}

// MARK: - Processing Receipt Row

struct ProcessingReceiptRow: View {
    let receipt: ProcessingReceipt
    let queuePosition: Int?
    let onDismiss: () -> Void
    let onClaim: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                statusIcon
                receiptInfo
                Spacer(minLength: 4)
                trailingContent
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if receipt.isActivelyProcessing {
                ReceiptProgressBar(processingStartedAt: receipt.processingStartedAt)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if receipt.status == .completed || receipt.status == .success {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onDismiss()
            }
        }
    }

    // MARK: - Status Icon

    @ViewBuilder
    private var statusIcon: some View {
        ZStack {
            if receipt.isTerminal {
                if receipt.status == .failed {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.red)
                        .symbolEffect(.bounce, value: receipt.status)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: receipt.status)
                }
            } else if receipt.isActivelyProcessing {
                ProgressView()
                    .controlSize(.small)
                    .tint(.blue)
            } else {
                // Queued — show position number
                ZStack {
                    Circle()
                        .fill(.quaternary)
                        .frame(width: 26, height: 26)
                    Text("\(queuePosition ?? 0)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(width: 28, height: 28)
    }

    // MARK: - Receipt Info

    private var receiptInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(receipt.displayName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            statusSubtitle
        }
    }

    @ViewBuilder
    private var statusSubtitle: some View {
        if receipt.status == .failed {
            Text(receipt.errorMessage ?? "Processing failed")
                .font(.system(size: 13))
                .foregroundStyle(.red)
                .lineLimit(1)
        } else if receipt.isTerminal {
            if let dateStr = receipt.formattedDate {
                Text(dateStr)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        } else if receipt.isActivelyProcessing {
            Text("Scanning items…")
                .font(.system(size: 13))
                .foregroundStyle(.blue)
        } else {
            Text("Waiting in queue")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Trailing Content

    @ViewBuilder
    private var trailingContent: some View {
        if receipt.status == .completed || receipt.status == .success {
            HStack(spacing: 10) {
                if let amount = receipt.totalAmount {
                    Text(String(format: "€%.2f", amount))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                }

                dismissButton
            }
        } else if receipt.status == .failed {
            dismissButton
        }
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.quaternary))
        }
    }
}

// MARK: - Per-Receipt Progress Bar

private struct ReceiptProgressBar: View {
    let processingStartedAt: Date?

    private let processingDuration: Double = 23.0

    @State private var progress: Double = 0

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(.quaternary)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .indigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(2, geo.size.width * progress))
                }
                .clipShape(Capsule())
        }
        .frame(height: 4)
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
