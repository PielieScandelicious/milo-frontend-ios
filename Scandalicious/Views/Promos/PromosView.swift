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
        }
        .task {
            await viewModel.loadPromos()
        }
        .onReceive(NotificationCenter.default.publisher(for: .receiptUploadedSuccessfully)) { _ in
            Task {
                // Wait for backend to rebuild enriched profile after receipt processing
                try? await Task.sleep(for: .seconds(3))
                await viewModel.loadPromos(forceRefresh: true)
            }
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
            VStack(spacing: 20) {
                if viewModel.selectedStoreNames.isEmpty {
                    // Scenario 1: No stores selected
                    noStoresSelectedView
                } else {
                    // Summary header + store bar grouped together
                    VStack(spacing: 8) {
                        PromoSummaryHeader(stores: viewModel.stores)
                        storeBar
                    }
                    .padding(.horizontal, 16)

                    if viewModel.isReloadingAfterStoreChange {
                        PromoSkeletonView()
                    } else if !data.isReady || data.dealCount == 0 {
                        // Scenarios 2, 3, 4: report not ready / no profile / zero deals
                        PromoEmptyView(
                            status: data.reportStatus,
                            title: emptyTitle(for: data),
                            message: data.message,
                            onAddStores: { showManageSheet = true },
                            onScanReceipt: {
                                // Navigate to Home/Scan tab
                                NotificationCenter.default.post(
                                    name: Notification.Name("app.switchToHomeTab"),
                                    object: nil
                                )
                            }
                        )
                    } else {
                        promoContent(data)
                    }
                }
            }
            .sheet(isPresented: $showManageSheet, onDismiss: {
                viewModel.saveStorePreferences()
            }) {
                ManageStoresSheet(viewModel: viewModel)
                    .onAppear { viewModel.beginManagingStores() }
            }
        case .error(let message):
            PromoErrorView(message: message) {
                Task { await viewModel.loadPromos() }
            }
        }
    }

    // MARK: - Scenario 1: No stores selected

    private var noStoresSelectedView: some View {
        VStack(spacing: 24) {
            // Store icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [promoGreenLocal.opacity(0.12), Color.clear],
                            center: .center, startRadius: 0, endRadius: 56
                        )
                    )
                    .frame(width: 112, height: 112)

                Circle()
                    .fill(Color(white: 0.08))
                    .frame(width: 80, height: 80)
                    .overlay(Circle().stroke(promoGreenLocal.opacity(0.25), lineWidth: 1.5))

                Image(systemName: "storefront")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [promoGreenLocal, promoGreenLocal.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: 10) {
                Text("Where do you shop?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text("Pick your favourite stores and Milo will find the best weekly deals for you.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 8)

            // Store preview chips
            storePreviewChips

            // CTA
            Button {
                showManageSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Choose Stores")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(promoGreenLocal))
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
        .glassCard()
        .padding(.horizontal, 16)
    }

    private var storePreviewChips: some View {
        // Show a few popular store logos as a preview of what's available
        let previewStores: [GroceryStore] = [.colruyt, .delhaize, .carrefour, .lidl, .albertHeijn]
        return HStack(spacing: -4) {
            ForEach(Array(previewStores.enumerated()), id: \.element) { index, store in
                StoreLogoView(storeName: store.rawValue, height: 18)
                    .frame(width: 36, height: 36)
                    .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color(white: 0.06), lineWidth: 1.5))
                    .zIndex(Double(previewStores.count - index))
            }
            Text("+\(GroceryStore.promoSupported.count - previewStores.count) more")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.leading, 12)
        }
    }

    // Promo green local ref (same as in PromoComponents)
    private let promoGreenLocal = Color(red: 0.20, green: 0.85, blue: 0.50)

    private var storeBar: some View {
        Button {
            showManageSheet = true
        } label: {
            HStack(spacing: 12) {
                // Overlapping store logos
                HStack(spacing: -6) {
                    ForEach(Array(viewModel.selectedStoreNames.prefix(5).enumerated()), id: \.element) { index, name in
                        StoreLogoView(storeName: name, height: 18)
                            .frame(width: 28, height: 28)
                            .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color(white: 0.06), lineWidth: 1.5))
                            .zIndex(Double(5 - index))
                    }

                    if viewModel.selectedStoreNames.count > 5 {
                        Text("+\(viewModel.selectedStoreNames.count - 5)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tertiary)
                            .frame(width: 28, height: 28)
                            .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                }

                Text("\(viewModel.selectedStoreNames.count) stores")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Text("Edit")
                        .font(.subheadline)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Main content

    private func promoContent(_ data: PromoRecommendationResponse) -> some View {
        // Store sections (hero card and manage button are rendered above)
        VStack(spacing: 12) {
            if !viewModel.stores.isEmpty {
                ForEach(Array(viewModel.stores.enumerated()), id: \.element.id) { index, store in
                    PromoStoreSection(
                        store: store,
                        index: index,
                        onExpand: { viewModel.trackStoreSectionOpened(store) }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func emptyTitle(for data: PromoRecommendationResponse) -> String {
        switch data.reportStatus {
        case .ready:
            if data.preferredStores?.isEmpty == true {
                return "No stores selected"
            }
            return "No deals this week"
        case .noEnrichedProfile:
            return "Help Milo learn your taste"
        case .noReportAvailable:
            return "Milo is on the hunt"
        }
    }
}

// MARK: - Manage Stores Sheet

struct ManageStoresSheet: View {
    @ObservedObject var viewModel: PromosViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                selectedStoresSection

                if !viewModel.availableStores.isEmpty {
                    addStoresSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Manage Stores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .environment(\.editMode, .constant(.active))
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    // MARK: - Selected Stores

    private var selectedStoresSection: some View {
        Section {
            ForEach(viewModel.selectedStoreNames, id: \.self) { name in
                storeRow(name: name)
            }
            .onDelete { offsets in
                withAnimation { viewModel.removeStore(at: offsets) }
            }
            .onMove(perform: viewModel.moveStore)
        } header: {
            Text("Your Stores")
        } footer: {
            if !viewModel.selectedStoreNames.isEmpty {
                Text("Drag to reorder. Tap \(Image(systemName: "minus.circle.fill")) to remove.")
            }
        }
    }

    // MARK: - Add Stores

    private var addStoresSection: some View {
        Section("Add Stores") {
            ForEach(viewModel.availableStores) { store in
                Button {
                    withAnimation { viewModel.addStore(store) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title3)

                        StoreLogoView(storeName: store.rawValue, height: 22)

                        Text(store.displayName)
                            .foregroundStyle(.primary)

                        Spacer()

                        let count = viewModel.dealCount(for: store.canonicalName)
                        if count > 0 {
                            Text("\(count) deals")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Store Row

    private func storeRow(name: String) -> some View {
        HStack(spacing: 12) {
            StoreLogoView(storeName: name, height: 22)

            Text(GroceryStore.fromCanonical(name)?.displayName ?? name.capitalized)

            Spacer()

            let count = viewModel.dealCount(for: name)
            Text("\(count) deals")
                .font(.subheadline)
                .foregroundColor(count > 0 ? .green : Color.white.opacity(0.3))
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
