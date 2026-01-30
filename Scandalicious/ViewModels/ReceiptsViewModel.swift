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

        // Log API call
        let storeInfo = storeName ?? "all stores"
        let dateRange = period == "All" ? "all time" : formatDateRange(start: filters.startDate, end: filters.endDate)
        print("📥 GET /receipts - period: \(period), store: \(storeInfo), page: \(currentPage), dates: \(dateRange)")

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

            print("✅ GET /receipts - returned \(response.receipts.count) receipts (total: \(response.total), page \(response.page)/\(response.totalPages))")

            // Auto-load remaining pages to show all receipts at initial load
            if reset && hasMorePages {
                await loadAllRemainingPages(period: period, storeName: storeName)
            }

        } catch {
            print("❌ GET /receipts - error: \(error.localizedDescription)")
            state = .error(error.localizedDescription)
        }
    }

    /// Load all remaining pages automatically
    private func loadAllRemainingPages(period: String, storeName: String?) async {
        while hasMorePages {
            currentPage += 1
            filters.page = currentPage

            print("📄 Auto-loading page \(currentPage) of \(totalPages)")

            do {
                let response = try await apiService.fetchReceipts(filters: filters)
                receipts.append(contentsOf: response.receipts)
                hasMorePages = response.page < response.totalPages
                state = .success(receipts)

                print("✅ Page \(currentPage) loaded - total receipts: \(receipts.count)")
            } catch {
                print("❌ Failed to load page \(currentPage): \(error.localizedDescription)")
                break
            }
        }

        hasMorePages = false
        print("📋 All \(receipts.count) receipts loaded")
    }

    /// Load next page of receipts
    func loadNextPage(period: String, storeName: String? = nil) async {
        guard hasMorePages else { return }
        currentPage += 1
        print("📄 Loading next page of receipts (page \(currentPage))")
        await loadReceipts(period: period, storeName: storeName, reset: false)
    }

    /// Refresh receipts
    func refresh(period: String, storeName: String? = nil) async {
        print("🔄 Refreshing receipts for \(period)")
        await loadReceipts(period: period, storeName: storeName, reset: true)
    }

    /// Delete a receipt by ID and update the list
    func deleteReceipt(_ receipt: APIReceipt, period: String, storeName: String?) async throws {
        print("🗑️ DELETE /receipts/\(receipt.receiptId) - store: \(receipt.storeName ?? "unknown")")

        // Delete from server
        try await apiService.removeReceipt(receiptId: receipt.receiptId)

        // Remove from local array - notify observers explicitly
        objectWillChange.send()
        receipts.removeAll { $0.receiptId == receipt.receiptId }
        state = .success(receipts)

        print("✅ Receipt deleted, remaining: \(receipts.count)")

        // Notify other views to refresh their data
        NotificationCenter.default.post(name: .receiptsDataDidChange, object: nil)
    }

    // MARK: - Private Helpers

    private func parsePeriod(_ period: String) -> (Date?, Date?) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "UTC") // Use UTC to avoid timezone shifts

        guard let date = dateFormatter.date(from: period) else {
            print("⚠️ Failed to parse period '\(period)' - expected format 'MMMM yyyy'")
            return (nil, nil)
        }

        // Use UTC calendar to avoid timezone issues
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

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