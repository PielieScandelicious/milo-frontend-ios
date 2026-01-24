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
    func loadReceipts(period: String, storeName: String? = nil, reset: Bool = true) async {
        if reset {
            state = .loading
            receipts = []
            currentPage = 1
        }

        // Parse period to get date range
        let (startDate, endDate) = parsePeriod(period)

        // Configure filters
        filters = ReceiptFilters()
        filters.startDate = startDate
        filters.endDate = endDate
        filters.page = currentPage
        filters.pageSize = 20

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

        } catch {
            state = .error(error.localizedDescription)
        }
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
        // Delete from server
        try await apiService.removeReceipt(receiptId: receipt.receiptId)

        // Remove from local array - notify observers explicitly
        objectWillChange.send()
        receipts.removeAll { $0.receiptId == receipt.receiptId }
        state = .success(receipts)

        // Notify other views to refresh their data
        NotificationCenter.default.post(name: .receiptsDataDidChange, object: nil)
    }

    // MARK: - Private Helpers

    private func parsePeriod(_ period: String) -> (Date?, Date?) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = dateFormatter.date(from: period) else {
            return (nil, nil)
        }

        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))

        var endComponents = DateComponents()
        endComponents.month = 1
        endComponents.second = -1
        let endOfMonth = calendar.date(byAdding: endComponents, to: startOfMonth ?? date)

        return (startOfMonth, endOfMonth)
    }
}
