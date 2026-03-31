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
    @Published private(set) var spinsAvailable: Int = 0
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

    // Referral earned overlay (app-wide, auto-triggered)
    @Published var showReferralEarnedOverlay: Bool = false
    @Published var pendingOverlayEuros: Double = 0
    @Published var pendingOverlaySpins: Int = 0
    @Published var animatedReferralOverlayValue: Double = 0
    @Published var showReferralOverlayConfetti: Bool = false

    // MARK: - Private

    private let userDefaults = UserDefaults.standard
    private var currentUserId: String?
    private var isAutoClaimInProgress: Bool = false

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
        userDefaults.set(spinsAvailable, forKey: "\(prefix)_spins")
        userDefaults.set(hasDoubleNext, forKey: "\(prefix)_doubleNext")
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

                // Auto-claim and show overlay if a reward is waiting
                if info.hasUnclaimedReward && !self.showReferralEarnedOverlay && !self.isAutoClaimInProgress {
                    self.isAutoClaimInProgress = true
                    self.autoClaimAndShowOverlay()
                }

                self.saveState()
            } catch {
                print("[GamificationManager] Referral info fetch failed: \(error)")
            }
        }
    }

    private func autoClaimAndShowOverlay() {
        Task {
            do {
                let response = try await ReferralAPIService.shared.claimReward()
                guard response.success else {
                    isAutoClaimInProgress = false
                    return
                }
                pendingOverlayEuros = response.eurosCredited
                pendingOverlaySpins = response.spinsCredited
                hasUnclaimedReferralReward = false
                unclaimedReferralEuros = 0
                unclaimedReferralSpins = 0
                wallet = WalletBalance(euros: response.newBalance)
                animatedReferralOverlayValue = 0
                showReferralOverlayConfetti = false
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    showReferralEarnedOverlay = true
                }
                saveState()
                NotificationCenter.default.post(name: .referralRewardAvailable, object: nil)
            } catch {
                print("[GamificationManager] Auto referral claim failed: \(error)")
                isAutoClaimInProgress = false
            }
        }
    }

    func dismissReferralEarnedOverlay() {
        withAnimation(.easeIn(duration: 0.25)) {
            showReferralEarnedOverlay = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showReferralOverlayConfetti = false
            self.animatedReferralOverlayValue = 0
            self.isAutoClaimInProgress = false
            NotificationCenter.default.post(name: .rewardClaimed, object: nil)
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
}
