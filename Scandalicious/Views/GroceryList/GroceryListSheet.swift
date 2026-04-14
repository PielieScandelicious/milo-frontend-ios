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
            if store.activeItems.contains(where: { $0.isChecked }) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            store.removeChecked()
                        }
                    } label: {
                        Text(L("clear_checked"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            }
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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 20, pinnedViews: []) {
                    savingsHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    storeChipRail(proxy: proxy)

                    if uncheckedGroups.isEmpty && checkedItems.isEmpty {
                        emptyFilterState
                            .padding(.top, 40)
                    }

                    // One horizontal lane per store (shows unchecked items; header shows totals)
                    ForEach(store.itemsByStore, id: \.storeName) { group in
                        let unchecked = group.items
                            .filter { !$0.isChecked }
                            .sorted { $0.addedAt < $1.addedAt }
                        if !unchecked.isEmpty {
                            storeLane(group: group, uncheckedItems: unchecked)
                                .id("lane-\(group.storeName)")
                        }
                    }

                    if !checkedItems.isEmpty {
                        cartSection
                            .padding(.top, 4)
                    }

                    Color.clear.frame(height: 40)
                }
            }
            .scrollIndicators(.hidden)
        }
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
                            onToggleChecked: { toggle(item) },
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
        let remaining = group.items.filter { !$0.isChecked }.count
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
                    Text("\(remaining) of \(total) to find")
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
            Capsule()
                .fill(accent.opacity(0.2))
                .overlay(Capsule().stroke(accent.opacity(0.4), lineWidth: 0.5))
                .frame(width: 40, height: 4)
        }
    }

    // MARK: - Savings header

    private var savingsHeader: some View {
        let total = visibleSavings
        let checkedCount = visibleItemCount - visibleUncheckedCount
        let progress: Double = visibleItemCount > 0 ? Double(checkedCount) / Double(visibleItemCount) : 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("total_savings").uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(.white.opacity(0.5))
                    Text(String(format: "€%.2f", total))
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(promoGreen)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(visibleItemCount)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(visibleItemCount == 1 ? "item" : "items")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(0.8)
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(promoGreen)
                        .frame(width: max(4, geo.size.width * progress))
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(visibleUncheckedCount) to find")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                Spacer()
                if visibleItemCount > 0 {
                    Text("\(checkedCount) / \(visibleItemCount) collected")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(promoGreen.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(promoGreen.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: - Store chip rail

    private func storeChipRail(proxy: ScrollViewProxy) -> some View {
        let groups = store.itemsByStore
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(groups, id: \.storeName) { group in
                    let accent = GroceryStore.fromCanonical(group.storeName)?.accentColor ?? promoGreen
                    let remaining = group.items.filter { !$0.isChecked }.count
                    chip(
                        isSelected: false,
                        accent: accent,
                        action: {
                            withAnimation(.snappy) {
                                proxy.scrollTo("lane-\(group.storeName)", anchor: .top)
                            }
                        }
                    ) {
                        HStack(spacing: 6) {
                            StoreLogoView(storeName: group.storeName, height: 14)
                                .frame(height: 14)
                            Text("\(remaining)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(accent)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(accent.opacity(0.15)))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func chip<Content: View>(
        isSelected: Bool,
        accent: Color,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            content()
                .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? accent : Color.white.opacity(0.06))
                )
                .overlay(
                    Capsule().stroke(isSelected ? accent : Color.white.opacity(0.08), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
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
