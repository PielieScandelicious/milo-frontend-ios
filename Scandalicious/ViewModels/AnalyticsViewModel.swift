//
//  AnalyticsViewModel.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 20/01/2026.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Loading State

enum LoadingState<T> {
    case idle
    case loading
    case success(T)
    case error(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var error: String? {
        if case .error(let message) = self { return message }
        return nil
    }

    var value: T? {
        if case .success(let value) = self { return value }
        return nil
    }
}

// MARK: - Transactions ViewModel

@MainActor
class TransactionsViewModel: ObservableObject {
    @Published var state: LoadingState<TransactionsResponse> = .idle
    @Published var filters: TransactionFilters = TransactionFilters()
    @Published var transactions: [APITransaction] = []
    @Published var hasMorePages = false

    private let apiService = AnalyticsAPIService.shared

    func loadTransactions(reset: Bool = false) async {
        if reset {
            filters.page = 1
            transactions = []
        }

        state = .loading

        do {
            let response = try await apiService.getTransactions(filters: filters)

            if reset {
                transactions = response.transactions
            } else {
                transactions.append(contentsOf: response.transactions)
            }

            hasMorePages = response.page < response.totalPages
            state = .success(response)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func loadNextPage() async {
        guard hasMorePages else { return }
        filters.page += 1
        await loadTransactions(reset: false)
    }

    func refresh() async {
        await loadTransactions(reset: true)
    }

    func updateFilters(_ newFilters: TransactionFilters) async {
        filters = newFilters
        filters.page = 1
        await loadTransactions(reset: true)
    }

    func updateDateRange(start: Date?, end: Date?) async {
        filters.startDate = start
        filters.endDate = end
        filters.page = 1
        await loadTransactions(reset: true)
    }

    func updateStore(_ storeName: String?) async {
        filters.storeName = storeName
        filters.page = 1
        await loadTransactions(reset: true)
    }

    func updateCategory(_ category: String?) async {
        filters.category = category
        filters.page = 1
        await loadTransactions(reset: true)
    }

    func clearFilters() async {
        filters = TransactionFilters()
        await loadTransactions(reset: true)
    }

}
