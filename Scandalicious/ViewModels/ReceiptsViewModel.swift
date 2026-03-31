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
    @Published var totalCount = 0

    private let apiService = AnalyticsAPIService.shared
    private var filters = ReceiptFilters()

    /// Load receipts for a given period and optional store filter.
    /// Pass "All" as period to load all receipts without date filtering.
    /// Set `loadAll` to false for lazy pagination (only first page loaded).
    func loadReceipts(period: String, storeName: String? = nil, reset: Bool = true, loadAll: Bool = true) async {
        let hadExistingData = !receipts.isEmpty
        if reset {
            // Only show loading skeleton if no existing data (avoids flash during refresh)
            if !hadExistingData {
                state = .loading
            }
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
                withAnimation(.easeInOut(duration: 0.3)) {
                    receipts = response.receipts
                }
            } else {
                receipts.append(contentsOf: response.receipts)
            }

            totalPages = response.totalPages
            totalCount = response.total
            hasMorePages = response.page < response.totalPages
            state = .success(receipts)

            // Auto-load remaining pages unless caller opted for lazy pagination
            if loadAll && reset && hasMorePages {
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

    /// Apply preloaded receipts from BudgetTabPreloadCache (skips API call)
    func applyPreloadedReceipts(_ receipts: [APIReceipt]) {
        self.receipts = receipts
        self.state = .success(receipts)
        self.hasMorePages = false
    }

    /// Load next page of receipts (always single-page, never auto-loads all)
    func loadNextPage(period: String, storeName: String? = nil) async {
        guard hasMorePages else { return }
        currentPage += 1
        await loadReceipts(period: period, storeName: storeName, reset: false, loadAll: false)
    }

    /// Refresh receipts
    func refresh(period: String, storeName: String? = nil) async {
        await loadReceipts(period: period, storeName: storeName, reset: true)
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
