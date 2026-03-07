//
//  WithdrawalHistoryView.swift
//  Scandalicious
//

import SwiftUI

struct WithdrawalHistoryView: View {
    @ObservedObject private var gm = GamificationManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()

                if gm.withdrawalHistory.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "banknote")
                            .font(.system(size: 36))
                            .foregroundStyle(.white.opacity(0.2))
                        Text("No withdrawals yet")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(gm.withdrawalHistory) { withdrawal in
                                WithdrawalHistoryRow(withdrawal: withdrawal)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Withdrawal History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .onAppear {
                gm.fetchWithdrawalHistory()
            }
        }
    }
}

// MARK: - History Row

private struct WithdrawalHistoryRow: View {
    let withdrawal: WithdrawalItemResponse

    private var statusColor: Color {
        switch withdrawal.status {
        case "paid_out": return Color(red: 0.2, green: 0.8, blue: 0.4)
        case "rejected": return .red
        case "pending_review": return .orange
        case "auto_approved", "approved": return Color(red: 0.3, green: 0.7, blue: 1.0)
        default: return .gray
        }
    }

    private var statusLabel: String {
        switch withdrawal.status {
        case "paid_out": return "Paid Out"
        case "rejected": return "Rejected"
        case "pending_review": return "Under Review"
        case "auto_approved": return "Approved"
        case "approved": return "Approved"
        default: return withdrawal.status
        }
    }

    private var formattedDate: String {
        // Parse ISO date string
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: withdrawal.createdAt) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .none
            return display.string(from: date)
        }
        // Fallback: try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: withdrawal.createdAt) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .none
            return display.string(from: date)
        }
        return withdrawal.createdAt
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(String(format: "€%.2f", withdrawal.amount))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("****\(withdrawal.ibanLast4)")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Text(formattedDate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()

                // Status pill
                Text(statusLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(statusColor.opacity(0.15))
                    )
            }

            // Rejection reason
            if withdrawal.status == "rejected", let notes = withdrawal.adminNotes {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red.opacity(0.7))
                    Text(notes)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }
}
