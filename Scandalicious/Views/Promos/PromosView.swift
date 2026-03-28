//
//  PromosView.swift
//  Scandalicious
//
//  Created by Claude on 09/02/2026.
//

import SwiftUI

struct PromosView: View {
    @ObservedObject var viewModel: PromosViewModel
    @EnvironmentObject var cashbackViewModel: BrandCashbackViewModel
    @State private var activeSegment: DealsSegment = .weekly
    @State private var scrollOffset: CGFloat = 0
    @State private var contentOpacity: Double = 0

    // Premium emerald header
    private let headerGreen = Color(red: 0.04, green: 0.22, blue: 0.13)

    var body: some View {
        ZStack(alignment: .top) {
            // Near-black base
            Color(white: 0.05).ignoresSafeArea()

            // Premium green gradient header (fades on scroll)
            GeometryReader { geometry in
                LinearGradient(
                    stops: [
                        .init(color: headerGreen, location: 0.0),
                        .init(color: headerGreen.opacity(0.7), location: 0.25),
                        .init(color: headerGreen.opacity(0.3), location: 0.5),
                        .init(color: Color.clear, location: 0.75)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: geometry.size.height * 0.45 + geometry.safeAreaInsets.top)
                .frame(maxWidth: .infinity)
                .offset(y: -geometry.safeAreaInsets.top)
                .opacity(headerGradientOpacity)
                .animation(.linear(duration: 0.1), value: scrollOffset)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()

            // Scrollable content
            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Segment picker
                        Picker("", selection: $activeSegment) {
                            ForEach(DealsSegment.allCases, id: \.self) { segment in
                                Text(segment.rawValue).tag(segment)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                        // Content for selected segment
                        if activeSegment == .weekly {
                            contentForState
                        } else {
                            BrandCashbackView(viewModel: cashbackViewModel)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                    .frame(width: geo.size.width)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(
                                    key: PromoScrollOffsetKey.self,
                                    value: -proxy.frame(in: .named("promoScroll")).origin.y
                                )
                        }
                    )
                }
            }
            .coordinateSpace(name: "promoScroll")
            .onPreferenceChange(PromoScrollOffsetKey.self) { value in
                scrollOffset = max(0, value)
            }

        }
        .navigationBarTitleDisplayMode(.inline)
        .opacity(contentOpacity)
        .refreshable {
            await viewModel.loadPromos(forceRefresh: true)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                contentOpacity = 1.0
            }
            configureSegmentedControlAppearance()
            // Auto-switch to Cashback segment if requested from the hint card
            if UserDefaults.standard.bool(forKey: "cashback.openCashbackSegment") {
                UserDefaults.standard.removeObject(forKey: "cashback.openCashbackSegment")
                withAnimation { activeSegment = .cashback }
            }
        }
        .task {
            await viewModel.loadPromos()
        }
    }

    // MARK: - Segmented Control Appearance

    private func configureSegmentedControlAppearance() {
        let appearance = UISegmentedControl.appearance()
        appearance.selectedSegmentTintColor = UIColor.white.withAlphaComponent(0.12)
        appearance.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        appearance.setTitleTextAttributes(
            [.foregroundColor: UIColor.white.withAlphaComponent(0.5),
             .font: UIFont.systemFont(ofSize: 13, weight: .semibold)],
            for: .normal
        )
        appearance.setTitleTextAttributes(
            [.foregroundColor: UIColor.white,
             .font: UIFont.systemFont(ofSize: 13, weight: .bold)],
            for: .selected
        )
    }

    // MARK: - Header fade

    private var headerGradientOpacity: Double {
        let fadeEnd: CGFloat = 200
        if scrollOffset <= 0 { return 1.0 }
        if scrollOffset >= fadeEnd { return 0.0 }
        return Double(1.0 - (scrollOffset / fadeEnd))
    }

    // MARK: - Content routing

    @ViewBuilder
    private var contentForState: some View {
        switch viewModel.state {
        case .idle, .loading:
            PromoSkeletonView()
        case .success(let data):
            if !data.isReady || data.dealCount == 0 {
                PromoEmptyView(
                    status: data.reportStatus,
                    title: emptyTitle(for: data),
                    message: data.message
                )
            } else {
                promoContent(data)
            }
        case .error(let message):
            PromoErrorView(message: message) {
                Task { await viewModel.loadPromos() }
            }
        }
    }

    // MARK: - Main content

    private func promoContent(_ data: PromoRecommendationResponse) -> some View {
        VStack(spacing: 20) {
            // Hero savings card
            PromoHeroCard(data: data)
                .padding(.horizontal, 16)

            // Store sections
            if !data.stores.isEmpty {
                VStack(spacing: 12) {
                    PromoSectionHeader(title: "DEALS BY STORE", icon: "storefront.fill")
                        .padding(.horizontal, 20)

                    ForEach(Array(data.stores.enumerated()), id: \.element.id) { index, store in
                        PromoStoreSection(
                            store: store,
                            index: index,
                            onExpand: { viewModel.trackStoreSectionOpened(store) },
                            onClaim: { item in viewModel.trackDealClaimed(item: item, store: store, reportId: data.reportId) }
                        )
                    }
                    .padding(.horizontal, 16)
                }
            }

        }
    }

    private func emptyTitle(for data: PromoRecommendationResponse) -> String {
        switch data.reportStatus {
        case .ready:
            return "No deals this week"
        case .noEnrichedProfile:
            return "Keep scanning receipts"
        case .noReportAvailable:
            return "Report not ready yet"
        }
    }
}

// MARK: - Scroll Offset Key

private struct PromoScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
