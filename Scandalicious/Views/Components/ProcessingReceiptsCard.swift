//
//  ProcessingReceiptsCard.swift
//  Scandalicious
//
//  Shows receipts being processed in the background with per-receipt status.
//  Lives at the top of the home tab's main content.
//

import SwiftUI

struct ProcessingReceiptsCard: View {
    @ObservedObject var manager: ReceiptProcessingManager

    var body: some View {
        if !manager.processingReceipts.isEmpty {
            VStack(spacing: 0) {
                // Header
                HStack {
                    headerIcon

                    Text(manager.hasActiveProcessing ? "Processing" : "Done")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    if !manager.hasActiveProcessing {
                        Button {
                            manager.dismissAll()
                        } label: {
                            Text("Clear")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

                // Receipt rows
                ForEach(manager.processingReceipts) { receipt in
                    ProcessingReceiptRow(
                        receipt: receipt,
                        onDismiss: { manager.dismiss(receipt.id) }
                    )
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
                }
            }
            .padding(.bottom, 10)
            .background(cardBackground)
            .overlay(cardBorder)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
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

    private var cardBorder: some View {
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

// MARK: - Processing Receipt Row

struct ProcessingReceiptRow: View {
    let receipt: ProcessingReceipt
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            statusIndicator

            VStack(alignment: .leading, spacing: 3) {
                Text(receipt.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                statusLabel
            }

            Spacer(minLength: 4)

            // Right side
            if receipt.isTerminal {
                if receipt.status == .completed || receipt.status == .success,
                   let amount = receipt.totalAmount {
                    Text(String(format: "\u{20AC}%.2f", amount))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.15))
                .frame(width: 32, height: 32)

            switch receipt.status {
            case .pending, .processing:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(0.7)
            case .completed, .success:
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.4))
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red)
            }
        }
    }

    private var statusColor: Color {
        switch receipt.status {
        case .pending, .processing: return .blue
        case .completed, .success: return Color(red: 0.2, green: 0.8, blue: 0.4)
        case .failed: return .red
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch receipt.status {
        case .pending:
            Text("Uploading...")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.blue.opacity(0.8))
        case .processing:
            Text("Processing...")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.blue.opacity(0.8))
        case .completed, .success:
            HStack(spacing: 4) {
                if let store = receipt.storeName {
                    Text(store.localizedCapitalized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                if receipt.itemsCount > 0 {
                    Text("\u{2022} \(receipt.itemsCount) items")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        case .failed:
            Text(receipt.errorMessage ?? "Processing failed")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.red.opacity(0.7))
                .lineLimit(1)
        }
    }
}
