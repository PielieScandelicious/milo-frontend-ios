//
//  BudgetViewModel.swift
//  Scandalicious
//
//  Created by Claude on 31/01/2026.
//  Simplified on 05/02/2026 - Removed AI features
//

import Foundation
import SwiftUI
import Combine

// MARK: - Budget State

enum BudgetState {
    case idle
    case loading
    case noBudget              // User hasn't set a budget yet
    case active(BudgetProgress) // User has an active budget with progress
    case error(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var progress: BudgetProgress? {
        if case .active(let progress) = self { return progress }
        return nil
    }

    var hasBudget: Bool {
        if case .active = self { return true }
        return false
    }
}

// MARK: - Budget ViewModel

@MainActor
class BudgetViewModel: ObservableObject {
    // MARK: - Published State

    @Published var state: BudgetState = .idle
    @Published var forceRefreshTrigger: Int = 0  // Increment to force view refresh

    // Period selection state
    @Published var selectedPeriod: String = ""  // "January 2026" format
    @Published var availablePeriods: [String] = []

    // Setup flow state
    @Published var setupBudgetAmount: Double = 0
    @Published var showingSetupSheet = false
    @Published var isSaving = false
    @Published var saveError: String?

    // Category editing state
    @Published var editingCategoryAllocations: [CategoryAllocation] = []
    @Published var showingCategoryEditor = false

    // MARK: - Budget Suggestion State

    @Published var suggestionState: SimpleLoadingState<SimpleBudgetSuggestionResponse> = .idle

    // Legacy alias for backward compatibility
    var aiSuggestionState: SimpleLoadingState<SimpleBudgetSuggestionResponse> {
        get { suggestionState }
        set { suggestionState = newValue }
    }

    // MARK: - Budget History State

    @Published var budgetHistory: [BudgetHistory] = []
    @Published var isLoadingHistory = false
    @Published var historyError: String?

    // MARK: - Budget Insights State

    @Published var insightsState: SimpleLoadingState<BudgetInsightsResponse> = .idle

    // MARK: - Private Properties

    private let apiService = BudgetAPIService.shared
    private var notificationObserver: NSObjectProtocol?
    private var categoryAllocationsObserver: NSObjectProtocol?

    // Date formatters
    private let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private let apiFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    // MARK: - Initialization

    init() {
        // Initialize periods synchronously so UI can render immediately
        initializePeriodsSync()

        // Listen for data changes that might affect budget progress
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .receiptsDataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshProgress()
            }
        }

