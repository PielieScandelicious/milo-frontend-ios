//
//  BudgetViewModel.swift
//  Scandalicious
//
//  Created by Claude on 31/01/2026.
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

    // Setup flow state
    @Published var setupBudgetAmount: Double = 0
    @Published var showingSetupSheet = false
    @Published var isSaving = false
    @Published var saveError: String?

    // Category editing state
    @Published var editingCategoryAllocations: [CategoryAllocation] = []
    @Published var showingCategoryEditor = false

    // MARK: - AI-Powered State

    @Published var aiSuggestionState: AILoadingState<AIBudgetSuggestionResponse> = .idle
    @Published var aiCheckInState: AILoadingState<AICheckInResponse> = .idle
    @Published var aiReceiptAnalysisState: AILoadingState<AIReceiptAnalysisResponse> = .idle
    @Published var aiMonthlyReportState: AILoadingState<AIMonthlyReportResponse> = .idle

    // AI UI state
    @Published var showingAICheckIn = false
    @Published var showingAIMonthlyReport = false

    // MARK: - Private Properties

    private let apiService = BudgetAPIService.shared
    private var notificationObserver: NSObjectProtocol?

    // MARK: - Initialization

    init() {
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
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public Methods

    /// Load the user's budget and current progress
    func loadBudget() async {
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

    /// Refresh just the progress (when spending changes)
    func refreshProgress() async {
        guard case .active = state else { return }

        do {
            let progressResponse = try await apiService.getBudgetProgress()
            state = .active(progressResponse.toBudgetProgress())
        } catch {
            // Don't change state on refresh failure, just log
            print("⚠️ Failed to refresh budget progress: \(error.localizedDescription)")
        }
    }

    /// Create a new budget (always uses AI-calculated allocations)
    func createBudget(amount: Double, categoryAllocations: [CategoryAllocation]? = nil) async -> Bool {
        isSaving = true
        saveError = nil

        let request = CreateBudgetRequest(
            monthlyAmount: amount,
            categoryAllocations: categoryAllocations,
            notificationsEnabled: true,
            alertThresholds: [0.5, 0.75, 0.9]
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
            alertThresholds: nil
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
            alertThresholds: nil
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

    /// Delete the budget
    func deleteBudget() async -> Bool {
        isSaving = true
        saveError = nil

        do {
            try await apiService.removeBudget()
            state = .noBudget
            // Reset all AI states when budget is deleted
            aiCheckInState = .idle
            aiSuggestionState = .idle
            aiMonthlyReportState = .idle
            NotificationCenter.default.post(name: .budgetDeleted, object: nil)
            isSaving = false
            return true
        } catch {
            saveError = error.localizedDescription
            isSaving = false
            return false
        }
    }

    // MARK: - Setup Helpers

    /// Start the budget setup flow (uses AI-powered suggestions)
    func startSetup() {
        showingSetupSheet = true
        Task {
            await loadAISuggestion()
        }
    }

    /// Prepare category allocations for editing based on AI suggestion or current budget
    func prepareCategoryAllocationsForEditing() {
        if let progress = state.progress {
            // Use current allocations
            editingCategoryAllocations = progress.budget.categoryAllocations ?? []
        } else if let aiSuggestion = aiSuggestionState.data {
            // Use AI-suggested allocations
            editingCategoryAllocations = aiSuggestion.categoryAllocations.map {
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

    // MARK: - AI-Powered Methods

    /// Load AI-powered budget suggestion with personalized insights
    func loadAISuggestion() async {
        aiSuggestionState = .loading

        do {
            let response = try await apiService.getAISuggestion(basedOnMonths: 3)
            aiSuggestionState = .loaded(response)
            // Also update the setup amount from AI suggestion
            setupBudgetAmount = response.aiAnalysis.recommendedBudget.amount
        } catch {
            aiSuggestionState = .error(error.localizedDescription)
        }
    }

    /// Load weekly AI check-in
    func loadAICheckIn() async {
        aiCheckInState = .loading

        do {
            let response = try await apiService.getAICheckIn()
            aiCheckInState = .loaded(response)
        } catch {
            aiCheckInState = .error(error.localizedDescription)
        }
    }

    /// Analyze a receipt for budget impact (call after scanning)
    func analyzeReceiptForBudget(receiptId: String) async {
        aiReceiptAnalysisState = .loading

        do {
            let response = try await apiService.getAIReceiptAnalysis(receiptId: receiptId)
            aiReceiptAnalysisState = .loaded(response)
        } catch {
            aiReceiptAnalysisState = .error(error.localizedDescription)
        }
    }

    /// Clear receipt analysis (after dismissing)
    func clearReceiptAnalysis() {
        aiReceiptAnalysisState = .idle
    }

    /// Load AI monthly report
    func loadAIMonthlyReport(month: String? = nil) async {
        aiMonthlyReportState = .loading

        // Default to current month
        let monthString = month ?? {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            return formatter.string(from: Date())
        }()

        do {
            let response = try await apiService.getAIMonthlyReport(month: monthString)
            aiMonthlyReportState = .loaded(response)
        } catch {
            aiMonthlyReportState = .error(error.localizedDescription)
        }
    }

    /// Check if weekly check-in should be shown
    var shouldShowWeeklyCheckIn: Bool {
        guard case .active = state else { return false }
        return true
    }

    /// Start AI setup flow (with AI-powered suggestions)
    func startAISetup() {
        showingSetupSheet = true
        Task {
            await loadAISuggestion()
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
