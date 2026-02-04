//
//  BankingViewModel.swift
//  Scandalicious
//
//  Created by Claude on 01/02/2026.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Banking Loading State

enum BankingLoadingState<T> {
    case idle
    case loading
    case success(T)
    case error(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var data: T? {
        if case .success(let data) = self { return data }
        return nil
    }

    var errorMessage: String? {
        if case .error(let message) = self { return message }
        return nil
    }
}

// MARK: - Banking ViewModel

@MainActor
class BankingViewModel: ObservableObject {
    // MARK: - Published State

    // Country & Bank Selection
    @Published var selectedCountry: BankingCountry = BankingCountry.defaultCountry
    @Published var banksState: BankingLoadingState<[BankInfo]> = .idle
    @Published var bankSearchQuery = ""

    // Connections
    @Published var connectionsState: BankingLoadingState<[BankConnectionResponse]> = .idle

    // Accounts
    @Published var accountsState: BankingLoadingState<[BankAccountResponse]> = .idle
    @Published var syncingAccountIds: Set<String> = []

    // Transactions for review
    @Published var pendingTransactionsState: BankingLoadingState<[BankTransactionResponse]> = .idle
    @Published var selectedTransactionIds: Set<String> = []
    @Published var categoryOverrides: [String: GroceryCategory] = [:]
    @Published var descriptionOverrides: [String: String] = [:]
    @Published var pendingTransactionsTotal: Int = 0

    // Notification State
    @Published var showPendingTransactionsNotification = false
    @Published var hasShownNotificationForCurrentBatch = false

    // UI State
    @Published var isImporting = false
    @Published var isIgnoring = false
    @Published var showingDeleteConfirmation = false
    @Published var connectionToDelete: BankConnectionResponse?
    @Published var showingConnectionSuccess = false
    @Published var lastConnectionResult: BankingCallbackResult?
    @Published var showingError = false
    @Published var errorMessage: String?

    // OAuth State
    @Published var pendingConnectionId: String?
    @Published var isAwaitingCallback = false
    @Published var isConnecting = false

    // Reauth State
    @Published var showingReauthPrompt = false
    @Published var connectionNeedingReauth: BankConnectionResponse?

    // Navigation
    @Published var showingCountryPicker = false
    @Published var showingBankSelection = false
    @Published var showingTransactionReview = false

    // MARK: - Computed Properties

    var filteredBanks: [BankInfo] {
        guard let banks = banksState.data else { return [] }
        if bankSearchQuery.isEmpty { return banks }
        return banks.filter { $0.name.localizedCaseInsensitiveContains(bankSearchQuery) }
    }

    var hasConnections: Bool {
        guard let connections = connectionsState.data else { return false }
        return !connections.isEmpty
    }

    var activeConnections: [BankConnectionResponse] {
        guard let connections = connectionsState.data else { return [] }
        return connections.filter { $0.status == .active }
    }

    var accountsByConnection: [String: [BankAccountResponse]] {
        guard let accounts = accountsState.data else { return [:] }
        return Dictionary(grouping: accounts, by: { $0.connectionId })
    }

    var selectedTransactionsCount: Int {
        selectedTransactionIds.count
    }

    var allTransactionsSelected: Bool {
        guard let transactions = pendingTransactionsState.data else { return false }
        return selectedTransactionIds.count == transactions.count && !transactions.isEmpty
    }

    var hasPendingTransactions: Bool {
        pendingTransactionsTotal > 0
    }

    // MARK: - Private Properties

    private let apiService = BankingAPIService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupNotificationObservers()
    }

    private func setupNotificationObservers() {
        // Deep link callbacks
        NotificationCenter.default.publisher(for: .bankConnectionCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let result = notification.userInfo?["result"] as? BankingCallbackResult {
                    self?.handleConnectionCallback(result)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .bankConnectionFailed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let result = notification.userInfo?["result"] as? BankingCallbackResult {
                    self?.handleConnectionCallback(result)
                }
            }
            .store(in: &cancellables)

        // Auto-sync notification - new transactions found
        NotificationCenter.default.publisher(for: .bankTransactionsPendingReview)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleAutoSyncNotification(notification)
            }
            .store(in: &cancellables)
    }