        // Listen for category allocation updates
        categoryAllocationsObserver = NotificationCenter.default.addObserver(
            forName: .budgetCategoryAllocationsUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let allocations = notification.userInfo?["allocations"] as? [CategoryAllocation] {
                    let _ = await self?.updateCategoryAllocations(allocations)
                }
            }
        }
    }

    /// Initialize periods synchronously (called from init)
    private func initializePeriodsSync() {
        var periods: [String] = []
        let now = Date()

        for i in (0...5).reversed() {
            if let date = Calendar.current.date(byAdding: .month, value: -i, to: now) {
                periods.append(displayFormatter.string(from: date))
            }
        }

        availablePeriods = periods
        selectedPeriod = displayFormatter.string(from: now)
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = categoryAllocationsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public Methods

    /// Load budget for the current selected period
    func loadBudget() async {
        // Periods are initialized in init(), but double-check
        if availablePeriods.isEmpty {
            initializePeriodsSync()
        }

        // Check for smart budget auto-rollover first (only for current month)
        if isCurrentMonth {
            await checkAndPerformAutoRollover()
        }

        await loadBudgetForPeriod(selectedPeriod)

        // Load budget history in background
        Task {
            await loadBudgetHistory()
        }
    }

    /// Load budget for a specific period
    func loadBudgetForPeriod(_ period: String) async {
        // Check if this is the current month or a past month
        let currentMonthString = displayFormatter.string(from: Date())

        if period == currentMonthString {
            // Current month: Load real-time budget progress
            await loadCurrentMonthProgress()
        } else {
            // Past month: Show no budget state (removed AI monthly report)
            state = .noBudget
        }
    }

    /// Load current month's budget progress (real-time tracking)
    private func loadCurrentMonthProgress() async {
        state = .loading

        do {
            let progressResponse = try await apiService.getBudgetProgress()
            state = .active(progressResponse.toBudgetProgress())
        } catch let error as BudgetAPIError {
            switch error {
            case .noBudgetSet, .notFound:
                state = .noBudget
            default:
                state = .error(error.localizedDescription)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Switch to a different period
    func selectPeriod(_ period: String) async {
        guard period != selectedPeriod else { return }
        selectedPeriod = period
        await loadBudgetForPeriod(period)
    }

    // MARK: - Period Helpers

    /// Convert display format ("January 2026") to API format ("2026-01")
    private func convertToAPIFormat(_ displayPeriod: String) -> String {
        if let date = displayFormatter.date(from: displayPeriod) {
            return apiFormatter.string(from: date)
        }
        // Fallback to current month
        return apiFormatter.string(from: Date())
    }

    /// Check if the selected period is the current month
    var isCurrentMonth: Bool {
        selectedPeriod == displayFormatter.string(from: Date())
    }

    /// Check if it's the start of a new month (day 1-3)
    var isNewMonthStart: Bool {
        guard isCurrentMonth else { return false }
        let day = Calendar.current.component(.day, from: Date())
        return day <= 3
    }

    /// Check if current period has minimal spending (new month scenario)
    var isNewMonthWithMinimalSpending: Bool {
        guard isNewMonthStart else { return false }
        guard let progress = state.progress else { return true }
        return progress.currentSpend < 50  // Less than €50 spent
    }

    /// Refresh just the progress (when spending changes)
    func refreshProgress() async {
        print("🔄 [BudgetViewModel] refreshProgress called, current state: \(state)")
        guard case .active = state else {
            print("🔄 [BudgetViewModel] refreshProgress skipped - state is not .active")
            return
        }

        do {
            let progressResponse = try await apiService.getBudgetProgress()
            state = .active(progressResponse.toBudgetProgress())
            print("🔄 [BudgetViewModel] refreshProgress completed - state updated to .active")
        } catch {
            print("🔄 [BudgetViewModel] refreshProgress failed: \(error)")
            // Don't change state on refresh failure
        }
    }

    // MARK: - Smart Budget Auto-Rollover

    /// Check if a smart budget should be auto-created for the current month
    /// This is called when loading the budget to ensure smart budgets carry over
    private func checkAndPerformAutoRollover() async {
        do {
            // Call the backend to check and perform auto-rollover
            // The backend will handle the logic of checking if:
            // 1. There's no budget for current month
            // 2. Previous month had a smart budget (isSmartBudget = true)
            // 3. Previous month's budget wasn't deleted
            try await apiService.performAutoRollover()
        } catch {
            // Silently fail - auto-rollover is optional
        }
    }

    /// Load budget history for all past months
    func loadBudgetHistory() async {
        isLoadingHistory = true
        historyError = nil

        do {
            let response = try await apiService.getBudgetHistory()
            budgetHistory = response.budgetHistory
        } catch {
            historyError = error.localizedDescription
        }

        isLoadingHistory = false
    }

    /// Create a new budget
    /// Smart budget is enabled by default, which means it will automatically roll over to next month
    func createBudget(amount: Double, categoryAllocations: [CategoryAllocation]? = nil, isSmartBudget: Bool = true) async -> Bool {
        isSaving = true
        saveError = nil

        let request = CreateBudgetRequest(
            monthlyAmount: amount,
            categoryAllocations: categoryAllocations,
            notificationsEnabled: true,
            alertThresholds: [0.5, 0.75, 0.9],
            isSmartBudget: isSmartBudget
        )

        do {
            let _ = try await apiService.saveBudget(request: request)
            // Reload to get fresh progress
            await loadBudget()
            NotificationCenter.default.post(name: .budgetUpdated, object: nil)
            isSaving = false
            return true
        } catch {
            saveError = error.localizedDescription
            isSaving = false
            return false
        }
    }

    /// Update existing budget amount
    func updateBudgetAmount(_ amount: Double) async -> Bool {
        isSaving = true
        saveError = nil

        let request = UpdateBudgetRequest(
            monthlyAmount: amount,
            categoryAllocations: nil,
            notificationsEnabled: nil,
            alertThresholds: nil,
            isSmartBudget: nil
        )

        do {
            let _ = try await apiService.modifyBudget(request: request)
            await loadBudget()
            NotificationCenter.default.post(name: .budgetUpdated, object: nil)
            isSaving = false
            return true
        } catch {
            saveError = error.localizedDescription
            isSaving = false
            return false
        }
    }

    /// Update category allocations
    func updateCategoryAllocations(_ allocations: [CategoryAllocation]) async -> Bool {
        isSaving = true
        saveError = nil

        let request = UpdateBudgetRequest(
            monthlyAmount: nil,
            categoryAllocations: allocations,
            notificationsEnabled: nil,
            alertThresholds: nil,
            isSmartBudget: nil
        )

        do {
            let _ = try await apiService.modifyBudget(request: request)
            await loadBudget()
            NotificationCenter.default.post(name: .budgetUpdated, object: nil)
            isSaving = false
            return true
        } catch {
            saveError = error.localizedDescription
            isSaving = false
            return false
        }
    }

    /// Toggle smart budget on/off
    /// When enabled, budget automatically rolls over to next month
    /// When disabled, budget will not be created for next month unless manually set
    func toggleSmartBudget(enabled: Bool) async -> Bool {
        isSaving = true
        saveError = nil

        let request = UpdateBudgetRequest(
            monthlyAmount: nil,
            categoryAllocations: nil,
            notificationsEnabled: nil,
            alertThresholds: nil,
            isSmartBudget: enabled
        )

        do {
            let _ = try await apiService.modifyBudget(request: request)
            await loadBudget()
            NotificationCenter.default.post(name: .budgetUpdated, object: nil)
            isSaving = false
            return true
        } catch {
            saveError = error.localizedDescription
            isSaving = false
            return false
        }
    }

    /// Delete the budget for the currently selected period
    func deleteBudget() async -> Bool {
        // Convert selected period to API format (yyyy-MM)
        let monthParam = isCurrentMonth ? nil : convertToAPIFormat(selectedPeriod)
        print("🗑️ [BudgetViewModel] Starting budget deletion for \(monthParam ?? "current month")...")
        isSaving = true
        saveError = nil

        do {
            try await apiService.removeBudget(month: monthParam)
            print("🗑️ [BudgetViewModel] API deletion successful, setting state to .noBudget")

            // Reset suggestion state
            suggestionState = .idle
            isSaving = false

            // Animate the state transition so the widget smoothly goes from active → noBudget
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                state = .noBudget
            }

            print("🗑️ [BudgetViewModel] State is now: \(state), refresh trigger: \(forceRefreshTrigger)")

            // Post notification for any other observers - this will trigger view reset
            NotificationCenter.default.post(name: .budgetDeleted, object: nil)

            print("🗑️ [BudgetViewModel] Budget deletion complete, notification posted")
            return true
        } catch {
            print("🗑️ [BudgetViewModel] Budget deletion failed: \(error.localizedDescription)")
            saveError = error.localizedDescription
            isSaving = false
            return false
        }
    }

    // MARK: - Setup Helpers

    /// Start the budget setup flow
    func startSetup() {
        showingSetupSheet = true
        Task {
            await loadBudgetSuggestion()
        }
    }

    /// Prepare category allocations for editing based on suggestion or current budget
    func prepareCategoryAllocationsForEditing() {
        if let progress = state.progress {
            // Use current allocations
            editingCategoryAllocations = progress.budget.categoryAllocations ?? []
        } else if let suggestion = suggestionState.data {
            // Use suggested allocations
            editingCategoryAllocations = suggestion.categoryAllocations.map {
                CategoryAllocation(category: $0.category, amount: $0.suggestedAmount, isLocked: false)
            }
        }
        showingCategoryEditor = true
    }

    /// Auto-balance category allocations to match total budget
    func autoBalanceCategories(totalBudget: Double) {
        guard !editingCategoryAllocations.isEmpty else { return }

        // Sum of locked amounts
        let lockedTotal = editingCategoryAllocations
            .filter { $0.isLocked }
            .reduce(0) { $0 + $1.amount }

        // Remaining budget for unlocked categories
        let remainingBudget = max(0, totalBudget - lockedTotal)

        // Calculate total of unlocked categories (for proportional distribution)
        let unlockedTotal = editingCategoryAllocations
            .filter { !$0.isLocked }
            .reduce(0) { $0 + $1.amount }

        // Redistribute
        editingCategoryAllocations = editingCategoryAllocations.map { allocation in
            if allocation.isLocked {
                return allocation
            } else {
                let proportion = unlockedTotal > 0 ? allocation.amount / unlockedTotal : 1.0 / Double(editingCategoryAllocations.filter { !$0.isLocked }.count)
                let newAmount = remainingBudget * proportion
                return CategoryAllocation(category: allocation.category, amount: newAmount, isLocked: false)
            }
        }
    }

    // MARK: - Budget Suggestion Methods

    /// Load budget suggestion based on historical spending
    func loadBudgetSuggestion() async {
        suggestionState = .loading

        do {
            let response = try await apiService.getBudgetSuggestion(basedOnMonths: 3)
            suggestionState = .loaded(response)
            // Also update the setup amount from suggestion
            setupBudgetAmount = response.recommendedBudget.amount
        } catch {
            suggestionState = .error(error.localizedDescription)
        }
    }

    // Legacy alias for backward compatibility
    func loadAISuggestion() async {
        await loadBudgetSuggestion()
    }

    /// Start setup flow (legacy alias)
    func startAISetup() {
        startSetup()
    }

    // MARK: - Budget Insights

    /// Load budget insights (deterministic, no AI)
    func loadInsights() async {
        insightsState = .loading

        do {
            let response = try await apiService.getBudgetInsights()
            insightsState = .loaded(response)
        } catch {
            insightsState = .error(error.localizedDescription)
        }
    }

    /// Load insights with specific options
    func loadInsights(
        includeBenchmarks: Bool = true,
        includeFlags: Bool = true,
        includeQuickWins: Bool = true,
        includeVolatility: Bool = true,
        includeProgress: Bool = true
    ) async {
        insightsState = .loading

        do {
            let response = try await apiService.getBudgetInsights(
                includeBenchmarks: includeBenchmarks,
                includeFlags: includeFlags,
                includeQuickWins: includeQuickWins,
                includeVolatility: includeVolatility,
                includeProgress: includeProgress
            )
            insightsState = .loaded(response)
        } catch {
            insightsState = .error(error.localizedDescription)
        }
    }
}

// MARK: - Activity Rings Support

extension BudgetViewModel {
    /// Get budget progress items for activity rings display
    var budgetProgressItems: [BudgetProgressItem] {
        guard let progress = state.progress else { return [] }
        return progress.categoryProgress.map { categoryProgress in
            BudgetProgressItem(
                categoryId: categoryProgress.category,
                name: categoryProgress.category,
                limitAmount: categoryProgress.budgetAmount,
                spentAmount: categoryProgress.currentSpend,
                isOverBudget: categoryProgress.isOverBudget,
                overBudgetAmount: categoryProgress.isOverBudget ? categoryProgress.overAmount : nil,
                isLocked: categoryProgress.isLocked
            )
        }
    }
}

// MARK: - Computed Properties

extension BudgetViewModel {
    var currentBudget: UserBudget? {
        state.progress?.budget
    }

    var currentProgress: BudgetProgress? {
        state.progress
    }

    var paceStatus: PaceStatus? {
        state.progress?.paceStatus
    }

    var spendRatioForDisplay: Double {
        state.progress?.spendRatio ?? 0
    }

    var formattedCurrentSpend: String {
        guard let progress = state.progress else { return "€0" }
        return String(format: "€%.0f", progress.currentSpend)
    }

    var formattedBudgetAmount: String {
        guard let progress = state.progress else { return "€0" }
        return String(format: "€%.0f", progress.budget.monthlyAmount)
    }

    var formattedRemaining: String {
        guard let progress = state.progress else { return "€0" }
        return String(format: "€%.0f", progress.remainingBudget)
    }

    var formattedDailyBudget: String {
        guard let progress = state.progress else { return "€0" }
        return String(format: "€%.0f", progress.dailyBudgetRemaining)
    }

    var daysRemainingText: String {
        guard let progress = state.progress else { return "" }
        let days = progress.daysRemaining
        return days == 1 ? "1 day left" : "\(days) days left"
    }

    var progressPercentageText: String {
        guard let progress = state.progress else { return "0%" }
        return String(format: "%.0f%%", progress.spendRatio * 100)
    }

    var projectionText: String? {
        guard let progress = state.progress else { return nil }
        let projected = progress.projectedEndOfMonth
        let budget = progress.budget.monthlyAmount

        if projected > budget * 1.05 {
            // Projected to be over budget
            let over = projected - budget
            return String(format: "Projected €%.0f over", over)
        } else if projected < budget * 0.95 {
            // Projected to be under budget
            let under = budget - projected
            return String(format: "Projected €%.0f under", under)
        }
        return "On track to hit budget"
    }
}
