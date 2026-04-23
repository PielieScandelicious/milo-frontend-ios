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

    /// All active (non-expired) coupons the user has saved, across every store,
    /// sorted most-recently-added first. Drives the top "Coupons" lane.
    private var couponItems: [GroceryListItem] {
        store.activeItems
            .filter { $0.isCoupon }
            .sorted { $0.addedAt > $1.addedAt }
    }

    // MARK: - Coupons top lane

    private var couponsLane: some View {
        let gold = Color(red: 0.95, green: 0.70, blue: 0.15)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(gold)
                Text(L("coupons").uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(gold)
                Text("\(couponItems.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(gold))
                Spacer()
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(couponItems) { coupon in
                        Button {
                            selectedDetailItem = coupon
                        } label: {
                            couponCard(for: coupon)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func couponCard(for coupon: GroceryListItem) -> some View {
        let gold = Color(red: 0.95, green: 0.70, blue: 0.15)
        let rewardLabel: String = {
            guard let value = coupon.couponValue else { return L("coupon_generic") }
            switch coupon.couponType {
            case "loyalty_points": return "+\(Int(value.rounded())) \(L("coupon_points_unit"))"
            case "cashback":       return String(format: "€%.2f", value).replacingOccurrences(of: ".", with: ",")
            case "percent_off_coupon": return "-\(Int(value.rounded()))%"
            default: return L("coupon_generic")
            }
        }()
        let typeLabel: String = {
            switch coupon.couponType {
            case "loyalty_points": return L("coupon_loyalty_points")
            case "cashback": return L("coupon_cashback")
            case "free_product": return L("coupon_free_product")
            case "percent_off_coupon": return L("coupon_discount")
            default: return L("coupon_generic")
            }
        }()
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(gold)
                Text(coupon.storeName.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(gold)
            }
            Text(rewardLabel)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(typeLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
            Text(coupon.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 2)
            if let days = coupon.daysRemaining, days >= 0 {
                Text(String(format: L("coupon_expires_in_days"), days))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(days <= 2 ? Color(red: 1.0, green: 0.55, blue: 0.35) : .white.opacity(0.55))
            }
        }
        .padding(12)
        .frame(width: 160, height: 140, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(white: 0.12), Color(white: 0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(gold.opacity(0.4), lineWidth: 1)
                )
        )
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

                    // Coupons lane — pinned above the regular grocery sections.
                    // Coupons stay in the main items list under the hood but get
                    // surfaced here first because redeeming them is the user's
                    // priority at the till.
                    if !couponItems.isEmpty {
                        couponsLane
                    }

                    ForEach(store.itemsByStore, id: \.storeName) { group in
                        let unchecked = group.items.filter { !$0.isChecked && !$0.isCoupon }
                        if !unchecked.isEmpty {
                            storeLane(group: (storeName: group.storeName, items: group.items.filter { !$0.isCoupon }),
                                      uncheckedItems: unchecked, proxy: proxy)
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
        uncheckedItems: [GroceryListItem],
        proxy: ScrollViewProxy
    ) -> some View {
        let isExpanded = expandedStores.contains(group.storeName)
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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(uncheckedItems) { item in
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
        .clipped()
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
