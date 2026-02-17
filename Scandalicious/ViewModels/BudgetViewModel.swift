//
//  BudgetViewModel.swift
//  Scandalicious
//

import Foundation
import SwiftUI
import Combine

// MARK: - Budget State

enum BudgetState {
    case idle
    case loading
    case noBudget
    case active(BudgetProgress)
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

    // Period selection
    @Published var selectedPeriod: String = ""
    @Published var availablePeriods: [String] = []

    // Setup flow
    @Published var setupBudgetAmount: Double = 0
    @Published var showingSetupSheet = false
    @Published var isSaving = false
    @Published var saveError: String?

    // Category editing
    @Published var editingCategoryAllocations: [CategoryAllocation] = []
    @Published var showingCategoryEditor = false

    // Budget history
    @Published var budgetHistory: [BudgetHistory] = []
    @Published var isLoadingHistory = false
    @Published var historyError: String?

    // MARK: - Private Properties

    private let apiService = BudgetAPIService.shared
    private var notificationObserver: NSObjectProtocol?
    private var receiptUploadObserver: NSObjectProtocol?
    private var categoryAllocationsObserver: NSObjectProtocol?

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
        initializePeriodsSync()

        let cache = AppDataCache.shared
        if let cached = cache.budgetProgressCache {
            state = .active(cached.toBudgetProgress())
        } else if cache.budgetStatusChecked {
            state = .noBudget
        }

        notificationObserver = NotificationCenter.default.addObserver(
            forName: .receiptsDataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[BudgetVM] 📩 Received .receiptsDataDidChange notification")
            Task { @MainActor in
                await self?.refreshProgress()
            }
        }

        receiptUploadObserver = NotificationCenter.default.addObserver(
            forName: .receiptUploadedSuccessfully,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[BudgetVM] 📩 Received .receiptUploadedSuccessfully notification")
            Task { @MainActor in
                // Delay to let backend finish cache invalidation after receipt processing
                try? await Task.sleep(for: .seconds(2))
                print("[BudgetVM] ⏱️ Post-delay, calling refreshProgress()")
                await self?.refreshProgress()
            }
        }

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
        if let observer = receiptUploadObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = categoryAllocationsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public Methods

    func loadBudget() async {
        if availablePeriods.isEmpty {
            initializePeriodsSync()
        }

        if isCurrentMonth {
            await checkAndPerformAutoRollover()
        }

        await loadBudgetForPeriod(selectedPeriod)

        Task {
            await loadBudgetHistory()
        }
    }

    func loadBudgetForPeriod(_ period: String) async {
        let currentMonthString = displayFormatter.string(from: Date())

        if period == currentMonthString {
            await loadCurrentMonthProgress()
        } else {
            state = .noBudget
        }
    }

