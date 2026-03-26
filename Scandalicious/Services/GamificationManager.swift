//
//  GamificationManager.swift
//  Scandalicious
//
//  Created by Claude on 20/02/2026.
//

import Foundation
import Combine
import SwiftUI
import FirebaseAuth

@MainActor
class GamificationManager: ObservableObject {
    static let shared = GamificationManager()

    // MARK: - Published State

    @Published private(set) var wallet: WalletBalance = WalletBalance(euros: 0)
    @Published private(set) var streak: StreakData = StreakData(weekCount: 0, lastReceiptDate: nil, hasShield: false, isAtRisk: false)
    @Published private(set) var badges: [Badge] = Badge.allBadges
    @Published private(set) var spinsAvailable: Int = 0
    @Published private(set) var lastUnlockedBadge: Badge? = nil
    @Published private(set) var lastSpinResult: SpinResult? = nil

    // Withdrawal state
    @Published private(set) var withdrawalInfo: WithdrawalInfoResponse? = nil
    @Published private(set) var hasPendingWithdrawal: Bool = false
    @Published private(set) var activeWithdrawal: WithdrawalItemResponse? = nil
    @Published private(set) var withdrawalHistory: [WithdrawalItemResponse] = []
    @Published var withdrawalTestMode: Bool = false

    // Charity state
    @Published private(set) var charities: [CharityItem] = []
    @Published private(set) var charityUserBalance: Double = 0
    @Published private(set) var charityHistory: [CharityDonationItem] = []
    @Published private(set) var charityTotalDonated: Double = 0

    // Referral state
    @Published private(set) var referralCode: String? = nil
    @Published private(set) var referralCount: Int = 0
    @Published private(set) var referralEarned: Double = 0
    @Published private(set) var hasAppliedReferralCode: Bool = false
    @Published private(set) var hasUnclaimedReferralReward: Bool = false
    @Published private(set) var unclaimedReferralEuros: Double = 0
    @Published private(set) var unclaimedReferralSpins: Int = 0

    // MARK: - Private

    private let userDefaults = UserDefaults.standard
    private var currentUserId: String?

    // MARK: - Init