    /// Handle notification when auto-sync finds new transactions
    private func handleAutoSyncNotification(_ notification: Notification) {
        let newCount = notification.userInfo?["newTransactions"] as? Int ?? 0
        let totalPending = notification.userInfo?["totalPending"] as? Int ?? 0
        let shouldNavigate = notification.userInfo?["shouldNavigate"] as? Bool ?? false

        // Update pending count
        pendingTransactionsTotal = totalPending

        // Show notification banner if there are pending transactions and we have new ones
        // Always show when auto-sync finds new transactions (newCount > 0)
        if totalPending > 0 && (newCount > 0 || !hasShownNotificationForCurrentBatch) {
            showPendingTransactionsNotification = true
            hasShownNotificationForCurrentBatch = true
        }

        // If tapped from push notification with review action, navigate directly
        if shouldNavigate && totalPending > 0 {
            showingTransactionReview = true
            Task {
                await loadPendingTransactions()
            }
        }
    }

    // MARK: - Bank List Methods

    func loadBanks(for country: BankingCountry) async {
        selectedCountry = country
        banksState = .loading
        bankSearchQuery = ""

        do {
            let response = try await apiService.getBanks(country: country.code)
            banksState = .success(response.banks)
        } catch {
            banksState = .error(error.localizedDescription)
            showError(error.localizedDescription)
        }
    }

    func refreshBanks() async {
        await loadBanks(for: selectedCountry)
    }

    // MARK: - Connection Methods

    func loadConnections() async {
        connectionsState = .loading

        do {
            let connections = try await apiService.getConnections()
            connectionsState = .success(connections)
        } catch {
            connectionsState = .error(error.localizedDescription)
        }
    }

    func startBankConnection(bank: BankInfo) async -> URL? {
        isConnecting = true

        do {
            let response = try await apiService.startBankConnection(
                bankName: bank.name,
                country: selectedCountry.code
            )
            pendingConnectionId = response.connectionId
            isAwaitingCallback = true
            isConnecting = false
            return URL(string: response.redirectUrl)
        } catch {
            isConnecting = false
            showError(error.localizedDescription)
            return nil
        }
    }

    func disconnectBank(_ connection: BankConnectionResponse) async -> Bool {
        do {
            try await apiService.disconnectBank(connectionId: connection.id)
            await loadConnections()
            await loadAccounts()
            return true
        } catch {
            showError(error.localizedDescription)
            return false
        }
    }

    func confirmDeleteConnection(_ connection: BankConnectionResponse) {
        connectionToDelete = connection
        showingDeleteConfirmation = true
    }

    func executeDeleteConnection() async {
        guard let connection = connectionToDelete else { return }
        _ = await disconnectBank(connection)
        connectionToDelete = nil
        showingDeleteConfirmation = false
    }

    func handleConnectionCallback(_ result: BankingCallbackResult) {
        isAwaitingCallback = false
        isConnecting = false
        pendingConnectionId = nil
        lastConnectionResult = result

        switch result.status {
        case .success:
            showingConnectionSuccess = true
            showingBankSelection = false
            Task {
                await loadConnections()
                await loadAccounts()

                // Auto-sync all accounts to fetch transactions from the bank
                await syncAllAccounts()

                // Load pending transactions after sync
                await loadPendingTransactions()
            }
        case .error:
            if let message = result.errorMessage {
                showError(message)
            } else {
                showError("Bank connection failed. Please try again.")
            }
        case .cancelled:
            // User cancelled, no error shown
            break
        }
    }

    // MARK: - Account Methods

    func loadAccounts() async {
        accountsState = .loading

        do {
            let accounts = try await apiService.getAccounts()
            accountsState = .success(accounts)
        } catch {
            accountsState = .error(error.localizedDescription)
        }
    }

