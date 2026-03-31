//
//  InsightsTabView.swift
//  Scandalicious
//
//  Created by Claude on 23/02/2026.
//

import SwiftUI

struct InsightsTabView: View {
    @ObservedObject var dataManager: StoreDataManager
    @StateObject private var viewModel = InsightsViewModel()

    // Staggered entrance animation states
    @State private var headerVisible = false
    @State private var chartCardVisible = false
    @State private var breakdownVisible = false
    @State private var changesVisible = false
    @State private var hasAnimated = false

    // Deep teal — unique to the Insights tab (Home=blue, Promos=green)
    private let headerColor = Color(red: 0.03, green: 0.18, blue: 0.25)

    var body: some View {
        ZStack(alignment: .top) {
            Color(white: 0.05).ignoresSafeArea()

            ScrollFadingGradientView(headerColor: headerColor)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {

                    // Period header — large total, delta badge
                    periodHeader
                        .padding(.top, 12)
                        .opacity(headerVisible ? 1 : 0)
                        .offset(y: headerVisible ? 0 : 12)

                    // Spending overview card (trend chart + mini stats)
                    spendingOverviewCard
                        .opacity(chartCardVisible ? 1 : 0)
                        .offset(y: chartCardVisible ? 0 : 16)

                    // Flippable category/store breakdown
                    FlippableBreakdownCard(viewModel: viewModel)
                        .opacity(breakdownVisible ? 1 : 0)
                        .offset(y: breakdownVisible ? 0 : 16)

                    // Top changes vs last month
                    TopChangesCard(viewModel: viewModel)
                        .opacity(changesVisible ? 1 : 0)
                        .offset(y: changesVisible ? 0 : 16)

                    Spacer().frame(height: 60)
                }
                .padding(.top, 8)
                .safeAreaPadding(.bottom, 90)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: -proxy.frame(in: .named("insightsScroll")).origin.y
                        )
                    }
                )
            }
            .coordinateSpace(name: "insightsScroll")
        }
        .refreshable {
            await viewModel.refresh()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Insights")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
        .onAppear {
            viewModel.configure(dataManager: dataManager)
            Task { await viewModel.loadInitialData() }

            // Only animate on first appearance — instant on tab switch back
            if hasAnimated {
                headerVisible = true
                chartCardVisible = true
                breakdownVisible = true
                changesVisible = true
            } else {
                hasAnimated = true
                playEntranceAnimation()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .receiptUploadedSuccessfully)) { _ in
            Task {
                // Give the backend time to finalize receipt data before refreshing
                try? await Task.sleep(for: .seconds(2))
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Entrance Animation

    private func playEntranceAnimation() {
        let spring = Animation.spring(response: 0.5, dampingFraction: 0.85)

        withAnimation(spring.delay(0.05)) {
            headerVisible = true
        }
        withAnimation(spring.delay(0.12)) {
            chartCardVisible = true
        }
        withAnimation(spring.delay(0.20)) {
            breakdownVisible = true
        }
        withAnimation(spring.delay(0.28)) {
            changesVisible = true
        }
    }

    // MARK: - Period Header

    private var periodHeader: some View {
        VStack(spacing: 4) {
            Text(viewModel.selectedPeriodLabel.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1.5)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: viewModel.selectedPeriodLabel)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("€")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                Text(viewModel.totalSpend > 0 ? String(format: "%.2f", viewModel.totalSpend) : "000.00")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.9), value: viewModel.totalSpend)
            }
            .padding(.top, 2)
            .redacted(reason: viewModel.totalSpend > 0 ? [] : .placeholder)

            if let delta = viewModel.spendingDelta {
                SpendingDeltaBadge(percentage: delta)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    // MARK: - Spending Overview Card

    private var spendingOverviewCard: some View {
        InsightCardShell {
            VStack(spacing: 16) {
                SpendingTrendChart(viewModel: viewModel)
                    .withSelectionHandling()

                // Mini stats — fade in when data arrives
                let hasStats = viewModel.receiptCount > 0
                HStack(spacing: 0) {
                    miniStat(icon: "receipt", value: hasStats ? "\(viewModel.receiptCount)" : "00", label: L("receipts"))
                    Spacer()
                    miniStat(icon: "basket", value: hasStats ? String(format: "€%.0f", viewModel.averageBasketSize ?? 0) : "€00", label: "avg basket")
                    Spacer()
                    miniStat(
                        icon: "bag",
                        value: hasStats ? "\(viewModel.pieChartSummary?.stores.count ?? 0)" : "00",
                        label: L("stores")
                    )
                }
                .padding(.top, 4)
                .redacted(reason: hasStats ? [] : .placeholder)
                .animation(.easeInOut(duration: 0.3), value: hasStats)
            }
        }
    }

    private func miniStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.35))
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
    }
}