    private init() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.handleUserChange(user)
            }
        }

        if let user = Auth.auth().currentUser {
            handleUserChange(user)
        }

        // Auto-sync wallet when any receipt completes
        NotificationCenter.default.addObserver(
            forName: .receiptUploadedSuccessfully,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Small delay to let the backend finalize cashback
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                self?.fetchAndSyncWallet()
                self?.fetchReferralInfo()

                // Check receipt-related badges
                let storeName = notification.userInfo?["storeName"] as? String
                let receiptAmount = notification.userInfo?["receiptAmount"] as? Double
                let receiptId = notification.userInfo?["receiptId"] as? String

                // Fetch full receipt details to get item categories for badge tracking
                var categories: [String]? = nil
                if let receiptId {
                    categories = await self?.fetchReceiptCategories(receiptId: receiptId)
                }

                self?.checkReceiptBadges(
                    storeName: storeName,
                    receiptAmount: receiptAmount,
                    categories: categories
                )
            }
        }
    }

    // MARK: - User Management

    private func handleUserChange(_ user: FirebaseAuth.User?) {
        let newUserId = user?.uid
        if newUserId != currentUserId {
            currentUserId = newUserId
            if newUserId != nil {
                loadState()
            } else {
                resetToDefaults()
            }
        }
    }

    private var keyPrefix: String {
        guard let uid = currentUserId else { return "gamification_anonymous" }
        return "gamification_\(uid)"
    }

    // MARK: - State Management

    private func resetToDefaults() {
        wallet = WalletBalance(euros: 0)
        streak = StreakData(weekCount: 0, lastReceiptDate: nil, hasShield: false, isAtRisk: false)
        badges = Badge.allBadges.map { var b = $0; b.isUnlocked = false; b.unlockedAt = nil; return b }
        spinsAvailable = 0
        referralCode = nil
        referralCount = 0
        referralEarned = 0
        hasAppliedReferralCode = false
        hasUnclaimedReferralReward = false
        unclaimedReferralEuros = 0
        unclaimedReferralSpins = 0
        withdrawalInfo = nil
        hasPendingWithdrawal = false
        activeWithdrawal = nil
        withdrawalHistory = []
        totalReceiptCount = 0
        totalSpinCount = 0
        uniqueStores = []
        uniqueCategories = []
        groceryReceiptCount = 0
        weekendScanDays = []
        lastWeekendScanWeek = nil
    }

    private func loadState() {
        let prefix = keyPrefix
        let decoder = JSONDecoder()

        if let data = userDefaults.data(forKey: "\(prefix)_wallet"),
           let decoded = try? decoder.decode(WalletBalance.self, from: data) {
            wallet = decoded
        } else {
            wallet = WalletBalance(euros: 0)
        }

        spinsAvailable = userDefaults.integer(forKey: "\(prefix)_spins")
        hasDoubleNext = userDefaults.bool(forKey: "\(prefix)_doubleNext")
        if !userDefaults.bool(forKey: "\(prefix)_initialized") {
            spinsAvailable = 2
        }

        if let data = userDefaults.data(forKey: "\(prefix)_badges"),
           let decoded = try? decoder.decode([Badge].self, from: data) {
            // Merge: always use latest template (name, description, icon, color)
            // but preserve unlock state and progress from saved data
            var merged: [Badge] = []
            for var template in Badge.allBadges {
                if let existing = decoded.first(where: { $0.id == template.id }) {
                    template.isUnlocked = existing.isUnlocked
                    template.unlockedAt = existing.unlockedAt
                    template.progress = existing.progress
                    template.progressLabel = existing.progressLabel
                }
                merged.append(template)
            }
            badges = merged
        } else {
            badges = Badge.allBadges
        }

        // Badge tracking stats
        totalReceiptCount = userDefaults.integer(forKey: "\(prefix)_totalReceiptCount")
        totalSpinCount = userDefaults.integer(forKey: "\(prefix)_totalSpinCount")
        groceryReceiptCount = userDefaults.integer(forKey: "\(prefix)_groceryReceiptCount")
        if let storesData = userDefaults.array(forKey: "\(prefix)_uniqueStores") as? [String] {
            uniqueStores = Set(storesData)
        }
        if let catsData = userDefaults.array(forKey: "\(prefix)_uniqueCategories") as? [String] {
            uniqueCategories = Set(catsData)
        }

        // Referral state
        referralCode = userDefaults.string(forKey: "\(prefix)_referralCode")
        referralCount = userDefaults.integer(forKey: "\(prefix)_referralCount")
        referralEarned = userDefaults.double(forKey: "\(prefix)_referralEarned")
        hasAppliedReferralCode = userDefaults.bool(forKey: "\(prefix)_hasAppliedReferral")

        userDefaults.set(true, forKey: "\(prefix)_initialized")
        saveState()

        // Sync wallet with backend
        fetchAndSyncWallet()
    }

    private func saveState() {
        let prefix = keyPrefix
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(wallet)         { userDefaults.set(data, forKey: "\(prefix)_wallet") }
        if let data = try? encoder.encode(streak)         { userDefaults.set(data, forKey: "\(prefix)_streak") }
        if let data = try? encoder.encode(badges)         { userDefaults.set(data, forKey: "\(prefix)_badges") }
        userDefaults.set(spinsAvailable, forKey: "\(prefix)_spins")
        userDefaults.set(hasDoubleNext, forKey: "\(prefix)_doubleNext")
        userDefaults.set(totalReceiptCount, forKey: "\(prefix)_totalReceiptCount")
        userDefaults.set(totalSpinCount, forKey: "\(prefix)_totalSpinCount")
        userDefaults.set(groceryReceiptCount, forKey: "\(prefix)_groceryReceiptCount")
        userDefaults.set(Array(uniqueStores), forKey: "\(prefix)_uniqueStores")
        userDefaults.set(Array(uniqueCategories), forKey: "\(prefix)_uniqueCategories")
        if let code = referralCode { userDefaults.set(code, forKey: "\(prefix)_referralCode") }
        userDefaults.set(referralCount, forKey: "\(prefix)_referralCount")
        userDefaults.set(referralEarned, forKey: "\(prefix)_referralEarned")
        userDefaults.set(hasAppliedReferralCode, forKey: "\(prefix)_hasAppliedReferral")
    }

    // MARK: - Wallet Sync

    func syncWalletWithBackend(balance: Double, isGoldTier: Bool, spins: Int? = nil) {
        wallet = WalletBalance(euros: balance)
        if let spins {
            spinsAvailable = spins
        }
        saveState()
    }

    /// Fetch the latest cashback balance from the backend and update the wallet.
    /// Also refreshes withdrawal info and charity data after the balance is known.
    func fetchAndSyncWallet() {
        Task {
            do {
                let balance = try await CashbackAPIService.shared.getBalance()
                self.wallet = WalletBalance(euros: balance.currentBalance)
                self.spinsAvailable = balance.spinsAvailable
                self.saveState()
            } catch {
                print("[GamificationManager] Wallet sync failed: \(error)")
            }
            // Refresh withdrawal eligibility and charity data after balance is loaded
            fetchWithdrawalInfo()
            fetchCharities()
        }
    }

    // MARK: - Public API

    func awardReceiptReward(storeName: String?, receiptAmount: Double?) -> RewardEvent {
        let baseAmount = 0.50
        let bonus = MysteryBonusType.random()

        wallet.add(euros: baseAmount)

        switch bonus {
        case .cashBonus(let amount):
            wallet.add(euros: amount)
        case .spinToken:
            spinsAvailable += 1
        case .nothing:
            break
        }

        // Spins are now awarded server-side via cashback transaction
        saveState()

        return RewardEvent(
            storeName: storeName,
            receiptAmount: receiptAmount,
            coinsAwarded: baseAmount,
            spinsAwarded: 0,
            mysteryBonus: bonus
        )
    }

    @Published private(set) var hasDoubleNext: Bool = false
    @Published var spinTestMode: Bool = false
    @Published var forcedSegmentIndex: Int? = nil
    @Published var badgeTestMode: Bool = false

    // MARK: - Badge Tracking Stats
    @Published private(set) var totalReceiptCount: Int = 0
    @Published private(set) var totalSpinCount: Int = 0
    @Published private(set) var uniqueStores: Set<String> = []
    @Published private(set) var uniqueCategories: Set<String> = []
    @Published private(set) var groceryReceiptCount: Int = 0
    @Published private(set) var weekendScanDays: Set<Int> = [] // weekday numbers (7=Sat,1=Sun)
    @Published private(set) var lastWeekendScanWeek: Int? = nil // week of year for tracking same-weekend

    func spinWheel(isRespin: Bool = false) async -> SpinResult? {
        if !spinTestMode {
            guard spinsAvailable > 0 else { return nil }
        }
        // Optimistic local decrement for immediate UI feedback
        spinsAvailable -= 1

        do {
            let result = try await CashbackAPIService.shared.performSpin(
                hasDoubleNext: hasDoubleNext,
                isRespin: isRespin,
                forceSegment: spinTestMode ? forcedSegmentIndex : nil
            )

            // NOTE: wallet, spinsAvailable, and hasDoubleNext are updated by the view
            // after wheel animation completes via applySpinResult(), not here,
            // to avoid updating counters before the wheel stops.

            lastSpinResult = result
            totalSpinCount += 1

            if result.isJackpot {
                unlockBadgeIfNeeded(id: "jackpot")
            }
            if result.cashValue >= 1 {
                unlockBadgeIfNeeded(id: "lucky_spin")
            }
            if totalSpinCount >= 50 {
                unlockBadgeIfNeeded(id: "spin_master")
            }
            updateBadgeProgress(id: "spin_master", current: Double(min(totalSpinCount, 50)), target: 50)

            saveState()
            NotificationCenter.default.post(name: .spinCompleted, object: nil)
            return result
        } catch {
            // Refund the spin on network error
            spinsAvailable += 1
            print("[GamificationManager] Spin failed: \(error)")
            return nil
        }
    }

    /// Called by the view after wheel animation completes to sync all state.
    /// Deferred so counters don't update while the wheel is still spinning.
    func applySpinResult(_ result: SpinResult) {
        wallet = WalletBalance(euros: result.newBalance)
        spinsAvailable = result.spinsRemaining
        if result.grantsDoubleNext {
            hasDoubleNext = true
        } else if result.isDoubled {
            hasDoubleNext = false
        }
        saveState()
    }

    // MARK: - Referral

    func fetchReferralInfo() {
        Task {
            do {
                let info = try await ReferralAPIService.shared.getReferralInfo()
                self.referralCode = info.referralCode
                self.referralCount = info.completedReferrals
                self.referralEarned = info.totalEarned
                self.hasUnclaimedReferralReward = info.hasUnclaimedReward
                self.unclaimedReferralEuros = info.unclaimedRewardEuros
                self.unclaimedReferralSpins = info.unclaimedRewardSpins

                // Social Butterfly badge: 3+ completed referrals
                if info.completedReferrals >= 3 {
                    self.unlockBadgeIfNeeded(id: "social_butterfly")
                }
                self.updateBadgeProgress(id: "social_butterfly", current: Double(min(info.completedReferrals, 3)), target: 3)

                self.saveState()
            } catch {
                print("[GamificationManager] Referral info fetch failed: \(error)")
            }
        }
    }

    func claimReferralReward() async throws -> ClaimReferralRewardResponse {
        let response = try await ReferralAPIService.shared.claimReward()
        if response.success {
            hasUnclaimedReferralReward = false
            unclaimedReferralEuros = 0
            unclaimedReferralSpins = 0
            wallet = WalletBalance(euros: response.newBalance)
            saveState()
        }
        return response
    }

    func applyReferralCode(_ code: String) async -> (success: Bool, message: String, referrerName: String?) {
        do {
            let response = try await ReferralAPIService.shared.applyCode(code)
            if response.success {
                hasAppliedReferralCode = true
                saveState()
            }
            return (response.success, response.message, response.referrerName)
        } catch {
            return (false, "Failed to apply referral code. Please try again.", nil)
        }
    }

    // MARK: - Withdrawal

    func fetchWithdrawalInfo() {
        Task {
            do {
                let info = try await WithdrawalAPIService.shared.getInfo()
                self.withdrawalInfo = info
                self.hasPendingWithdrawal = info.hasPendingWithdrawal
                self.activeWithdrawal = info.activeWithdrawal
            } catch {
                print("[GamificationManager] Withdrawal info fetch failed: \(error)")
            }
        }
    }

    func fetchWithdrawalHistory() {
        Task {
            do {
                let history = try await WithdrawalAPIService.shared.getHistory()
                self.withdrawalHistory = history.withdrawals
                self.hasPendingWithdrawal = history.hasPending
            } catch {
                print("[GamificationManager] Withdrawal history fetch failed: \(error)")
            }
        }
    }

    func submitWithdrawal(amount: Double, iban: String) async throws -> WithdrawalCreateResponse {
        let response = try await WithdrawalAPIService.shared.submitWithdrawal(amount: amount, iban: iban)
        wallet = WalletBalance(euros: response.newBalance)
        hasPendingWithdrawal = true
        saveState()
        fetchWithdrawalInfo()
        return response
    }

    func testAutoProcessWithdrawal(_ withdrawalId: String) async throws {
        _ = try await WithdrawalAPIService.shared.autoProcess(withdrawalId: withdrawalId)
        fetchWithdrawalInfo()
        fetchAndSyncWallet()
    }

    func testResetWithdrawals() async throws {
        _ = try await WithdrawalAPIService.shared.resetWithdrawals()
        hasPendingWithdrawal = false
        activeWithdrawal = nil
        withdrawalHistory = []
        fetchWithdrawalInfo()
        fetchAndSyncWallet()
    }

    // MARK: - Charity

    func fetchCharities() {
        Task {
            do {
                let response = try await CharityAPIService.shared.getCharities()
                self.charities = response.charities
                self.charityUserBalance = response.userBalance
            } catch {
                print("[GamificationManager] Charity list fetch failed: \(error)")
            }
        }
    }

    func fetchCharityHistory() {
        Task {
            do {
                let response = try await CharityAPIService.shared.getHistory()
                self.charityHistory = response.donations
                self.charityTotalDonated = response.totalDonated
            } catch {
                print("[GamificationManager] Charity history fetch failed: \(error)")
            }
        }
    }

    func submitCharityDonation(charityId: String, amount: Double) async throws -> CharityDonateResponse {
        let response = try await CharityAPIService.shared.donate(charityId: charityId, amount: amount)
        wallet = WalletBalance(euros: response.newBalance)
        saveState()
        fetchCharities()
        fetchWithdrawalInfo()
        return response
    }

    // MARK: - Badge Helpers

    /// Fetches category data for a completed receipt from the analytics API.
    private func fetchReceiptCategories(receiptId: String) async -> [String]? {
        do {
            let response = try await AnalyticsAPIService.shared.getReceipts()
            if let receipt = response.receipts.first(where: { $0.receiptId == receiptId }) {
                let categories = receipt.transactions.map { $0.category }
                return categories.isEmpty ? nil : categories
            }
        } catch {
            print("[GamificationManager] Failed to fetch receipt categories: \(error)")
        }
        return nil
    }

    func unlockBadgeIfNeeded(id: String) {
        guard let index = badges.firstIndex(where: { $0.id == id }),
              !badges[index].isUnlocked else { return }

        badges[index].isUnlocked = true
        badges[index].unlockedAt = Date()
        badges[index].progress = 1.0
        lastUnlockedBadge = badges[index]

        saveState()

        NotificationCenter.default.post(
            name: .badgeUnlocked,
            object: nil,
            userInfo: ["badgeId": id]
        )
    }

    private func updateBadgeProgress(id: String, current: Double, target: Double) {
        guard let index = badges.firstIndex(where: { $0.id == id }),
              !badges[index].isUnlocked else { return }
        let progress = min(current / target, 1.0)
        badges[index].progress = progress
        badges[index].progressLabel = "\(Int(current))/\(Int(target))"
    }

    /// Called after a receipt is successfully processed to check receipt-related badges.
    func checkReceiptBadges(storeName: String?, receiptAmount: Double?, categories: [String]?, uploadDate: Date = Date()) {
        totalReceiptCount += 1

        // First Scan
        unlockBadgeIfNeeded(id: "first_scan")

        // Big Spender
        if let amount = receiptAmount, amount > 100 {
            unlockBadgeIfNeeded(id: "big_spender")
        }

        // Night Owl (after 10 PM)
        let hour = Calendar.current.component(.hour, from: uploadDate)
        if hour >= 22 || hour < 4 {
            unlockBadgeIfNeeded(id: "night_scanner")
        }

        // Collector (5+ different stores)
        if let store = storeName, !store.isEmpty {
            uniqueStores.insert(store.lowercased())
            if uniqueStores.count >= 5 {
                unlockBadgeIfNeeded(id: "collector")
            }
            updateBadgeProgress(id: "collector", current: Double(min(uniqueStores.count, 5)), target: 5)
        }

        // Grocery Guru (20 grocery receipts)
        if let cats = categories {
            let isGrocery = cats.contains { $0.lowercased().contains("grocer") || $0.lowercased().contains("supermar") }
            if isGrocery {
                groceryReceiptCount += 1
                if groceryReceiptCount >= 20 {
                    unlockBadgeIfNeeded(id: "grocery_guru")
                }
                updateBadgeProgress(id: "grocery_guru", current: Double(min(groceryReceiptCount, 20)), target: 20)
            }
            // Category Explorer (8+ different categories)
            for cat in cats {
                uniqueCategories.insert(cat.lowercased())
            }
            if uniqueCategories.count >= 8 {
                unlockBadgeIfNeeded(id: "category_explorer")
            }
            updateBadgeProgress(id: "category_explorer", current: Double(min(uniqueCategories.count, 8)), target: 8)
        }

        // Century Club (100 receipts)
        if totalReceiptCount >= 100 {
            unlockBadgeIfNeeded(id: "century_club")
        }
        updateBadgeProgress(id: "century_club", current: Double(min(totalReceiptCount, 100)), target: 100)

        // Weekend Warrior (scan on both Sat and Sun in same weekend)
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: uploadDate)
        if weekday == 7 || weekday == 1 { // Saturday or Sunday
            // Use Saturday's date as the weekend identifier so Sat & Sun always match.
            // Sunday (weekday=1) can have a different weekOfYear than Saturday, so we
            // go back one day from Sunday to find the Saturday that anchors this weekend.
            let saturdayDate: Date
            if weekday == 1 { // Sunday → go back 1 day to Saturday
                saturdayDate = calendar.date(byAdding: .day, value: -1, to: uploadDate) ?? uploadDate
            } else { // Saturday
                saturdayDate = uploadDate
            }
            let weekendId = calendar.ordinality(of: .day, in: .era, for: calendar.startOfDay(for: saturdayDate)) ?? 0

            if lastWeekendScanWeek == weekendId {
                // Already scanned on another weekend day this weekend
                weekendScanDays.insert(weekday)
                if weekendScanDays.contains(7) && weekendScanDays.contains(1) {
                    unlockBadgeIfNeeded(id: "weekend_warrior")
                }
            } else {
                lastWeekendScanWeek = weekendId
                weekendScanDays = [weekday]
            }
        }

        saveState()
    }

    /// Called when a month ends under budget.
    func checkBudgetBadges(spentRatio: Double) {
        if spentRatio <= 1.0 {
            unlockBadgeIfNeeded(id: "budget_boss")
        }
        if spentRatio <= 0.8 {
            unlockBadgeIfNeeded(id: "penny_pincher")
        }
    }

    // MARK: - Badge Test Mode

    func testUnlockBadge(id: String) {
        unlockBadgeIfNeeded(id: id)
    }

    func testUnlockAllBadges() {
        for i in badges.indices {
            if !badges[i].isUnlocked {
                badges[i].isUnlocked = true
                badges[i].unlockedAt = Date()
                badges[i].progress = 1.0
            }
        }
        saveState()
    }

    func testResetAllBadges() {
        badges = Badge.allBadges
        totalReceiptCount = 0
        totalSpinCount = 0
        uniqueStores = []
        uniqueCategories = []
        groceryReceiptCount = 0
        weekendScanDays = []
        lastWeekendScanWeek = nil
        saveState()
    }

    func testUnlockNextBadge() {
        if let index = badges.firstIndex(where: { !$0.isUnlocked }) {
            unlockBadgeIfNeeded(id: badges[index].id)
        }
    }
}