    private func loadCurrentMonthProgress() async {
        let cache = AppDataCache.shared
        print("[BudgetVM] loadCurrentMonthProgress() — cache.budgetProgressCache=\(cache.budgetProgressCache != nil), cache.budgetStatusChecked=\(cache.budgetStatusChecked)")

        if let cached = cache.budgetProgressCache {
            print("[BudgetVM] Using cached budget: spend=€\(cached.currentSpend), budget=€\(cached.budget.monthlyAmount)")
            state = .active(cached.toBudgetProgress())
            Task {
                do {
                    let progressResponse = try await apiService.getBudgetProgress()
                    print("[BudgetVM] Background refresh succeeded: spend=€\(progressResponse.currentSpend)")
                    state = .active(progressResponse.toBudgetProgress())
                    cache.updateBudgetProgress(progressResponse)
                } catch let error as BudgetAPIError {
                    switch error {
                    case .notFound, .noBudgetSet:
                        print("[BudgetVM] Background refresh: budget no longer exists, clearing cache")
                        AppDataCache.shared.budgetProgressCache = nil
                        AppDataCache.shared.budgetStatusChecked = true
                        AppDataCache.shared.scheduleSaveToDisk()
                        state = .noBudget
                    default:
                        print("[BudgetVM] Background refresh failed: \(error)")
                    }
                } catch {
                    print("[BudgetVM] Background refresh failed: \(error)")
                }
            }
            return
        }

        if cache.budgetStatusChecked {
            print("[BudgetVM] budgetStatusChecked=true, no cache → setting .noBudget, fetching in background")
            state = .noBudget
            Task {
                do {
                    let progressResponse = try await apiService.getBudgetProgress()
                    print("[BudgetVM] Background fetch found budget! spend=€\(progressResponse.currentSpend), budget=€\(progressResponse.budget.monthlyAmount)")
                    state = .active(progressResponse.toBudgetProgress())
                    cache.updateBudgetProgress(progressResponse)
                } catch {
                    print("[BudgetVM] Background fetch failed (still no budget): \(error)")
                }
            }
            return
        }

        print("[BudgetVM] No cache, first load → setting .loading, fetching from API")
        state = .loading

        do {
            let progressResponse = try await apiService.getBudgetProgress()
            print("[BudgetVM] Initial fetch succeeded: spend=€\(progressResponse.currentSpend), budget=€\(progressResponse.budget.monthlyAmount), categories=\(progressResponse.categoryProgress.count)")
            state = .active(progressResponse.toBudgetProgress())
            cache.updateBudgetProgress(progressResponse)
            cache.budgetStatusChecked = true
            cache.scheduleSaveToDisk()
        } catch let error as BudgetAPIError {
            print("[BudgetVM] Initial fetch BudgetAPIError: \(error)")
            switch error {
            case .noBudgetSet, .notFound:
                print("[BudgetVM] → No budget set on backend, setting .noBudget")
                state = .noBudget
                cache.budgetStatusChecked = true
                cache.scheduleSaveToDisk()
            default:
                print("[BudgetVM] → Other API error: \(error.localizedDescription)")
                state = .error(error.localizedDescription)
            }
        } catch {
            print("[BudgetVM] Initial fetch unexpected error: \(error)")
            state = .error(error.localizedDescription)
        }
    }

    func selectPeriod(_ period: String) async {
        guard period != selectedPeriod else { return }
        selectedPeriod = period
        await loadBudgetForPeriod(period)
    }

    // MARK: - Period Helpers

    private func convertToAPIFormat(_ displayPeriod: String) -> String {
        if let date = displayFormatter.date(from: displayPeriod) {
            return apiFormatter.string(from: date)
        }
        return apiFormatter.string(from: Date())
    }

    var isCurrentMonth: Bool {
        selectedPeriod == displayFormatter.string(from: Date())
    }

    func refreshProgress() async {
        print("[BudgetVM] refreshProgress() called, state=\(state)")
        guard case .active(let currentProgress) = state else {
            print("[BudgetVM] ❌ refreshProgress() skipped — state is not .active")
            return
        }
        print("[BudgetVM] 🔄 Fetching budget progress from API (current spend: €\(currentProgress.currentSpend))")

        do {
            let progressResponse = try await apiService.getBudgetProgress()
            let newProgress = progressResponse.toBudgetProgress()
            print("[BudgetVM] ✅ API returned: spend=€\(newProgress.currentSpend), budget=€\(newProgress.budget.monthlyAmount), categories=\(newProgress.categoryProgress.count)")
            state = .active(newProgress)
            AppDataCache.shared.updateBudgetProgress(progressResponse)
        } catch let error as BudgetAPIError {
            switch error {
            case .notFound, .noBudgetSet:
                print("[BudgetVM] ❌ refreshProgress(): budget no longer exists, clearing cache")
                AppDataCache.shared.budgetProgressCache = nil
                AppDataCache.shared.budgetStatusChecked = true
                AppDataCache.shared.scheduleSaveToDisk()
                state = .noBudget
            default:
                print("[BudgetVM] ❌ refreshProgress() API error: \(error)")
            }
        } catch {
            print("[BudgetVM] ❌ refreshProgress() API error: \(error)")
        }
    }

    // MARK: - Smart Budget Auto-Rollover

    private func checkAndPerformAutoRollover() async {
        do {
            try await apiService.performAutoRollover()
        } catch {
            // Silently fail
        }
    }

    // MARK: - Budget History

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

    // MARK: - CRUD Operations

