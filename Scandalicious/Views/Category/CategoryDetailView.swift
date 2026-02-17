//
//  CategoryDetailView.swift
//  Scandalicious
//
//  Detail view showing all transactions for a specific category
//

import SwiftUI

struct CategoryDetailView: View {
    let category: CategorySpendItem
    let period: String  // e.g., "January 2026" or "All"

    @Environment(\.dismiss) private var dismiss
    @State private var transactions: [APITransaction] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var hasInitialized = false

    /// Observe split cache for updates
    @ObservedObject private var splitCache = SplitCacheManager.shared

    // Group transactions by store
    private var transactionsByStore: [(storeName: String, transactions: [APITransaction], totalSpent: Double)] {
        let grouped = Dictionary(grouping: transactions) { $0.storeName }
        return grouped.map { (storeName: $0.key, transactions: $0.value, totalSpent: $0.value.reduce(0) { $0 + $1.totalPrice }) }
            .sorted { $0.totalSpent > $1.totalSpent }
    }

    // Average health score for this category
    private var averageHealthScore: Double? {
        let scores = transactions.compactMap { $0.healthScore }
        guard !scores.isEmpty else { return nil }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    // Total spent
    private var totalSpent: Double {
        transactions.reduce(0) { $0 + $1.totalPrice }
    }

    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()

            if isLoading {
                loadingView
            } else if let error = error {
                errorView(error)
            } else if transactions.isEmpty {
                emptyView
            } else {
                contentView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !hasInitialized {
                hasInitialized = true
                Task {
                    await loadTransactions()
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Skeleton header matching categoryHeader layout
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            SkeletonCircle(size: 36)
                            SkeletonRect(width: 120, height: 20)
                        }
                        SkeletonRect(width: 80, height: 12)
                        SkeletonRect(width: 100, height: 28)
                        SkeletonRect(width: 60, height: 11)
                    }
                    Spacer()
                    VStack(spacing: 8) {
                        SkeletonCircle(size: 64)
                        SkeletonRect(width: 70, height: 10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.04))
                )
                .padding(.horizontal, 16)

                // Skeleton store sections
                ForEach(0..<2, id: \.self) { _ in
                    VStack(spacing: 8) {
                        SkeletonRect(height: 50, cornerRadius: 16)
                        SkeletonTransactionList(count: 3)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 16)
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Failed to load items")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task { await loadTransactions() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue)
                )
            }
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image.categorySymbol(category.icon)
                .frame(width: 40, height: 40)
                .foregroundStyle(category.color)

