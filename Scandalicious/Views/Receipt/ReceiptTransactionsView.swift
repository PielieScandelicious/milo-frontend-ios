//
//  ReceiptTransactionsView.swift
//  Scandalicious
//
//  Created by Claude on 24/01/2026.
//

import SwiftUI

struct ReceiptTransactionsView: View {
    let receipt: APIReceipt

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    /// Tracks which grocery sub-categories are collapsed (hidden items)
    @State private var collapsedGrocerySubCategories: Set<String> = []

    private var filteredTransactions: [APIReceiptItem] {
        if searchText.isEmpty {
            return receipt.transactions
        }
        return receipt.transactions.filter {
            $0.itemName.localizedCaseInsensitiveContains(searchText) ||
            $0.categoryDisplayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Grocery items grouped by sub-category, sorted by total spend
    private var grocerySubGroups: [(String, [APIReceiptItem])] {
        let groceryItems = filteredTransactions.filter {
            $0.categoryDisplayName.isGroceryCategory
        }
        guard !groceryItems.isEmpty else { return [] }

        let grouped = Dictionary(grouping: groceryItems) { $0.categoryDisplayName }
        return grouped.sorted { first, second in
            let firstTotal = first.value.reduce(0) { $0 + $1.totalPrice }
            let secondTotal = second.value.reduce(0) { $0 + $1.totalPrice }
            return firstTotal > secondTotal
        }
    }

    /// Non-grocery items grouped by sub-category (original behavior), sorted by total spend
    private var nonGroceryGroups: [(String, [APIReceiptItem])] {
        let nonGroceryItems = filteredTransactions.filter {
            !$0.categoryDisplayName.isGroceryCategory
        }
        guard !nonGroceryItems.isEmpty else { return [] }

        let grouped = Dictionary(grouping: nonGroceryItems) { $0.categoryDisplayName }
        return grouped.sorted { first, second in
            let firstTotal = first.value.reduce(0) { $0 + $1.totalPrice }
            let secondTotal = second.value.reduce(0) { $0 + $1.totalPrice }
            return firstTotal > secondTotal
        }
    }

    /// Total grocery spend (for sorting Groceries section among others)
    private var groceryTotal: Double {
        grocerySubGroups.flatMap { $0.1 }.reduce(0) { $0 + $1.totalPrice }
    }

    /// All sections combined: Groceries as one section + individual non-grocery sub-categories
    /// Sorted by total spend descending
    private enum SectionItem: Identifiable {
        case groceries
        case subCategory(name: String, items: [APIReceiptItem])

        var id: String {
            switch self {
            case .groceries: return "__groceries__"
            case .subCategory(let name, _): return name
            }
        }

        var totalSpent: Double {
            switch self {
            case .groceries: return 0 // handled separately
            case .subCategory(_, let items): return items.reduce(0) { $0 + $1.totalPrice }
            }
        }
    }

    private var orderedSections: [SectionItem] {
        var sections: [(Double, SectionItem)] = []

        if !grocerySubGroups.isEmpty {
            sections.append((groceryTotal, .groceries))
        }

        for (name, items) in nonGroceryGroups {
            let total = items.reduce(0) { $0 + $1.totalPrice }
            sections.append((total, .subCategory(name: name, items: items)))
        }

        return sections.sorted { $0.0 > $1.0 }.map { $0.1 }
    }

    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    searchBar

                    if filteredTransactions.isEmpty {
                        emptySearchState
                    } else {
                        LazyVStack(spacing: 24) {
                            ForEach(orderedSections) { section in
                                switch section {
                                case .groceries:
                                    groceriesCategorySection()
                                case .subCategory(let name, let items):
                                    categorySection(category: name, transactions: items)
                                }
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(receipt.displayStoreName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Text(receipt.formattedDate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }

    // MARK: - Components

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Receipt header card
            VStack(spacing: 12) {
                // Store icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: "building.2.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.blue)
                }

                Text(receipt.displayStoreName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(receipt.formattedDate)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                Text(String(format: "€%.2f", receipt.displayTotalAmount))
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 4)

                // Health score if available
                if let healthScore = receipt.averageHealthScore {
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.horizontal, 40)
                        .padding(.top, 8)

                    HStack(spacing: 8) {
                        HealthScoreBadge(score: Int(healthScore.rounded()), size: .medium, style: .subtle)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("health_score"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))

                            Text(healthScore.healthScoreLabel)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(healthScore.healthScoreColor)
                        }
                    }
                    .padding(.top, 4)
                }

                // Item count
                Text("\(receipt.itemsCount) item\(receipt.itemsCount == 1 ? "" : "s")")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 4)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(searchText.isEmpty ? .white.opacity(0.4) : .white.opacity(0.6))

            TextField(L("search_items"), text: $searchText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .accentColor(.blue)
                .focused($isSearchFocused)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSearchFocused ? Color.blue.opacity(0.5) : Color.white.opacity(0.15),
                    lineWidth: isSearchFocused ? 2 : 1
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.3), value: isSearchFocused)
    }

    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))
                .padding(.top, 40)

            Text(L("no_results_search"))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Text(L("try_adjusting_search"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Non-Groceries Section (original behavior)

    private func categorySection(category: String, transactions: [APIReceiptItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack {
                Image.categorySymbol(category.categoryIcon)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(category.categoryColor)

                Text(category)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                Text(String(format: "€%.2f", transactions.reduce(0) { $0 + $1.totalPrice }))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 24)

            // Transaction rows
            VStack(spacing: 8) {
                ForEach(transactions) { transaction in
                    transactionRow(transaction)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Groceries Section (collapsible sub-categories)

    private func groceriesCategorySection() -> some View {
        let registry = CategoryRegistryManager.shared
        let parentGroup = registry.groupForCategory("Groceries")
        let color = registry.colorForGroup(parentGroup)
        let icon = registry.iconForGroup(parentGroup)
        let allGroceryItems = grocerySubGroups.flatMap { $0.1 }
        let totalSpent = allGroceryItems.reduce(0) { $0 + $1.totalPrice }

        return VStack(alignment: .leading, spacing: 12) {
            // Main "Groceries" header
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)

                Text(L("groceries"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                Text(String(format: "€%.2f", totalSpent))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 24)

            // Collapsible sub-sections by sub-category
            VStack(spacing: 4) {
                ForEach(grocerySubGroups, id: \.0) { subCategory, items in
                    let isCollapsed = collapsedGrocerySubCategories.contains(subCategory)
                    let subTotal = items.reduce(0) { $0 + $1.totalPrice }

                    VStack(alignment: .leading, spacing: 0) {
                        let subColor = subCategory.categoryColor
                        let subIcon = subCategory.categoryIcon

                        // Tappable sub-category header
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if isCollapsed {
                                    collapsedGrocerySubCategories.remove(subCategory)
                                } else {
                                    collapsedGrocerySubCategories.insert(subCategory)
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image.categorySymbol(subIcon)
                                    .foregroundStyle(subColor)
                                    .frame(width: 16, height: 16)

                                Text(subCategory.localizedCategoryName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))

                                Spacer()

                                Text("\(items.count)")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.35))

                                Text(String(format: "€%.2f", subTotal))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.3))
                                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        // Items (shown when not collapsed)
                        if !isCollapsed {
                            VStack(spacing: 8) {
                                ForEach(items) { transaction in
                                    transactionRow(transaction, colorOverride: subColor)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }
        }
    }

    private func transactionRow(_ transaction: APIReceiptItem, colorOverride: Color? = nil) -> some View {
        let itemColor = colorOverride ?? transaction.categoryDisplayName.categoryColor
        let itemIcon = transaction.categoryDisplayName.categoryIcon

        return HStack(spacing: 12) {
            // Icon with quantity badge
            ZStack(alignment: .topTrailing) {
                CategoryIconBadge(icon: itemIcon, color: itemColor, size: 50)

                if transaction.quantity > 1 {
                    Text("×\(transaction.quantity)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(itemColor.adjustBrightness(by: -0.25))
                        )
                        .offset(x: 6, y: -4)
                }
            }
            .frame(width: 50, height: 50)

            // Item details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(transaction.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        if let description = transaction.displayDescription {
                            Text(description)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.45))
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 0)

                    if let healthScore = transaction.healthScore {
                        HealthScoreBadge(score: healthScore, size: .small, style: .subtle)
                    }
                }

                HStack(spacing: 8) {
                    Text(transaction.categoryDisplayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))

                    if transaction.quantity > 1 {
                        Text("•")
                            .foregroundColor(.white.opacity(0.3))

                        Text("\(L("qty")): \(transaction.quantity)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                if let unitPrice = transaction.unitPrice, transaction.quantity > 1 {
                    Text(unitPrice, format: .currency(code: "EUR"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()

            // Price
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "€%.2f", transaction.totalPrice))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if let score = transaction.healthScore {
                    Text(score.healthScoreShortLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(score.healthScoreColor)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }


}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReceiptTransactionsView(
            receipt: APIReceipt(
                receiptId: "abc123",
                storeName: "COLRUYT",
                receiptDate: "2026-01-24",
                totalAmount: 4.48,
                itemsCount: 2,
                averageHealthScore: 3.5,
                transactions: [
                    APIReceiptItem(
                        itemName: "Organic Milk",
                        itemPrice: 2.49,
                        quantity: 2,
                        unitPrice: 1.245,
                        category: "Dairy & Eggs",
                        healthScore: 4
                    ),
                    APIReceiptItem(
                        itemName: "Fresh Bread",
                        itemPrice: 1.99,
                        quantity: 1,
                        unitPrice: nil,
                        category: "Bakery",
                        healthScore: 3
                    )
                ]
            )
        )
    }
    .preferredColorScheme(.dark)
}
