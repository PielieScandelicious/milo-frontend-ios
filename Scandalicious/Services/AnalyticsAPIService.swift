//
//  AnalyticsAPIService.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 20/01/2026.
//

import Foundation
import FirebaseAuth

// MARK: - API Errors

enum AnalyticsAPIError: LocalizedError {
    case invalidURL
    case noAuthToken
    case unauthorized
    case notFound
    case serverError(String)
    case decodingError(String)
    case networkError(Error)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .noAuthToken:
            return "No authentication token available"
        case .unauthorized:
            return "Unauthorized - please sign in again"
        case .notFound:
            return "Resource not found"
        case .serverError(let message):
            return "Server error: \(message)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid server response"
        }
    }
}

// MARK: - Analytics API Service

actor AnalyticsAPIService {
    static let shared = AnalyticsAPIService()

    private var baseURL: String { AppConfiguration.apiBase }
    private let decoder: JSONDecoder
    
    private init() {
        self.decoder = JSONDecoder()
    }
    
    // MARK: - Analytics Endpoints
    
    /// Fetch spending trends over time
    /// - Parameters:
    ///   - periodType: Type of period (week, month, year)
    ///   - numPeriods: Number of periods to fetch (1-52, default 12)
    ///   - storeName: Optional store name to filter trends for a specific store
    func fetchTrends(periodType: PeriodType = .month, numPeriods: Int = 12, storeName: String? = nil) async throws -> TrendsResponse {
        var queryItems = [
            URLQueryItem(name: "period_type", value: periodType.rawValue),
            URLQueryItem(name: "num_periods", value: String(min(max(numPeriods, 1), 52)))
        ]

        if let storeName = storeName {
            queryItems.append(URLQueryItem(name: "store_name", value: storeName))
        }

        return try await performRequest(
            endpoint: "/analytics/trends",
            queryItems: queryItems
        )
    }
    
    /// Fetch category breakdown for spending
    /// - Parameter filters: Analytics filters for period, dates, and store
    func fetchCategories(filters: AnalyticsFilters = AnalyticsFilters()) async throws -> CategoriesResponse {
        return try await performRequest(
            endpoint: "/analytics/categories",
            queryItems: filters.toQueryItems()
        )
    }
    
    /// Fetch summary with store breakdown
    /// - Parameter filters: Analytics filters for period and dates
    /// Note: Backend now requires month and year parameters instead of start_date/end_date
    func fetchSummary(filters: AnalyticsFilters = AnalyticsFilters()) async throws -> SummaryResponse {
        // Extract month and year from filters
        let date = filters.startDate ?? Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)

        let queryItems = [
            URLQueryItem(name: "month", value: String(month)),
            URLQueryItem(name: "year", value: String(year))
        ]

        return try await performRequest(
            endpoint: "/analytics/summary",
            queryItems: queryItems
        )
    }
    
    /// Fetch detailed breakdown for a specific store
    /// - Parameters:
    ///   - storeName: Name of the store
    ///   - filters: Analytics filters for period and dates
    func fetchStoreDetails(storeName: String, filters: AnalyticsFilters = AnalyticsFilters()) async throws -> StoreDetailsResponse {
        return try await performRequest(
            endpoint: "/analytics/stores/\(storeName)",
            queryItems: filters.toQueryItems()
        )
    }

    /// Fetch spending trends for a specific store
    /// - Parameters:
    ///   - storeName: Name of the store
    ///   - periodType: Type of period (week, month, year)
    ///   - numPeriods: Number of periods to fetch (1-52, default 6)
    func fetchStoreTrends(storeName: String, periodType: PeriodType = .month, numPeriods: Int = 6) async throws -> TrendsResponse {
        // URL encode the store name to handle special characters (spaces, &, etc.)
        guard let encodedStoreName = storeName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw AnalyticsAPIError.invalidURL
        }

        let queryItems = [
            URLQueryItem(name: "period_type", value: periodType.rawValue),
            URLQueryItem(name: "num_periods", value: String(min(max(numPeriods, 1), 52)))
        ]

        return try await performRequest(
            endpoint: "/analytics/stores/\(encodedStoreName)/trends",
            queryItems: queryItems
        )
    }

    /// Fetch paginated list of transactions
    /// - Parameter filters: Transaction filters including pagination
    func fetchTransactions(filters: TransactionFilters = TransactionFilters()) async throws -> TransactionsResponse {
        return try await performRequest(
            endpoint: "/transactions",
            queryItems: filters.toQueryItems()
        )
    }

    /// Fetch list of scanned receipts
    /// - Parameter filters: Receipt filters including pagination
    func fetchReceipts(filters: ReceiptFilters = ReceiptFilters()) async throws -> ReceiptsListResponse {
        return try await performRequest(
            endpoint: "/receipts",
            queryItems: filters.toQueryItems()
        )
    }

    /// Fetch lightweight period metadata for fast initial loading
    /// - Parameters:
    ///   - periodType: Period type (week, month, year). Defaults to month.
    ///   - numPeriods: Number of periods to fetch (1-52, default 52)
    func fetchPeriods(periodType: PeriodType = .month, numPeriods: Int = 52) async throws -> PeriodsResponse {
        let queryItems = [
            URLQueryItem(name: "period_type", value: periodType.rawValue),
            URLQueryItem(name: "num_periods", value: String(min(max(numPeriods, 1), 52)))
        ]

        return try await performRequest(
            endpoint: "/analytics/periods",
            queryItems: queryItems
        )
    }

    /// Fetch aggregate analytics across multiple periods
    /// Returns totals, averages, extremes, top categories/stores, and health score distribution
    /// - Parameter filters: Aggregate filters for period type, limits, and date range
    func fetchAggregate(filters: AggregateFilters = AggregateFilters()) async throws -> AggregateResponse {
        return try await performRequest(
            endpoint: "/analytics/aggregate",
            queryItems: filters.toQueryItems()
        )
    }

    /// Fetch all-time statistics for the user (for scan view hero cards)
    /// Returns total receipts, items, spend, top stores, and top categories across all time
    /// - Parameters:
    ///   - topStoresLimit: Number of top stores to return (default 3)
    ///   - topCategoriesLimit: Number of top categories to return (default 5)
    func fetchAllTimeStats(topStoresLimit: Int = 3, topCategoriesLimit: Int = 5) async throws -> AllTimeStatsResponse {
        let queryItems = [
            URLQueryItem(name: "top_stores_limit", value: String(topStoresLimit)),
            URLQueryItem(name: "top_categories_limit", value: String(topCategoriesLimit))
        ]

        return try await performRequest(
            endpoint: "/analytics/all-time",
            queryItems: queryItems
        )
    }

    /// Fetch year summary statistics
    /// Returns total spend, stores breakdown, and monthly breakdown for a specific year
    /// - Parameters:
    ///   - year: The year to fetch data for (e.g., 2025)
    ///   - includeMonthlyBreakdown: Whether to include monthly spend breakdown (default true)
    ///   - topCategoriesLimit: Number of top categories to return (default 5)
    func fetchYearSummary(year: Int, includeMonthlyBreakdown: Bool = true, topCategoriesLimit: Int = 5) async throws -> YearSummaryResponse {
        var queryItems = [
            URLQueryItem(name: "include_monthly_breakdown", value: String(includeMonthlyBreakdown)),
            URLQueryItem(name: "top_categories_limit", value: String(topCategoriesLimit))
        ]

        return try await performRequest(
            endpoint: "/analytics/year/\(year)",
            queryItems: queryItems
        )
    }

    /// Fetch pie chart summary for category spending breakdown
    /// Returns category spending data for a specific month/year
    /// - Parameters:
    ///   - month: Month (1-12)
    ///   - year: Year (2020-2100)
    func fetchPieChartSummary(month: Int, year: Int) async throws -> PieChartSummaryResponse {
        let queryItems = [
            URLQueryItem(name: "month", value: String(month)),
            URLQueryItem(name: "year", value: String(year))
        ]

        return try await performRequest(
            endpoint: "/analytics/summary",
            queryItems: queryItems
        )
    }

    /// Delete a receipt by ID
    /// - Parameter receiptId: The receipt ID to delete
    func deleteReceipt(receiptId: String) async throws {
        let endpoint = "/receipts/\(receiptId)"

        // Build URL
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw AnalyticsAPIError.invalidURL
        }

        print("🗑️ API Delete Request: DELETE \(url.absoluteString)")

        // Get auth token
        let token = try await getAuthToken()

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        // Perform request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnalyticsAPIError.invalidResponse
        }

        print("📥 Delete response: HTTP \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200...299:
            print("✅ Receipt deleted successfully")
            return

        case 401:
            throw AnalyticsAPIError.unauthorized

        case 404:
            throw AnalyticsAPIError.notFound

        default:
            let errorMessage = parseErrorMessage(from: data) ?? "Delete failed: \(httpResponse.statusCode)"
            throw AnalyticsAPIError.serverError(errorMessage)
        }
    }

    /// Delete a specific line item from a receipt
    /// - Parameters:
    ///   - receiptId: The receipt ID containing the item
    ///   - itemId: The item ID to delete
    func deleteReceiptItem(receiptId: String, itemId: String) async throws -> DeleteReceiptItemResponse {
        let endpoint = "/receipts/\(receiptId)/items/\(itemId)"

        // Build URL
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw AnalyticsAPIError.invalidURL
        }

        print("🗑️ API Delete Item Request: DELETE \(url.absoluteString)")

        // Get auth token
        let token = try await getAuthToken()

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        // Perform request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnalyticsAPIError.invalidResponse
        }

        print("📥 Delete item response: HTTP \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200...299:
            print("✅ Receipt item deleted successfully")
            do {
                let decodedResponse = try decoder.decode(DeleteReceiptItemResponse.self, from: data)
                return decodedResponse
            } catch {
                // If response can't be decoded, return a default success response
                return DeleteReceiptItemResponse(success: true, message: "Item deleted successfully", updatedTotalAmount: nil, updatedItemsCount: nil, updatedAverageHealthScore: nil, receiptDeleted: nil)
            }

        case 401:
            throw AnalyticsAPIError.unauthorized

        case 404:
            throw AnalyticsAPIError.notFound

        default:
            let errorMessage = parseErrorMessage(from: data) ?? "Delete item failed: \(httpResponse.statusCode)"
            throw AnalyticsAPIError.serverError(errorMessage)
        }
    }

    /// Delete transactions for a specific store within a time period
    /// - Parameters:
    ///   - storeName: Name of the store
    ///   - period: Period type (week, month, year)
    ///   - startDate: Start date for the period
    ///   - endDate: End date for the period
    func deleteTransactions(storeName: String, period: String, startDate: String, endDate: String) async throws -> DeleteTransactionsResponse {
        let requestBody = DeleteTransactionsRequest(
            storeName: storeName,
            period: period,
            startDate: startDate,
            endDate: endDate
        )

        return try await performRequestWithBody(
            endpoint: "/transactions",
            method: "DELETE",
            body: requestBody
        )
    }

    /// Delete a single transaction by ID
    /// - Parameter transactionId: The transaction ID to delete
    func deleteTransaction(transactionId: String) async throws {
        let endpoint = "/transactions/\(transactionId)"

        // Build URL
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw AnalyticsAPIError.invalidURL
        }

        print("🗑️ API Delete Transaction Request: DELETE \(url.absoluteString)")

        // Get auth token
        let token = try await getAuthToken()

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        // Perform request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnalyticsAPIError.invalidResponse
        }

        print("📥 Delete transaction response: HTTP \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200...299:
            print("✅ Transaction deleted successfully")
            return

        case 401:
            throw AnalyticsAPIError.unauthorized

        case 404:
            throw AnalyticsAPIError.notFound

        default:
            let errorMessage = parseErrorMessage(from: data) ?? "Delete failed: \(httpResponse.statusCode)"
            throw AnalyticsAPIError.serverError(errorMessage)
        }
    }

    // MARK: - Helper Methods
    
    private func performRequest<T: Decodable>(
        endpoint: String,
        queryItems: [URLQueryItem] = [],
        method: String = "GET"
    ) async throws -> T {
        // Build URL
        guard var urlComponents = URLComponents(string: "\(baseURL)\(endpoint)") else {
            throw AnalyticsAPIError.invalidURL
        }
        
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            throw AnalyticsAPIError.invalidURL
        }
        
        // Log the request
        print("📡 API Request: \(method) \(url.absoluteString)")
        
        // Get auth token
        let token = try await getAuthToken()
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        
        // Perform request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AnalyticsAPIError.invalidResponse
            }
            
            // Handle status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success - decode response
                do {
                    let decodedResponse = try decoder.decode(T.self, from: data)
                    return decodedResponse
                } catch let decodingError as DecodingError {
                    // Log detailed decoding error
                    logDecodingError(decodingError, data: data, endpoint: endpoint)
                    throw AnalyticsAPIError.decodingError(decodingError.localizedDescription)
                }
                
            case 401:
                // Unauthorized
                throw AnalyticsAPIError.unauthorized
                
            case 404:
                // Not found
                throw AnalyticsAPIError.notFound
                
            case 400...499:
                // Client error
                let errorMessage = parseErrorMessage(from: data) ?? "Client error: \(httpResponse.statusCode)"
                throw AnalyticsAPIError.serverError(errorMessage)
                
            case 500...599:
                // Server error
                let errorMessage = parseErrorMessage(from: data) ?? "Server error: \(httpResponse.statusCode)"
                throw AnalyticsAPIError.serverError(errorMessage)
                
            default:
                throw AnalyticsAPIError.serverError("Unexpected status code: \(httpResponse.statusCode)")
            }
            
        } catch let error as AnalyticsAPIError {
            throw error
        } catch {
            throw AnalyticsAPIError.networkError(error)
        }
    }

    private func performRequestWithBody<T: Decodable, B: Encodable>(
        endpoint: String,
        method: String,
        body: B
    ) async throws -> T {
        // Build URL
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw AnalyticsAPIError.invalidURL
        }

        // Log the request
        print("📡 API Request: \(method) \(url.absoluteString)")

        // Get auth token
        let token = try await getAuthToken()

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        // Encode body
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        // Perform request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AnalyticsAPIError.invalidResponse
            }

            // Handle status codes
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    let decodedResponse = try decoder.decode(T.self, from: data)
                    return decodedResponse
                } catch let decodingError as DecodingError {
                    logDecodingError(decodingError, data: data, endpoint: endpoint)
                    throw AnalyticsAPIError.decodingError(decodingError.localizedDescription)
                }

            case 401:
                throw AnalyticsAPIError.unauthorized

            case 404:
                throw AnalyticsAPIError.notFound

            case 400...499:
                let errorMessage = parseErrorMessage(from: data) ?? "Client error: \(httpResponse.statusCode)"
                throw AnalyticsAPIError.serverError(errorMessage)

            case 500...599:
                let errorMessage = parseErrorMessage(from: data) ?? "Server error: \(httpResponse.statusCode)"
                throw AnalyticsAPIError.serverError(errorMessage)

            default:
                throw AnalyticsAPIError.serverError("Unexpected status code: \(httpResponse.statusCode)")
            }

        } catch let error as AnalyticsAPIError {
            throw error
        } catch {
            throw AnalyticsAPIError.networkError(error)
        }
    }

    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AnalyticsAPIError.noAuthToken
        }
        
        do {
            let token = try await user.getIDToken()
            return token
        } catch {
            throw AnalyticsAPIError.unauthorized
        }
    }
    
    private func parseErrorMessage(from data: Data) -> String? {
        if let errorDict = try? JSONDecoder().decode([String: String].self, from: data) {
            return errorDict["error"] ?? errorDict["message"]
        }
        return nil
    }
    
    private func logDecodingError(_ error: DecodingError, data: Data, endpoint: String) {
        print("❌ Decoding error for endpoint: \(endpoint)")
        
        // Print raw response
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📄 Raw server response:\n\(jsonString)")
        }
        
        // Print detailed error info
        switch error {
        case .keyNotFound(let key, let context):
            print("🔑 Missing key '\(key.stringValue)'")
            print("📍 Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            print("ℹ️  \(context.debugDescription)")
            
        case .typeMismatch(let type, let context):
            print("⚠️ Type mismatch for type '\(type)'")
            print("📍 Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            print("ℹ️  \(context.debugDescription)")
            
        case .valueNotFound(let type, let context):
            print("❓ Value not found for type '\(type)'")
            print("📍 Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            print("ℹ️  \(context.debugDescription)")
            
        case .dataCorrupted(let context):
            print("💥 Data corrupted")
            print("📍 Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            print("ℹ️  \(context.debugDescription)")
            
        @unknown default:
            print("❔ Unknown decoding error")
        }
    }
}

// MARK: - Nonisolated Convenience Methods

extension AnalyticsAPIService {
    /// Nonisolated wrapper for fetchTrends
    nonisolated func getTrends(periodType: PeriodType = .month, numPeriods: Int = 12, storeName: String? = nil) async throws -> TrendsResponse {
        return try await fetchTrends(periodType: periodType, numPeriods: numPeriods, storeName: storeName)
    }
    
    /// Nonisolated wrapper for fetchCategories
    nonisolated func getCategories(filters: AnalyticsFilters = AnalyticsFilters()) async throws -> CategoriesResponse {
        return try await fetchCategories(filters: filters)
    }
    
    /// Nonisolated wrapper for fetchSummary
    nonisolated func getSummary(filters: AnalyticsFilters = AnalyticsFilters()) async throws -> SummaryResponse {
        return try await fetchSummary(filters: filters)
    }
    
    /// Nonisolated wrapper for fetchStoreDetails
    nonisolated func getStoreDetails(storeName: String, filters: AnalyticsFilters = AnalyticsFilters()) async throws -> StoreDetailsResponse {
        return try await fetchStoreDetails(storeName: storeName, filters: filters)
    }

    /// Nonisolated wrapper for fetchStoreTrends
    nonisolated func getStoreTrends(storeName: String, periodType: PeriodType = .month, numPeriods: Int = 6) async throws -> TrendsResponse {
        return try await fetchStoreTrends(storeName: storeName, periodType: periodType, numPeriods: numPeriods)
    }

    /// Nonisolated wrapper for fetchTransactions
    nonisolated func getTransactions(filters: TransactionFilters = TransactionFilters()) async throws -> TransactionsResponse {
        return try await fetchTransactions(filters: filters)
    }

    /// Nonisolated wrapper for deleteTransactions
    nonisolated func removeTransactions(storeName: String, period: String, startDate: String, endDate: String) async throws -> DeleteTransactionsResponse {
        return try await deleteTransactions(storeName: storeName, period: period, startDate: startDate, endDate: endDate)
    }

    /// Nonisolated wrapper for deleteReceipt
    nonisolated func removeReceipt(receiptId: String) async throws {
        return try await deleteReceipt(receiptId: receiptId)
    }

    /// Nonisolated wrapper for deleteTransaction
    nonisolated func removeTransaction(transactionId: String) async throws {
        return try await deleteTransaction(transactionId: transactionId)
    }

    /// Nonisolated wrapper for deleteReceiptItem
    nonisolated func removeReceiptItem(receiptId: String, itemId: String) async throws -> DeleteReceiptItemResponse {
        return try await deleteReceiptItem(receiptId: receiptId, itemId: itemId)
    }

    /// Nonisolated wrapper for fetchReceipts
    nonisolated func getReceipts(filters: ReceiptFilters = ReceiptFilters()) async throws -> ReceiptsListResponse {
        return try await fetchReceipts(filters: filters)
    }

    /// Nonisolated wrapper for fetchPeriods
    nonisolated func getPeriods(periodType: PeriodType = .month, numPeriods: Int = 52) async throws -> PeriodsResponse {
        return try await fetchPeriods(periodType: periodType, numPeriods: numPeriods)
    }

    /// Nonisolated wrapper for fetchAggregate
    nonisolated func getAggregate(filters: AggregateFilters = AggregateFilters()) async throws -> AggregateResponse {
        return try await fetchAggregate(filters: filters)
    }

    /// Nonisolated wrapper for fetchAllTimeStats
    nonisolated func getAllTimeStats(topStoresLimit: Int = 3, topCategoriesLimit: Int = 5) async throws -> AllTimeStatsResponse {
        return try await fetchAllTimeStats(topStoresLimit: topStoresLimit, topCategoriesLimit: topCategoriesLimit)
    }

    /// Nonisolated wrapper for fetchYearSummary
    nonisolated func getYearSummary(year: Int, includeMonthlyBreakdown: Bool = true, topCategoriesLimit: Int = 5) async throws -> YearSummaryResponse {
        return try await fetchYearSummary(year: year, includeMonthlyBreakdown: includeMonthlyBreakdown, topCategoriesLimit: topCategoriesLimit)
    }

    /// Nonisolated wrapper for fetchPieChartSummary
    nonisolated func getPieChartSummary(month: Int, year: Int) async throws -> PieChartSummaryResponse {
        return try await fetchPieChartSummary(month: month, year: year)
    }
}

// MARK: - Delete Transactions Models

struct DeleteTransactionsRequest: Encodable {
    let storeName: String
    let period: String
    let startDate: String
    let endDate: String
}

struct DeleteTransactionsResponse: Decodable {
    let success: Bool
    let deletedCount: Int
    let message: String

    enum CodingKeys: String, CodingKey {
        case success
        case deletedCount = "deleted_count"
        case message
    }
}

struct DeleteReceiptItemResponse: Decodable {
    let success: Bool
    let message: String
    let updatedTotalAmount: Double?
    let updatedItemsCount: Int?
    let updatedAverageHealthScore: Double?
    let receiptDeleted: Bool?

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case updatedTotalAmount = "updated_total_amount"
        case updatedItemsCount = "updated_items_count"
        case updatedAverageHealthScore = "updated_average_health_score"
        case receiptDeleted = "receipt_deleted"
    }
}
