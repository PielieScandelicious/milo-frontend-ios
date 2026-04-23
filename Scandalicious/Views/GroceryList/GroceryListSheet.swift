//
//  GroceryListSheet.swift
//  Scandalicious
//

import SwiftUI

struct GroceryListSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GroceryListContentView(
                leadingToolbar: {
                    Button(L("done")) { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                },
                onBrowseTapped: { dismiss() }
            )
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

struct GroceryListContentView<Leading: View>: View {
    @ObservedObject private var store = GroceryListStore.shared
    @EnvironmentObject private var foldersViewModel: PromoFoldersViewModel
    @State private var checkedTrigger = false
    @State private var isCartExpanded: Bool = false
    @State private var expandedStores: Set<String> = []
    @State private var selectedDetailItem: GroceryListItem?
    @State private var folderDestination: FolderDestination?
    @State private var pendingScrollStore: String?
    @ViewBuilder let leadingToolbar: () -> Leading
    let onBrowseTapped: () -> Void

    struct FolderDestination: Hashable {
        let folderId: String
        let pageIndex: Int
        let highlightItemId: String?
    }

    private let promoGreen = Color(red: 0.20, green: 0.85, blue: 0.50)

    private let cardWidth: CGFloat = 160

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.06, green: 0.09, blue: 0.14), location: 0.0),
                    .init(color: Color(red: 0.04, green: 0.06, blue: 0.10), location: 0.4),
                    .init(color: Color(red: 0.03, green: 0.04, blue: 0.07), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if store.activeItems.isEmpty {
                emptyState
            } else {
                mainContent
            }
        }
        .navigationTitle(L("grocery_list"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                leadingToolbar()
            }
        }
        .sheet(item: $selectedDetailItem) { item in
            PromoProductDetailSheet(
                gridItem: PromoGridItem(
                    id: item.id,
                    item: item.toPromoStoreItem(),
                    storeName: item.storeName
                ),
                onOpenInFolder: { folder, pageIndex, itemId in
                    folderDestination = FolderDestination(
                        folderId: folder.folderId,
                        pageIndex: pageIndex,
                        highlightItemId: itemId
                    )
                }
            )
            .environmentObject(foldersViewModel)
        }
        .navigationDestination(item: $folderDestination) { dest in
            if case .success(let folders) = foldersViewModel.state,
               let folder = folders.first(where: { $0.folderId == dest.folderId }) {
                PromoFolderPageViewer(
                    folder: folder,
                    initialPage: dest.pageIndex,
                    highlightItemId: dest.highlightItemId
                )
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: checkedTrigger)
        .onAppear {
            store.removeExpired()
            expandedStores.removeAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("app.scrollToStoreInList"))) { notif in
            guard let storeName = notif.userInfo?["storeName"] as? String else { return }
            pendingScrollStore = storeName
        }
    }

    // MARK: - Filtered data

    private var visibleGroups: [(storeName: String, items: [GroceryListItem])] {
        store.itemsByStore
    }

    private var uncheckedGroups: [(storeName: String, items: [GroceryListItem])] {
        visibleGroups
            .map { (storeName: $0.storeName, items: $0.items.filter { !$0.isChecked }) }
            .filter { !$0.items.isEmpty }
    }

    private var checkedItems: [GroceryListItem] {
        visibleGroups
            .flatMap { $0.items }
            .filter { $0.isChecked }
            .sorted { $0.addedAt > $1.addedAt }
    }

    private var visibleSavings: Double {
        visibleGroups.flatMap { $0.items }.reduce(0) { $0 + $1.savings }
    }

    private var visibleCheckedSavings: Double {
        checkedItems.reduce(0) { $0 + $1.savings }
    }

    private var visibleItemCount: Int {
        visibleGroups.reduce(0) { $0 + $1.items.count }
    }

    private var visibleUncheckedCount: Int {
        visibleGroups.flatMap { $0.items }.filter { !$0.isChecked }.count
    }

    // MARK: - Main content

    private var mainContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 20, pinnedViews: []) {
                    if uncheckedGroups.isEmpty && checkedItems.isEmpty {
                        emptyFilterState
                            .padding(.top, 40)
                    }

                    ForEach(store.itemsByStore, id: \.storeName) { group in
                        let hasCoupons = group.items.contains { $0.isCoupon }
                        let hasUncheckedPromos = group.items.contains { !$0.isCoupon && !$0.isChecked }
                        if hasCoupons || hasUncheckedPromos {
                            storeLane(group: group, proxy: proxy)
                                .id(group.storeName)
                        }
                    }

                    if !checkedItems.isEmpty {
                        cartSection
                            .padding(.top, 4)
                    }

                    Color.clear.frame(height: 40)
                }
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
            .onChange(of: pendingScrollStore) { _, newValue in
                guard let storeName = newValue else { return }
                consumePendingScroll(storeName: storeName, proxy: proxy)
            }
            .onAppear {
                if let storeName = pendingScrollStore {
                    consumePendingScroll(storeName: storeName, proxy: proxy)
                }
            }
        }
    }

    private func consumePendingScroll(storeName: String, proxy: ScrollViewProxy) {
        withAnimation(.snappy(duration: 0.3)) {
            expandedStores.insert(storeName)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(storeName, anchor: .top)
            }
            pendingScrollStore = nil
        }
    }

    // MARK: - Store lane

    private func storeLane(
        group: (storeName: String, items: [GroceryListItem]),
        proxy: ScrollViewProxy
    ) -> some View {
        let isExpanded = expandedStores.contains(group.storeName)
        let coupons = group.items
            .filter { $0.isCoupon }
            .sorted { $0.addedAt > $1.addedAt }
        let promos = group.items.filter { !$0.isCoupon && !$0.isChecked }
        let showBothLanes = !coupons.isEmpty && !promos.isEmpty
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy(duration: 0.3)) {
                    if isExpanded {
                        expandedStores.remove(group.storeName)
                    } else {
                        expandedStores.insert(group.storeName)
                    }
                }
                if !isExpanded {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(group.storeName, anchor: .top)
                        }
                    }
                }
            } label: {
                laneHeader(group: group, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            if isExpanded {
                VStack(alignment: .leading, spacing: showBothLanes ? 14 : 0) {
                    if !coupons.isEmpty {
                        couponRow(coupons: coupons, labeled: showBothLanes)
                    }
                    if !promos.isEmpty {
                        promoRow(items: promos, labeled: showBothLanes)
                    }
                }
            }
        }
        .clipped()
    }

    private func couponRow(coupons: [GroceryListItem], labeled: Bool) -> some View {
        let gold = Color(red: 0.95, green: 0.70, blue: 0.15)
        return VStack(alignment: .leading, spacing: 6) {
            if labeled {
                HStack(spacing: 6) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(gold)
                    Text(L("coupons").uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(gold)
                }
                .padding(.horizontal, 20)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(coupons) { coupon in
                        GroceryListCouponCard(
                            item: coupon,
                            onTap: { selectedDetailItem = coupon },
                            onRemove: { remove(coupon) }
                        )
                        .frame(width: cardWidth)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func promoRow(items: [GroceryListItem], labeled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if labeled {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    Text(L("promos").uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 20)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(items) { item in
                        GroceryListCard(
                            item: item,
                            onTap: { selectedDetailItem = item },
                            onRemove: { remove(item) }
                        )
                        .frame(width: cardWidth)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func laneHeader(
        group: (storeName: String, items: [GroceryListItem]),
        isExpanded: Bool
    ) -> some View {
        let total = group.items.count
        let displayName = GroceryStore.fromCanonical(group.storeName)?.displayName
            ?? group.storeName.capitalized
        return HStack(spacing: 12) {
            StoreLogoView(storeName: group.storeName, height: 18)
                .frame(width: 28, height: 28)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(displayName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.95))

            Text("\(total)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(total)))
                .animation(.spring(response: 0.35, dampingFraction: 0.65), value: total)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.35))
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Cart section

    private var cartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy) { isCartExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(promoGreen)
                    Text("In cart")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Text("\(checkedItems.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(checkedItems.count)))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: checkedItems.count)
                    Spacer()
                    if visibleCheckedSavings > 0 {
                        Text(String(format: "saved €%.2f", visibleCheckedSavings))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(promoGreen.opacity(0.85))
                    }
                    Image(systemName: isCartExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            if isCartExpanded {
                LazyVStack(spacing: 8) {
                    ForEach(checkedItems) { item in
                        GroceryListCompactCard(
                            item: item,
                            onToggleChecked: { toggle(item) },
                            onRemove: { remove(item) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            if checkedItems.count <= 3 { isCartExpanded = true }
        }
    }

    // MARK: - Empty states

    private var emptyState: some View {
        ContentUnavailableView {
            Label(L("grocery_list_empty_title"), systemImage: "cart")
                .foregroundColor(.white.opacity(0.6))
        } description: {
            Text(L("grocery_list_empty_description"))
                .foregroundColor(.white.opacity(0.4))
        } actions: {
            Button {
                onBrowseTapped()
            } label: {
                Text(L("browse_deals_to_add"))
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(promoGreen)
        }
    }

    private var emptyFilterState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 32))
                .foregroundColor(promoGreen.opacity(0.6))
            Text("All collected")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Actions

    private func toggle(_ item: GroceryListItem) {
        withAnimation(.snappy) {
            store.toggleChecked(id: item.id)
        }
        checkedTrigger.toggle()
    }

    private func remove(_ item: GroceryListItem) {
        withAnimation(.snappy) {
            store.remove(id: item.id)
        }
    }
}