            Text(L("no_items_found"))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text(L("no_items_in_period"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Category header
                categoryHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // Store breakdown sections
                ForEach(transactionsByStore, id: \.storeName) { storeData in
                    storeSection(storeData)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                }

                // Bottom padding
                Color.clear.frame(height: 32)
            }
        }
    }

    // MARK: - Category Header

    private var categoryHeader: some View {
        let scoreColor = averageHealthScore?.healthScoreColor ?? Color(white: 0.4)
        let nutriLetter: String = {
            guard let score = averageHealthScore else { return "-" }
            return Int(score.rounded()).nutriScoreLetter
        }()

        return HStack(spacing: 0) {
            // Left side: Category info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image.categorySymbol(category.icon)
                        .foregroundStyle(category.color)
                        .frame(width: 20, height: 20)

                    Text(category.name.localizedCategoryName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Text(period.localizedPeriod)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                Text(String(format: "%.2f", totalSpent))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 2)

                Text("\(transactions.count) item\(transactions.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            // Right side: Nutri Score
            VStack(spacing: 8) {
                if averageHealthScore != nil {
                    ZStack {
                        Circle()
                            .fill(scoreColor.opacity(0.15))
                            .frame(width: 64, height: 64)

                        Circle()
                            .stroke(scoreColor, lineWidth: 3)
                            .frame(width: 64, height: 64)

                        Text(nutriLetter)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(scoreColor)
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 64, height: 64)

                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            .frame(width: 64, height: 64)

                        Text("N/A")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }

                Text("NUTRI SCORE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(averageHealthScore != nil ? scoreColor : .white.opacity(0.35))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(category.color.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Store Section

    private func storeSection(_ storeData: (storeName: String, transactions: [APITransaction], totalSpent: Double)) -> some View {
        VStack(spacing: 0) {
            // Store header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 36, height: 36)
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(storeData.storeName.localizedCapitalized)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("\(storeData.transactions.count) item\(storeData.transactions.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer()

                Text(String(format: "%.2f", storeData.totalSpent))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.04))

                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.07), Color.white.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )

            // Transaction items
            VStack(spacing: 0) {
                let sortedTransactions = storeData.transactions.sorted { t1, t2 in
                    let score1 = t1.healthScore
                    let score2 = t2.healthScore
                    if let s1 = score1, let s2 = score2 { return s1 > s2 }
                    if score1 != nil && score2 == nil { return true }
                    if score1 == nil && score2 != nil { return false }
                    return t1.itemName.localizedCaseInsensitiveCompare(t2.itemName) == .orderedAscending
                }

                ForEach(Array(sortedTransactions.enumerated()), id: \.element.id) { index, transaction in
                    transactionRow(transaction, isLast: index == sortedTransactions.count - 1)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
        }
    }

    // MARK: - Transaction Row

    private func transactionRow(_ transaction: APITransaction, isLast: Bool) -> some View {
        // Get split participants for this transaction
        let splitParticipants: [SplitParticipantInfo] = {
            guard let receiptId = transaction.receiptId else {
                return []
            }
            guard let splitData = splitCache.getSplit(for: receiptId) else {
                return []
            }
            let participants = splitData.participantsForTransaction(transaction.id)
            return participants
        }()
        let friendsOnly = splitParticipants.filter { !$0.isMe }

        return HStack(spacing: 12) {
            // Nutri-Score badge (only shown when score exists)
            if transaction.healthScore != nil {
                Text(transaction.healthScore.nutriScoreLetter)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(transaction.healthScore.healthScoreColor)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(transaction.healthScore.healthScoreColor.opacity(0.15))
                    )
                    .overlay(
                        Circle()
                            .stroke(transaction.healthScore.healthScoreColor.opacity(0.3), lineWidth: 0.5)
                    )
            }

            // Item info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(transaction.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)

                    if transaction.quantity > 1 {
                        Text("\(transaction.quantity)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                            )
                    }

                    // Split participant avatars
                    if !friendsOnly.isEmpty {
                        MiniSplitAvatars(participants: friendsOnly)
                    }
                }

                if let description = transaction.displayDescription {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(2)
                }

                Text(formatTransactionDate(transaction.dateParsed))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
            }

            Spacer()

            // Price
            Text(String(format: "%.2f", transaction.totalPrice))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.02))
        )
        .padding(.bottom, isLast ? 0 : 6)
        .task {
            // Fetch split data if we have a receipt ID and it's not cached
            if let receiptId = transaction.receiptId, !splitCache.hasSplit(for: receiptId) {
                await splitCache.fetchSplit(for: receiptId)
            }
        }
    }

    // MARK: - Date Formatting

    private func formatTransactionDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    // MARK: - Load Transactions

    private func loadTransactions() async {
        // Check AppDataCache first for instant display
        let cacheKey = AppDataCache.shared.categoryItemsKey(period: period, category: category.name)
        if let cachedItems = AppDataCache.shared.categoryItemsCache[cacheKey], !cachedItems.isEmpty {
            await MainActor.run {
                self.transactions = cachedItems
                self.isLoading = false
            }
            return
        }

        isLoading = true
        error = nil

        do {
            var filters = TransactionFilters()

            // Use the category name directly from the backend
            filters.category = category.name

            filters.pageSize = 100  // Backend max is 100

            // Handle period filtering
            if period != "All" {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMMM yyyy"
                dateFormatter.locale = Locale(identifier: "en_US")
                dateFormatter.timeZone = TimeZone(identifier: "UTC")

                if let parsedDate = dateFormatter.date(from: period) {
                    var calendar = Calendar(identifier: .gregorian)
                    calendar.timeZone = TimeZone(identifier: "UTC")!

                    let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: parsedDate))!
                    let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

                    filters.startDate = startOfMonth
                    filters.endDate = endOfMonth
                }
            }

            let response = try await AnalyticsAPIService.shared.getTransactions(filters: filters)

            await MainActor.run {
                self.transactions = response.transactions
                self.isLoading = false
                // Update cache for future use
                AppDataCache.shared.updateCategoryItems(period: period, category: category.name, items: response.transactions)
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - Make CategorySpendItem Hashable for navigation

extension CategorySpendItem: Hashable {
    static func == (lhs: CategorySpendItem, rhs: CategorySpendItem) -> Bool {
        lhs.categoryId == rhs.categoryId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(categoryId)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CategoryDetailView(
            category: CategorySpendItem(
                categoryId: "MEAT_FISH",
                name: "Meat & Fish",
                totalSpent: 125.50,
                colorHex: "#FF6B6B",
                percentage: 25.0,
                transactionCount: 12,
                averageHealthScore: 3.5
            ),
            period: "January 2026"
        )
    }
    .preferredColorScheme(.dark)
}
