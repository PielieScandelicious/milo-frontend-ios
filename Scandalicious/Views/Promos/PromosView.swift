//
//  PromosView.swift
//  Scandalicious
//
//  Created by Claude on 09/02/2026.
//

import SwiftUI

struct PromosView: View {
    @ObservedObject var viewModel: PromosViewModel
    @State private var scrollOffset: CGFloat = 0

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
                        contentForState
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
            .refreshable {
                await viewModel.refresh()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("DEALS")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(1.5)
            }
        }
        .task {
            await viewModel.loadPromos()
        }
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
            if data.dealCount == 0 {
                PromoEmptyView()
            } else {
                promoContent(data)
            }
        case .error(let message):
            PromoErrorView(message: message) {
                Task { await viewModel.refresh() }
            }
        }
    }

    // MARK: - Main content

    private func promoContent(_ data: PromoRecommendationResponse) -> some View {
        VStack(spacing: 20) {
            // Hero savings card
            PromoHeroCard(data: data)
                .padding(.horizontal, 16)

            // Top Picks
            if !data.topPicks.isEmpty {
                VStack(spacing: 12) {
                    PromoSectionHeader(title: "TOP PICKS FOR YOU", icon: "star.fill")
                        .padding(.horizontal, 20)

                    // All picks in a single glass card
                    VStack(spacing: 0) {
                        ForEach(Array(data.topPicks.enumerated()), id: \.element.id) { index, pick in
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 0.5)
                                    .padding(.leading, 64)
                                    .padding(.trailing, 16)
                            }
                            PromoTopPickCard(pick: pick, index: index)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(white: 0.08))
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.04), Color.white.opacity(0.02)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )
                    .padding(.horizontal, 16)
                }
            }

            // Smart Switch
            if let smartSwitch = data.smartSwitch {
                PromoSmartSwitchCard(smartSwitch: smartSwitch)
                    .padding(.horizontal, 16)
            }

            // Store sections
            if !data.stores.isEmpty {
                VStack(spacing: 12) {
                    PromoSectionHeader(title: "DEALS BY STORE", icon: "storefront.fill")
                        .padding(.horizontal, 20)

                    ForEach(Array(data.stores.enumerated()), id: \.element.id) { index, store in
                        PromoStoreSection(store: store, index: index)
                    }
                    .padding(.horizontal, 16)
                }
            }

            // Summary
            PromoSummaryFooter(summary: data.summary, stores: data.stores)
                .padding(.horizontal, 16)
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