    func createBudget(amount: Double, categoryAllocations: [CategoryAllocation]? = nil, isSmartBudget: Bool = true) async -> Bool {
        isSaving = true
        saveError = nil

        let request = CreateBudgetRequest(
            monthlyAmount: amount,
            categoryAllocations: categoryAllocations,
            isSmartBudget: isSmartBudget
        )

        do {
            let _ = try await apiService.saveBudget(request: request)
            print("[BudgetVM] Budget created successfully, reloading...")
            AppDataCache.shared.budgetProgressCache = nil
            AppDataCache.shared.budgetStatusChecked = false
            AppDataCache.shared.scheduleSaveToDisk()
            await loadBudget()
            NotificationCenter.default.post(name: .budgetUpdated, object: nil)
            isSaving = false
            return true
        } catch {
            print("[BudgetVM] Create budget failed: \(error)")
            saveError = error.localizedDescription
            isSaving = false
            return false
        }
    }

    func updateBudgetAmount(_ amount: Double) async -> Bool {
        isSaving = true
        saveError = nil

        let request = UpdateBudgetRequest(
            monthlyAmount: amount,
            categoryAllocations: nil,
            isSmartBudget: nil
        )

        do {
            let _ = try await apiService.modifyBudget(request: request)
            AppDataCache.shared.budgetProgressCache = nil
            AppDataCache.shared.scheduleSaveToDisk()
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

    func updateCategoryAllocations(_ allocations: [CategoryAllocation]) async -> Bool {
        isSaving = true
        saveError = nil

        let request = UpdateBudgetRequest(
            monthlyAmount: nil,
            categoryAllocations: allocations,
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

    func toggleSmartBudget(enabled: Bool) async -> Bool {
        isSaving = true
        saveError = nil

        let request = UpdateBudgetRequest(
            monthlyAmount: nil,
            categoryAllocations: nil,
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

    func deleteBudget() async -> Bool {
        let monthParam = isCurrentMonth ? nil : convertToAPIFormat(selectedPeriod)

        let previousState = state

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            state = .noBudget
        }
        AppDataCache.shared.budgetProgressCache = nil
        AppDataCache.shared.budgetStatusChecked = false
        AppDataCache.shared.scheduleSaveToDisk()
        NotificationCenter.default.post(name: .budgetDeleted, object: nil)

        do {
            try await apiService.removeBudget(month: monthParam)
            return true
        } catch {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                state = previousState
            }
            saveError = error.localizedDescription
            return false
        }
    }

    func updateBudgetFull(request: UpdateBudgetRequest) async -> Bool {
        isSaving = true
        saveError = nil

        do {
            let _ = try await apiService.modifyBudget(request: request)
            // Fetch fresh progress directly — skip loading state to avoid card collapse
            let progressResponse = try await apiService.getBudgetProgress()
            state = .active(progressResponse.toBudgetProgress())
            AppDataCache.shared.updateBudgetProgress(progressResponse)
            AppDataCache.shared.scheduleSaveToDisk()
            NotificationCenter.default.post(name: .budgetUpdated, object: nil)
            isSaving = false
            return true
        } catch {
            saveError = error.localizedDescription
            isSaving = false
            return false
        }
    }

    // MARK: - Setup Helpers

    func startSetup() {
        showingSetupSheet = true
    }

    func prepareCategoryAllocationsForEditing() {
        if let progress = state.progress {
            editingCategoryAllocations = progress.budget.categoryAllocations ?? []
        } else {
            editingCategoryAllocations = []
        }
        showingCategoryEditor = true
    }
}

// MARK: - Activity Rings Support

extension BudgetViewModel {
    var budgetProgressItems: [BudgetProgressItem] {
        guard let progress = state.progress else { return [] }
        return progress.categoryProgress.map { categoryProgress in
            BudgetProgressItem(
                categoryId: categoryProgress.category,
                name: categoryProgress.category,
                limitAmount: categoryProgress.budgetAmount,
                spentAmount: categoryProgress.currentSpend,
                isOverBudget: categoryProgress.isOverBudget,
                overBudgetAmount: categoryProgress.isOverBudget ? categoryProgress.overAmount : nil
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
            let over = projected - budget
            return String(format: "Projected €%.0f over", over)
        } else if projected < budget * 0.95 {
            let under = budget - projected
            return String(format: "Projected €%.0f under", under)
        }
        return "On track to hit budget"
    }
}
