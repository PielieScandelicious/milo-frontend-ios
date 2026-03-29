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
    @State private var showManageSheet = false

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
        .tint(.white.opacity(0.6))
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
        appearance.selectedSegmentTintColor = UIColor.white.withAlphaComponent(0.18)
        appearance.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        appearance.setTitleTextAttributes(
            [.foregroundColor: UIColor.white.withAlphaComponent(0.45),
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
            PromoHeroCard(stores: viewModel.stores)
                .padding(.horizontal, 16)

            // Store sections
            VStack(spacing: 12) {
                // Manage button
                HStack {
                    Spacer()
                    Button {
                        showManageSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Manage")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                    }
                }
                .padding(.horizontal, 16)

                if !viewModel.stores.isEmpty {
                    ForEach(Array(viewModel.stores.enumerated()), id: \.element.id) { index, store in
                        PromoStoreSection(
                            store: store,
                            index: index,
                            onExpand: { viewModel.trackStoreSectionOpened(store) }
                        )
                    }
                    .padding(.horizontal, 16)
                }
            }

        }
        .sheet(isPresented: $showManageSheet, onDismiss: {
            viewModel.saveStorePreferences()
        }) {
            ManageStoresSheet(viewModel: viewModel)
                .onAppear { viewModel.beginManagingStores() }
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

// MARK: - Manage Stores Sheet

private let sheetGreen = Color(red: 0.20, green: 0.85, blue: 0.50)

struct ManageStoresSheet: View {
    @ObservedObject var viewModel: PromosViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                // MARK: Selected stores (reorderable)
                Section {
                    ForEach(viewModel.selectedStoreNames, id: \.self) { name in
                        HStack(spacing: 12) {
                            StoreLogoView(storeName: name, height: 22)

                            Text(GroceryStore.fromCanonical(name)?.displayName ?? name.capitalized)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)

                            Spacer()

                            let count = viewModel.dealCount(for: name)
                            if count > 0 {
                                Text("\(count) deals")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(sheetGreen.opacity(0.8))
                            }
                        }
                        .padding(.vertical, 2)
                        .listRowBackground(Color(white: 0.10))
                    }
                    .onMove(perform: viewModel.moveStore)
                    .onDelete(perform: viewModel.removeStore)
                } header: {
                    Text("Your Stores")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(.white.opacity(0.4))
                } footer: {
                    if !viewModel.selectedStoreNames.isEmpty {
                        Text("Drag to reorder priority. Swipe to remove.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.25))
                    }
                }

                // MARK: Available stores (tap to add)
                if !viewModel.availableStores.isEmpty {
                    Section {
                        ForEach(viewModel.availableStores) { store in
                            Button {
                                withAnimation {
                                    viewModel.addStore(store)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    StoreLogoView(storeName: store.rawValue, height: 22)

                                    Text(store.displayName)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))

                                    Spacer()

                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(sheetGreen.opacity(0.6))
                                }
                                .padding(.vertical, 2)
                            }
                            .listRowBackground(Color(white: 0.08))
                        }
                    } header: {
                        Text("Add Stores")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.0)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(white: 0.05))
            .navigationTitle("Manage Stores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            .environment(\.editMode, .constant(.active))
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }
}

// MARK: - Scroll Offset Key

private struct PromoScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
