//
//  TopChangesCard.swift
//  Scandalicious
//
//  Created by Claude on 23/02/2026.
//

import SwiftUI

struct TopChangesCard: View {
    @ObservedObject var viewModel: InsightsViewModel
    @State private var showAll = false

    private var changes: [SpendingChange] {
        showAll ? viewModel.allChanges : viewModel.topChanges
    }

    private var hasMore: Bool {
        viewModel.allChanges.count > viewModel.topChanges.count
    }

    private var previousPeriodLabel: String {
        let full = viewModel.previousPeriod?.period ?? "last month"
        return full.split(separator: " ").first.map(String.init) ?? full
    }

    var body: some View {
        if viewModel.topChanges.isEmpty {
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

                    if hasMore {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showAll.toggle()
                            }
                        } label: {
                            Text(showAll ? "Show Less" : "Show All")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.blue)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func changeRow(_ change: SpendingChange) -> some View {
        HStack(spacing: 14) {
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
