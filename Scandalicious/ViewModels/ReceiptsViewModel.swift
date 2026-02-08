//
//  ReceiptsViewModel.swift
//  Scandalicious
//
//  Created by Claude on 24/01/2026.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Receipts ViewModel

@MainActor
class ReceiptsViewModel: ObservableObject {
    @Published var state: LoadingState<[APIReceipt]> = .idle
    @Published var receipts: [APIReceipt] = []
    @Published var hasMorePages = false
    @Published var currentPage = 1
    @Published var totalPages = 1

    private let apiService = AnalyticsAPIService.shared
    private var filters = ReceiptFilters()

    /// Load receipts for a given period and optional store filter
    /// Pass "All" as period to load all receipts without date filtering
    func loadReceipts(period: String, storeName: String? = nil, reset: Bool = true) async {
        if reset {
            state = .loading
            receipts = []
            currentPage = 1
        }

        // Configure filters
        filters = ReceiptFilters()
        filters.page = currentPage
        filters.pageSize = 20

        // Handle "All" period - no date filtering
        if period != "All" {
            // Parse period to get date range
            let (startDate, endDate) = parsePeriod(period)
            filters.startDate = startDate
            filters.endDate = endDate
        }

        if let store = storeName, store != "All Stores" {
            filters.storeName = store
        }

        do {
            let response = try await apiService.fetchReceipts(filters: filters)

            if reset {
                receipts = response.receipts
            } else {
                receipts.append(contentsOf: response.receipts)
            }

            totalPages = response.totalPages
            hasMorePages = response.page < response.totalPages
            state = .success(receipts)

            // Auto-load remaining pages to show all receipts at initial load
            if reset && hasMorePages {
                await loadAllRemainingPages(period: period, storeName: storeName)
            }

        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Load all remaining pages automatically
    private func loadAllRemainingPages(period: String, storeName: String?) async {
        while hasMorePages {
            currentPage += 1
            filters.page = currentPage

            do {
                let response = try await apiService.fetchReceipts(filters: filters)
                receipts.append(contentsOf: response.receipts)
                hasMorePages = response.page < response.totalPages
                state = .success(receipts)
            } catch {
                break
            }
        }

        hasMorePages = false
    }

    /// Load next page of receipts
    func loadNextPage(period: String, storeName: String? = nil) async {
        guard hasMorePages else { return }
        currentPage += 1
        await loadReceipts(period: period, storeName: storeName, reset: false)
    }

    /// Refresh receipts
    func refresh(period: String, storeName: String? = nil) async {
        await loadReceipts(period: period, storeName: storeName, reset: true)
    }

    /// Delete a receipt by ID and update the list
    func deleteReceipt(_ receipt: APIReceipt, period: String, storeName: String?) async throws {
        let receiptId = receipt.receiptId
        print("[ReceiptsVM] deleteReceipt called for id=\(receiptId), period=\(period), count before=\(receipts.count)")

        // Delete from server
        try await apiService.removeReceipt(receiptId: receiptId)
        print("[ReceiptsVM] Server deletion succeeded for id=\(receiptId)")

        // Remove from local array using explicit filter (not in-place mutation)
        let updatedReceipts = receipts.filter { $0.receiptId != receiptId }
        print("[ReceiptsVM] Filtered receipts: before=\(receipts.count), after=\(updatedReceipts.count)")
        receipts = updatedReceipts
        state = .success(updatedReceipts)

        // Sync deletion to AppDataCache so stale cache doesn't restore the receipt
        AppDataCache.shared.receiptsByPeriod[period]?.removeAll { $0.receiptId == receiptId }
        AppDataCache.shared.scheduleSaveToDisk()

        print("[ReceiptsVM] deleteReceipt done, receipts.count=\(receipts.count)")

        // Notify other views to refresh their data
        NotificationCenter.default.post(name: .receiptsDataDidChange, object: nil)
    }

    /// Delete a specific line item from a receipt
    func deleteReceiptItem(receiptId: String, itemId: String) async throws {
        // Delete from server
        let response = try await apiService.removeReceiptItem(receiptId: receiptId, itemId: itemId)

        // Update local array - find and modify the receipt
        objectWillChange.send()

        if let receiptIndex = receipts.firstIndex(where: { $0.receiptId == receiptId }) {
            let receipt = receipts[receiptIndex]

            // Check if backend indicates the receipt was deleted (last item removed)
            if response.receiptDeleted == true {
                receipts.remove(at: receiptIndex)
            } else {
                // Remove the item from the receipt's transactions
                let updatedTransactions = receipt.transactions.filter { $0.itemId != itemId }

                // Create updated receipt with new transactions and backend-provided values
                let updatedReceipt = APIReceipt(
                    receiptId: receipt.receiptId,
                    storeName: receipt.storeName,
                    receiptDate: receipt.receiptDate,
                    totalAmount: response.updatedTotalAmount ?? receipt.totalAmount,
                    itemsCount: response.updatedItemsCount ?? updatedTransactions.count,
                    averageHealthScore: response.updatedAverageHealthScore ?? calculateAverageHealthScore(for: updatedTransactions),
                    transactions: updatedTransactions
                )

                // If no items left locally, remove the receipt
                if updatedTransactions.isEmpty {
                    receipts.remove(at: receiptIndex)
                } else {
                    receipts[receiptIndex] = updatedReceipt
                }
            }

            state = .success(receipts)

            // Sync changes to AppDataCache so stale cache doesn't restore old data
            for (period, var periodReceipts) in AppDataCache.shared.receiptsByPeriod {
                if let cacheIndex = periodReceipts.firstIndex(where: { $0.receiptId == receiptId }) {
                    if let updatedReceipt = receipts.first(where: { $0.receiptId == receiptId }) {
                        periodReceipts[cacheIndex] = updatedReceipt
                    } else {
                        periodReceipts.remove(at: cacheIndex)
                    }
                    AppDataCache.shared.receiptsByPeriod[period] = periodReceipts
                }
            }
            AppDataCache.shared.scheduleSaveToDisk()
        }

        // Notify other views to refresh their data
        NotificationCenter.default.post(name: .receiptsDataDidChange, object: nil)
    }

    /// Calculate average health score for a list of items
    private func calculateAverageHealthScore(for items: [APIReceiptItem]) -> Double? {
        let scores = items.compactMap { $0.healthScore }
        guard !scores.isEmpty else { return nil }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    // MARK: - Private Helpers

    /// Check if a period is a year period (e.g., "2025", "2024")
    private func isYearPeriod(_ period: String) -> Bool {
        return period.count == 4 && period.allSatisfy { $0.isNumber }
    }

    private func parsePeriod(_ period: String) -> (Date?, Date?) {
        // Use UTC calendar to avoid timezone issues
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // Handle year periods (e.g., "2025")
        if isYearPeriod(period), let year = Int(period) {
            var startComponents = DateComponents()
            startComponents.year = year
            startComponents.month = 1
            startComponents.day = 1
            let startOfYear = calendar.date(from: startComponents)

            var endComponents = DateComponents()
            endComponents.year = year
            endComponents.month = 12
            endComponents.day = 31
            endComponents.hour = 23
            endComponents.minute = 59
            endComponents.second = 59
            let endOfYear = calendar.date(from: endComponents)

            return (startOfYear, endOfYear)
        }

        // Handle month periods (e.g., "January 2026")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "UTC") // Use UTC to avoid timezone shifts

        guard let date = dateFormatter.date(from: period) else {
            return (nil, nil)
        }

        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))

        var endComponents = DateComponents()
        endComponents.month = 1
        endComponents.second = -1
        let endOfMonth = calendar.date(byAdding: endComponents, to: startOfMonth ?? date)

        return (startOfMonth, endOfMonth)
    }

    private func formatDateRange(start: Date?, end: Date?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let startStr = start.map { formatter.string(from: $0) } ?? "nil"
        let endStr = end.map { formatter.string(from: $0) } ?? "nil"
        return "\(startStr) to \(endStr)"
    }
}
