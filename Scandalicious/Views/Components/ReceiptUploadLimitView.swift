//
//  ReceiptUploadLimitView.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 21/01/2026.
//

import SwiftUI

/// Displays the user's receipt upload limit status in the profile menu
struct ReceiptUploadLimitView: View {
    @ObservedObject var rateLimitManager: RateLimitManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Usage display
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .foregroundColor(statusColor)
                    .font(.system(size: 14))

                Text(rateLimitManager.receiptUsageDisplayString)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)

                    // Progress
                    RoundedRectangle(cornerRadius: 3)
                        .fill(progressColor)
                        .frame(width: max(0, geometry.size.width * (1 - rateLimitManager.receiptUsagePercentage)), height: 6)
                }
            }
            .frame(height: 6)

            // Reset info
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text(rateLimitManager.resetDaysFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Warning message when exhausted
            if rateLimitManager.receiptLimitState == .exhausted {
                Text("Upgrade for unlimited uploads")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch rateLimitManager.receiptLimitState {
        case .normal:
            return "doc.text.image"
        case .warning:
            return "exclamationmark.triangle"
        case .exhausted:
            return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch rateLimitManager.receiptLimitState {
        case .normal:
            return .green
        case .warning:
            return .orange
        case .exhausted:
            return .red
        }
    }

    private var progressColor: Color {
        switch rateLimitManager.receiptLimitState {
        case .normal:
            return .green
        case .warning:
            return .orange
        case .exhausted:
            return .red
        }
    }
}

/// Compact version for menu display - shows just the essential info
struct ReceiptUploadLimitMenuContent: View {
    @ObservedObject var rateLimitManager: RateLimitManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text("\(rateLimitManager.receiptsRemaining)/\(rateLimitManager.receiptsLimit) uploads")
            } icon: {
                Image(systemName: iconName)
                    .foregroundColor(statusColor)
            }

            if rateLimitManager.receiptLimitState == .exhausted {
                Text(rateLimitManager.resetDaysFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var iconName: String {
        switch rateLimitManager.receiptLimitState {
        case .normal:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .exhausted:
            return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch rateLimitManager.receiptLimitState {
        case .normal:
            return .green
        case .warning:
            return .orange
        case .exhausted:
            return .red
        }
    }
}

// MARK: - Previews

#Preview("Normal State") {
    ReceiptUploadLimitView(rateLimitManager: RateLimitManager.shared)
        .padding()
        .background(Color(.systemBackground))
}

#Preview("Menu Content") {
    Menu {
        Section("Receipt Uploads") {
            ReceiptUploadLimitMenuContent(rateLimitManager: RateLimitManager.shared)
        }
    } label: {
        Image(systemName: "person.circle.fill")
    }
    .padding()
}
