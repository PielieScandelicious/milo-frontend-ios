//
//  WithdrawalRow.swift
//  Scandalicious
//
//  One row in the wallet's withdrawal history list.
//

import SwiftUI

struct WithdrawalRow: View {
    let item: WithdrawalItemResponse

    private let cashbackGreen = Color(red: 0.25, green: 0.90, blue: 0.55)

    var body: some View {
        HStack(spacing: 12) {
            statusIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(MoneyFormatter.eur(item.amount))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("•••• \(item.ibanLast4)")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                statusPill
                Text(formattedDate)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.15))
                .frame(width: 36, height: 36)
            Image(systemName: statusSymbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(statusColor)
        }
    }

    private var statusPill: some View {
        Text(statusLabel)
            .font(.system(size: 10, weight: .heavy))
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundStyle(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(statusColor.opacity(0.12)))
    }

    private var statusLabel: String {
        switch item.status {
        case "paid_out": return "Paid"
        case "approved": return "Approved"
        case "auto_approved": return "Approved"
        case "pending_review": return "Pending"
        case "rejected": return "Rejected"
        default: return item.status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private var statusColor: Color {
        switch item.status {
        case "paid_out", "approved", "auto_approved": return cashbackGreen
        case "pending_review": return Color(red: 1.00, green: 0.70, blue: 0.20)
        case "rejected": return Color(red: 1.00, green: 0.40, blue: 0.40)
        default: return Color.white.opacity(0.5)
        }
    }

    private var statusSymbol: String {
        switch item.status {
        case "paid_out": return "checkmark.circle.fill"
        case "approved", "auto_approved": return "arrow.down.circle.fill"
        case "pending_review": return "hourglass"
        case "rejected": return "xmark.circle.fill"
        default: return "circle"
        }
    }

    private var formattedDate: String {
        let parsed = ISO8601DateFormatter().date(from: item.createdAt)
            ?? {
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return f.date(from: item.createdAt)
            }()
        guard let parsed else { return item.createdAt }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: parsed)
    }
}