    func syncAccount(_ accountId: String) async -> Bool {
        guard !syncingAccountIds.contains(accountId) else {
            return false
        }

        syncingAccountIds.insert(accountId)

        do {
            let result = try await apiService.syncAccountTransactions(accountId: accountId)
            syncingAccountIds.remove(accountId)

            // Check if reauth is required
            if result.requiresReauth == true {
                // Find the connection that needs reauth
                if let connectionId = result.connectionId,
                   let connections = connectionsState.data,
                   let connection = connections.first(where: { $0.id == connectionId }) {
                    connectionNeedingReauth = connection
                    showingReauthPrompt = true
                } else {
                    // Reload connections to find it
                    await loadConnections()
                    if let connectionId = result.connectionId,
                       let connections = connectionsState.data,
                       let connection = connections.first(where: { $0.id == connectionId }) {
                        connectionNeedingReauth = connection
                        showingReauthPrompt = true
                    }
                }
                return false
            }

            // Reload accounts to get updated balance
            await loadAccounts()

            // Reload pending transactions
            await loadPendingTransactions()

            // Show notification banner if there are new transactions
            if result.newTransactions > 0 {
                hasShownNotificationForCurrentBatch = false  // Reset so notification shows
                showPendingTransactionsNotification = true
                hasShownNotificationForCurrentBatch = true

                // Haptic feedback for new transactions
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }

            return true
        } catch let error as BankingAPIError {
            syncingAccountIds.remove(accountId)

            // Handle connection expired error
            if case .connectionExpired = error {
                // Find the account's connection
                if let accounts = accountsState.data,
                   let account = accounts.first(where: { $0.id == accountId }),
                   let connections = connectionsState.data,
                   let connection = connections.first(where: { $0.id == account.connectionId }) {
                    connectionNeedingReauth = connection
                    showingReauthPrompt = true
                    return false
                }
            }

            showError(error.localizedDescription)
            return false
        } catch {
            syncingAccountIds.remove(accountId)
            showError(error.localizedDescription)
            return false
        }
    }

    func syncAllAccounts() async {
        guard let accounts = accountsState.data else { return }

        for account in accounts {
            _ = await syncAccount(account.id)
        }
    }

    func isSyncingAccount(_ accountId: String) -> Bool {
        syncingAccountIds.contains(accountId)
    }

    // MARK: - Transaction Methods

    func loadPendingTransactions() async {
        pendingTransactionsState = .loading

        do {
            let response = try await apiService.getPendingTransactions()
            pendingTransactionsState = .success(response.transactions)
            pendingTransactionsTotal = response.total

            // Select all by default for easier bulk import
            selectedTransactionIds = Set(response.transactions.map { $0.id })

            // Note: Notification banner is triggered by BackgroundSyncManager via .bankTransactionsPendingReview
            // notification, not here. This keeps loadPendingTransactions focused on data loading only.
        } catch {
            pendingTransactionsState = .error(error.localizedDescription)
            pendingTransactionsTotal = 0
        }
    }

    func dismissTransactionNotification() {
        showPendingTransactionsNotification = false
    }

    func resetNotificationState() {
        hasShownNotificationForCurrentBatch = false
    }

    func toggleTransactionSelection(_ transactionId: String) {
        if selectedTransactionIds.contains(transactionId) {
            selectedTransactionIds.remove(transactionId)
        } else {
            selectedTransactionIds.insert(transactionId)
        }
    }

    func selectAllTransactions() {
        guard let transactions = pendingTransactionsState.data else { return }
        selectedTransactionIds = Set(transactions.map { $0.id })
    }

    func deselectAllTransactions() {
        selectedTransactionIds.removeAll()
    }

    func setCategoryOverride(for transactionId: String, category: GroceryCategory) {
        categoryOverrides[transactionId] = category
    }

    func getCategory(for transaction: BankTransactionResponse) -> GroceryCategory {
        if let override = categoryOverrides[transaction.id] {
            return override
        }
        if let suggested = transaction.suggestedCategory,
           let category = GroceryCategory.from(string: suggested) {
            return category
        }
        return .other
    }

    func setDescriptionOverride(for transactionId: String, description: String) {
        if description.isEmpty {
            descriptionOverrides.removeValue(forKey: transactionId)
        } else {
            descriptionOverrides[transactionId] = description
        }
    }

    func getDescription(for transaction: BankTransactionResponse) -> String? {
        return descriptionOverrides[transaction.id] ?? transaction.description
    }

    func getCustomDescription(for transactionId: String) -> String? {
        return descriptionOverrides[transactionId]
    }

