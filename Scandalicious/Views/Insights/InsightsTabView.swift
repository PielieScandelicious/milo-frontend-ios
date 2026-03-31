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

            if viewModel.totalSpend > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("€")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(String(format: "%.2f", viewModel.totalSpend))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: viewModel.totalSpend)
                }
                .padding(.top, 2)

                if let delta = viewModel.spendingDelta {
                    SpendingDeltaBadge(percentage: delta)
                        .padding(.top, 4)
                }
            } else if viewModel.trendState == .loading {
                // Skeleton for total amount
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 180, height: 48)
                    .padding(.top, 2)
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
                if viewModel.receiptCount > 0 {
                    HStack(spacing: 0) {
                        miniStat(icon: "receipt", value: "\(viewModel.receiptCount)", label: L("receipts"))
                        Spacer()
                        if let avg = viewModel.averageBasketSize {
                            miniStat(icon: "basket", value: String(format: "€%.0f", avg), label: "avg basket")
                        }
                        Spacer()
                        miniStat(
                            icon: "bag",
                            value: "\(viewModel.pieChartSummary?.stores.count ?? 0)",
                            label: L("stores")
                        )
                    }
                    .padding(.top, 4)
                    .transition(.opacity)
                } else if viewModel.trendState == .loading {
                    // Skeleton stats row
                    HStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { _ in
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.05))
                                    .frame(width: 32, height: 14)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.04))
                                    .frame(width: 44, height: 10)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 4)
                }
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
