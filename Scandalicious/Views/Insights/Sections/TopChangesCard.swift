//
//  TopChangesCard.swift
//  Scandalicious
//
//  Created by Claude on 23/02/2026.
//

import SwiftUI

struct TopChangesCard: View {
    @ObservedObject var viewModel: InsightsViewModel

    private var changes: [SpendingChange] {
        viewModel.topChanges
    }

    private var previousPeriodLabel: String {
        // Extract just the month name: "January 2026" -> "January"
        let full = viewModel.previousPeriod?.period ?? "last month"
        return full.split(separator: " ").first.map(String.init) ?? full
    }

    var body: some View {
        if changes.isEmpty {
            EmptyView()
        } else {
            InsightCardShell {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    Text("Changes from \(previousPeriodLabel)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)

                    // Change rows
                    VStack(spacing: 0) {
                        ForEach(changes) { change in
                            changeRow(change)

                            if change.id != changes.last?.id {
                                Divider()
                                    .background(Color.white.opacity(0.06))
                                    .padding(.leading, 52)
                            }
                        }
                    }
                }
            }
        }
    }

    private func changeRow(_ change: SpendingChange) -> some View {
        HStack(spacing: 14) {
            // Apple-style filled circle icon (using backend icon)
            ZStack {
                Circle()
                    .fill(change.color.gradient)
                    .frame(width: 36, height: 36)
                Image.categorySymbol(resolvedGroupIcon(change.icon))
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(change.categoryName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                Text(String(format: "%+.0f%%", change.percentageChange))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(change.isIncrease ? .red.opacity(0.7) : .green.opacity(0.7))
            }

            Spacer()

            // Change amount with directional arrow
            HStack(spacing: 4) {
                Image(systemName: change.isIncrease ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 12, weight: .bold))
                Text(String(format: "€%.0f", abs(change.absoluteChange)))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(change.isIncrease ? .red.opacity(0.85) : .green)
        }
        .padding(.vertical, 10)
    }

    private func resolvedGroupIcon(_ icon: String) -> String {
        switch icon {
        case "smoke.fill": return "cigarette"
        default: return icon
        }
    }
}
