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

// MARK: - Trends ViewModel

@MainActor
class TrendsViewModel: ObservableObject {
    @Published var state: LoadingState<TrendsResponse> = .idle
    @Published var filters: AnalyticsFilters = AnalyticsFilters()
    
    private let apiService = AnalyticsAPIService.shared
    
    func loadTrends() async {
        state = .loading
        
        do {
            let response = try await apiService.getTrends(
                periodType: filters.period,
                numPeriods: filters.numPeriods
            )
            state = .success(response)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    func refresh() async {
        await loadTrends()
    }
    
    func updatePeriod(_ period: PeriodType) async {
        filters.period = period
        await loadTrends()
    }
    
    func updateNumPeriods(_ numPeriods: Int) async {
        filters.numPeriods = numPeriods
        await loadTrends()
    }
}

// MARK: - Categories ViewModel

@MainActor
class CategoriesViewModel: ObservableObject {
    @Published var state: LoadingState<CategoriesResponse> = .idle
    @Published var filters: AnalyticsFilters = AnalyticsFilters()
    
    private let apiService = AnalyticsAPIService.shared
    
    func loadCategories() async {
        state = .loading
        
        do {
            let response = try await apiService.getCategories(filters: filters)
            state = .success(response)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    func refresh() async {
        await loadCategories()
    }
    
    func updateFilters(_ newFilters: AnalyticsFilters) async {
        filters = newFilters
        await loadCategories()
    }
    
    func updatePeriod(_ period: PeriodType) async {
        filters.period = period
        await loadCategories()
    }
    
    func updateDateRange(start: Date?, end: Date?) async {
        filters.startDate = start
        filters.endDate = end
        await loadCategories()
    }
    
    func updateStore(_ storeName: String?) async {
        filters.storeName = storeName
        await loadCategories()
    }
}

// MARK: - Summary ViewModel

@MainActor
class SummaryViewModel: ObservableObject {
    @Published var state: LoadingState<SummaryResponse> = .idle
    @Published var filters: AnalyticsFilters = AnalyticsFilters()
    
    private let apiService = AnalyticsAPIService.shared
    
    func loadSummary() async {
        state = .loading
        
        do {
            let response = try await apiService.getSummary(filters: filters)
            state = .success(response)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    func refresh() async {
        await loadSummary()
    }
    
    func updateFilters(_ newFilters: AnalyticsFilters) async {
        filters = newFilters
        await loadSummary()
    }
    
    func updatePeriod(_ period: PeriodType) async {
        filters.period = period
        await loadSummary()
    }
    
    func updateDateRange(start: Date?, end: Date?) async {
        filters.startDate = start
        filters.endDate = end
        await loadSummary()
    }
}

// MARK: - Store Details ViewModel

@MainActor
class StoreDetailsViewModel: ObservableObject {
    @Published var state: LoadingState<StoreDetailsResponse> = .idle
    @Published var filters: AnalyticsFilters = AnalyticsFilters()
    @Published var storeName: String
    
    private let apiService = AnalyticsAPIService.shared
    
    init(storeName: String) {
        self.storeName = storeName
    }
    
    func loadStoreDetails() async {
        state = .loading
        
        do {
            let response = try await apiService.getStoreDetails(
                storeName: storeName,
                filters: filters
            )
            state = .success(response)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    func refresh() async {
        await loadStoreDetails()
    }
    
    func updateFilters(_ newFilters: AnalyticsFilters) async {
        filters = newFilters
        await loadStoreDetails()
    }
    
    func updatePeriod(_ period: PeriodType) async {
        filters.period = period
        await loadStoreDetails()
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
    private var notificationObserver: NSObjectProtocol?

    init() {
        // Listen for data change notifications
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .receiptsDataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

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

            // Debug: Log transaction totals
            let sumItemPrice = transactions.reduce(0) { $0 + $1.itemPrice }
            let sumTotalPrice = transactions.reduce(0) { $0 + $1.totalPrice }
            let sumQuantity = transactions.reduce(0) { $0 + $1.quantity }
            print("📊 Transaction Debug (page \(response.page)/\(response.totalPages), total: \(response.total)):")
            print("   Sum of itemPrice: €\(String(format: "%.2f", sumItemPrice))")
            print("   Sum of totalPrice (itemPrice × qty): €\(String(format: "%.2f", sumTotalPrice))")
            print("   Total quantity: \(sumQuantity)")
            print("   Transaction count loaded: \(transactions.count)")
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
    
    func updateCategory(_ category: AnalyticsCategory?) async {
        filters.category = category
        filters.page = 1
        await loadTransactions(reset: true)
    }
    
    func clearFilters() async {
        filters = TransactionFilters()
        await loadTransactions(reset: true)
    }
}

// MARK: - Data Refresh Notification

extension Notification.Name {
    static let receiptsDataDidChange = Notification.Name("receiptsDataDidChange")
}

// MARK: - Combined Analytics ViewModel

@MainActor
class AnalyticsViewModel: ObservableObject {
    // Child ViewModels
    let trends = TrendsViewModel()
    let categories = CategoriesViewModel()
    let summary = SummaryViewModel()

    private var notificationObserver: NSObjectProtocol?

    @Published var selectedPeriod: PeriodType = .month {
        didSet {
            Task {
                await updateAllPeriods()
            }
        }
    }

    @Published var dateRange: (start: Date?, end: Date?) = (nil, nil) {
        didSet {
            Task {
                await updateAllDateRanges()
            }
        }
    }

    init() {
        // Listen for data change notifications
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .receiptsDataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func loadAll() async {
        async let trendsTask = trends.loadTrends()
        async let categoriesTask = categories.loadCategories()
        async let summaryTask = summary.loadSummary()
        
        await trendsTask
        await categoriesTask
        await summaryTask
    }
    
    func refresh() async {
        await loadAll()
    }
    
    private func updateAllPeriods() async {
        async let trendsTask = trends.updatePeriod(selectedPeriod)
        async let categoriesTask = categories.updatePeriod(selectedPeriod)
        async let summaryTask = summary.updatePeriod(selectedPeriod)
        
        await trendsTask
        await categoriesTask
        await summaryTask
    }
    
    private func updateAllDateRanges() async {
        async let categoriesTask = categories.updateDateRange(start: dateRange.start, end: dateRange.end)
        async let summaryTask = summary.updateDateRange(start: dateRange.start, end: dateRange.end)
        
        await categoriesTask
        await summaryTask
    }
}
