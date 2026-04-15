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
    @State private var checkedTrigger = false
    @State private var isCartExpanded: Bool = false
    @State private var selectedDetailItem: GroceryListItem?
    @ViewBuilder let leadingToolbar: () -> Leading
    let onBrowseTapped: () -> Void

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
                )
            )
        }
        .sensoryFeedback(.impact(weight: .light), trigger: checkedTrigger)
        .onAppear {
            store.removeExpired()
        }
    }

    // MARK: - Filtered data

    private var visibleGroups: [(storeName: String, items: [GroceryListItem])] {
        store.itemsByStore
    }

    private var uncheckedGroups: [(storeName: String, items: [GroceryListItem])] {
        visibleGroups
            .map { (storeName: $0.storeName, items: $0.items.filter { !$0.isChecked }
                .sorted { $0.addedAt < $1.addedAt }) }
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
        ScrollView {
            LazyVStack(spacing: 20, pinnedViews: []) {
                if uncheckedGroups.isEmpty && checkedItems.isEmpty {
                    emptyFilterState
                        .padding(.top, 40)
                }

                ForEach(store.itemsByStore, id: \.storeName) { group in
                    let unchecked = group.items
                        .filter { !$0.isChecked }
                        .sorted { $0.addedAt < $1.addedAt }
                    if !unchecked.isEmpty {
                        storeLane(group: group, uncheckedItems: unchecked)
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
    }

    // MARK: - Store lane

    private func storeLane(
        group: (storeName: String, items: [GroceryListItem]),
        uncheckedItems: [GroceryListItem]
    ) -> some View {
        let accent = GroceryStore.fromCanonical(group.storeName)?.accentColor ?? promoGreen
        return VStack(alignment: .leading, spacing: 10) {
            laneHeader(group: group, accent: accent)
                .padding(.horizontal, 16)

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

    private func laneHeader(
        group: (storeName: String, items: [GroceryListItem]),
        accent: Color
    ) -> some View {
        let savings = group.items.reduce(0) { $0 + $1.savings }
        let total = group.items.count
        let displayName = GroceryStore.fromCanonical(group.storeName)?.displayName
            ?? group.storeName.capitalized
        return HStack(spacing: 10) {
            StoreLogoView(storeName: group.storeName, height: 22)
                .frame(width: 34, height: 34)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Text("\(total) \(total == 1 ? "item" : "items")")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                    if savings > 0 {
                        Text("•")
                            .foregroundColor(.white.opacity(0.3))
                        Text(String(format: "save €%.2f", savings))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(promoGreen.opacity(0.9))
                    }
                }
            }
            Spacer()
        }
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
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
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
