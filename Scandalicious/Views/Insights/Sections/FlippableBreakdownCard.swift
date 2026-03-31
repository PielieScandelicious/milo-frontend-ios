//
//  FlippableBreakdownCard.swift
//  Scandalicious
//
//  Created by Claude on 23/02/2026.
//

import SwiftUI

struct FlippableBreakdownCard: View {
    @ObservedObject var viewModel: InsightsViewModel
    @State private var isShowingCategories = true
    @State private var flipDegrees: Double = 180
    @State private var showAllRows = false

    private var groups: [PieChartGroup] {
        viewModel.pieChartSummary?.groups ?? []
    }

    private var stores: [PieChartStore] {
        viewModel.pieChartSummary?.stores ?? []
    }

    private var visibleGroups: [PieChartGroup] {
        showAllRows ? groups : Array(groups.prefix(5))
    }

    private var visibleStores: [PieChartStore] {
        showAllRows ? stores : Array(stores.prefix(5))
    }

    var body: some View {
        if viewModel.categoryState == .loading && groups.isEmpty {
            loadingState
        } else if groups.isEmpty && stores.isEmpty {
            EmptyView()
        } else {
            InsightCardShell {
                VStack(spacing: 20) {
                    // Section header with flip toggle
                    HStack {
                        Text(isShowingCategories ? L("categories") : L("stores"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        flipButton
                    }

                    // Flippable donut chart
                    flippableChart

                    // Rows
                    if isShowingCategories {
                        categoryRows
                    } else {
                        storeRows
                    }
                }
            }
        }
    }

    // MARK: - Flip Button

    private var flipButton: some View {
        Button {
            showAllRows = false
            viewModel.expandedCategoryId = nil
            withAnimation(.spring(response: 0.35, dampingFraction: 1.0)) {
                isShowingCategories.toggle()
                flipDegrees += 180
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .medium))
                Text(isShowingCategories ? L("tap_for_stores") : L("tap_for_categories"))
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.4))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color.white.opacity(0.07))
            )
        }
    }

    // MARK: - Flippable Chart

    private var flippableChart: some View {
        ZStack {
            // Categories side
            IconDonutChartView(
                data: viewModel.categoryChartData,
                totalAmount: viewModel.totalSpend,
                size: 180,
                currencySymbol: "€",
                subtitle: nil,
                totalItems: nil,
                averageItemPrice: nil,
                centerIcon: "cart.fill",
                centerLabel: L("categories"),
                showAllSegments: showAllRows,
                refreshToken: 0
            )
            .opacity(isShowingCategories ? 1 : 0)
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))

            // Stores side
            IconDonutChartView(
                data: viewModel.storeChartData,
                totalAmount: Double(viewModel.receiptCount),
                size: 180,
                currencySymbol: "",
                subtitle: L("receipts"),
                totalItems: nil,
                averageItemPrice: nil,
                centerIcon: "storefront.fill",
                centerLabel: L("stores"),
                showAllSegments: showAllRows,
                refreshToken: 0
            )
            .opacity(isShowingCategories ? 0 : 1)
        }
        .rotation3DEffect(
            .degrees(flipDegrees),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .contentShape(Circle())
        .onTapGesture {
            showAllRows = false
            viewModel.expandedCategoryId = nil
            withAnimation(.spring(response: 0.35, dampingFraction: 1.0)) {
                isShowingCategories.toggle()
                flipDegrees += 180
            }
        }
    }

    // MARK: - Category Rows

    private var categoryRows: some View {
        VStack(spacing: 0) {
            ForEach(visibleGroups) { group in
                let isExpanded = viewModel.expandedCategoryId == group.groupName
                let transactions = viewModel.categoryTransactions[group.groupName] ?? []

                VStack(spacing: 0) {
                    // Tappable row — entire area triggers expand/collapse
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.toggleCategory(group.groupName)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(group.color.gradient)
                                    .frame(width: 36, height: 36)
                                Image.categorySymbol(resolvedGroupIcon(group.groupIcon))
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(group.groupName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                                Text("\(group.percentageText) \u{2022} \(group.transactionCount) items")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.4))
                            }

                            Spacer()

                            Text(group.amountText)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)

                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.25))
                                .animation(.easeInOut(duration: 0.2), value: isExpanded)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Expanded transaction items — no slide, just reveal
                    if isExpanded && !transactions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(transactions) { transaction in
                                HStack(spacing: 10) {
                                    // Phosphor icon via categorySymbol
                                    Circle()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(width: 26, height: 26)
                                        .overlay(
                                            Image.categorySymbol(transaction.icon)
                                                .frame(width: 12, height: 12)
                                                .foregroundStyle(.white.opacity(0.35))
                                        )

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(transaction.displayName)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.65))
                                            .lineLimit(1)
                                        if let brand = transaction.displayDescription {
                                            Text(brand)
                                                .font(.system(size: 11))
                                                .foregroundStyle(.white.opacity(0.3))
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()

                                    Text(String(format: "€%.2f", transaction.itemPrice))
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .padding(.vertical, 5)
                                .padding(.leading, 52)
                            }
                        }
                        .padding(.bottom, 6)
                    }

                    if group.id != visibleGroups.last?.id {
                        Divider()
                            .background(Color.white.opacity(0.06))
                            .padding(.leading, 52)
                    }
                }
            }
            expandCollapseButton(count: groups.count)
        }
        .animation(nil, value: isShowingCategories)
    }

    // MARK: - Store Rows

    private var storeRows: some View {
        VStack(spacing: 0) {
            ForEach(visibleStores) { store in
                storeRow(store)

                if store.id != visibleStores.last?.id {
                    Divider()
                        .background(Color.white.opacity(0.06))
                        .padding(.leading, 52)
                }
            }
            expandCollapseButton(count: stores.count)
        }
        .animation(nil, value: isShowingCategories)
    }

    private func storeRow(_ store: PieChartStore) -> some View {
        let brandColor = viewModel.storeAccentColor(for: store.storeName)

        return HStack(spacing: 14) {
            // Store logo (SVG) with brand color fallback
            ZStack {
                Circle()
                    .fill(brandColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                StoreLogoView(
                    storeName: store.storeName,
                    height: 20,
                    fallbackColor: brandColor
                )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(store.storeName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                Text(store.visitsText)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(store.amountText)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(store.percentageText)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Icon Resolution

    /// Maps backend group icons to working icons.
    /// Some backend icons (e.g. "smoke.fill") don't exist in SF Symbols —
    /// fall back to Phosphor names that Image.categorySymbol() can resolve.
    private func resolvedGroupIcon(_ icon: String) -> String {
        switch icon {
        case "smoke.fill": return "cigarette"  // Phosphor cigarette icon
        default: return icon
        }
    }

    // MARK: - Shared

    private func expandCollapseButton(count: Int) -> some View {
        Group {
            if count > 5 {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAllRows.toggle()
                    }
                } label: {
                    Text(showAllRows ? "Show Less" : "Show All")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
        }
    }

    private var loadingState: some View {
        InsightCardShell {
            ProgressView()
                .tint(.white.opacity(0.4))
                .frame(height: 260)
                .frame(maxWidth: .infinity)
        }
    }
}