    func importSelectedTransactions() async -> Bool {
        guard !selectedTransactionIds.isEmpty else {
            return false
        }

        isImporting = true

        // Build import items with categories and descriptions
        let items: [TransactionImportItem] = selectedTransactionIds.compactMap { transactionId in
            guard let transactions = pendingTransactionsState.data,
                  let transaction = transactions.first(where: { $0.id == transactionId }) else {
                return nil
            }

            let category = getCategory(for: transaction)
            let customDescription = descriptionOverrides[transactionId]

            return TransactionImportItem(
                bankTransactionId: transactionId,
                category: category.rawValue,
                storeName: transaction.counterpartyName,
                itemName: customDescription ?? transaction.description
            )
        }

        let request = TransactionImportRequest(transactions: items)

        do {
            let response = try await apiService.importSelectedTransactions(request: request)
            isImporting = false

            // Clear selections and overrides
            selectedTransactionIds.removeAll()
            categoryOverrides.removeAll()
            descriptionOverrides.removeAll()

            // Reset notification state for next batch
            hasShownNotificationForCurrentBatch = false
            showPendingTransactionsNotification = false

            // Reload to get updated pending list
            await loadPendingTransactions()

            // Notify rest of app
            NotificationCenter.default.post(
                name: .bankTransactionsImported,
                object: nil,
                userInfo: ["importedCount": response.importedCount]
            )

            if response.failedCount > 0 {
                showError("\(response.importedCount) imported, \(response.failedCount) failed")
            }

            return response.failedCount == 0
        } catch {
            isImporting = false
            showError(error.localizedDescription)
            return false
        }
    }

    func ignoreSelectedTransactions() async -> Bool {
        guard !selectedTransactionIds.isEmpty else { return false }

        isIgnoring = true

        let request = TransactionIgnoreRequest(transactionIds: Array(selectedTransactionIds))

        do {
            try await apiService.ignoreSelectedTransactions(request: request)
            isIgnoring = false
            selectedTransactionIds.removeAll()
            await loadPendingTransactions()
            return true
        } catch {
            isIgnoring = false
            showError(error.localizedDescription)
            return false
        }
    }

    // MARK: - Reauth Methods

    func dismissReauthPrompt() {
        showingReauthPrompt = false
        connectionNeedingReauth = nil
    }

    func startReauthentication() async -> URL? {
        guard let connection = connectionNeedingReauth else { return nil }

        isConnecting = true
        dismissReauthPrompt()

        do {
            // Start a new connection flow for the same bank
            let response = try await apiService.startBankConnection(
                bankName: connection.aspspName,
                country: connection.aspspCountry
            )
            pendingConnectionId = response.connectionId
            isAwaitingCallback = true
            isConnecting = false
            return URL(string: response.redirectUrl)
        } catch {
            isConnecting = false
            showError(error.localizedDescription)
            return nil
        }
    }

    // MARK: - Navigation Helpers

    func openCountryPicker() {
        showingCountryPicker = true
    }

    func selectCountryAndShowBanks(_ country: BankingCountry) {
        showingCountryPicker = false
        showingBankSelection = true
        Task {
            await loadBanks(for: country)
        }
    }

    func openBankSelection() {
        showingBankSelection = true
        Task {
            await loadBanks(for: selectedCountry)
        }
    }

    func closeBankSelection() {
        showingBankSelection = false
        bankSearchQuery = ""
    }

    func openTransactionReview() {
        showingTransactionReview = true
        Task {
            await loadPendingTransactions()
        }
    }

    func closeTransactionReview() {
        showingTransactionReview = false
    }

    // MARK: - Initial Load

    func loadInitialData() async {
        await loadConnections()
        await loadAccounts()

        // Load pending transactions to show notification if any
        // Note: Auto-sync is handled by BackgroundSyncManager on app launch/foreground
        if hasConnections {
            await loadPendingTransactions()
        }
    }

    func refresh() async {
        await loadConnections()
        await loadAccounts()
        if hasConnections {
            await loadPendingTransactions()
        }
    }

    /// Trigger a manual sync of all accounts
    /// Call this when user explicitly requests a refresh
    func manualSyncAllAccounts() async {
        // Reset notification state so we show banner after sync
        hasShownNotificationForCurrentBatch = false

        await loadConnections()
        await loadAccounts()

        if hasConnections {
            await syncAllAccounts()
            await loadPendingTransactions()

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }

    // MARK: - Error Handling

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }

    func dismissError() {
        showingError = false
        errorMessage = nil
    }
}
