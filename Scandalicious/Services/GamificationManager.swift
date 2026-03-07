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
    @Published private(set) var goldTierStatus: GoldTierStatus = GoldTierStatus(isGoldTier: true)
    @Published private(set) var badges: [Badge] = Badge.allBadges
    @Published private(set) var spinsAvailable: Int = 0
    @Published private(set) var ownedCoupons: [Coupon] = []
    @Published private(set) var lastUnlockedBadge: Badge? = nil
    @Published private(set) var lastSpinResult: SpinResult? = nil

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
        ) { [weak self] _ in
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
        goldTierStatus = GoldTierStatus(isGoldTier: true)
        badges = Badge.allBadges.map { var b = $0; b.isUnlocked = false; b.unlockedAt = nil; return b }
        spinsAvailable = 0
        ownedCoupons = []
        referralCode = nil
        referralCount = 0
        referralEarned = 0
        hasAppliedReferralCode = false
        hasUnclaimedReferralReward = false
        unclaimedReferralEuros = 0
        unclaimedReferralSpins = 0
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

        if let data = userDefaults.data(forKey: "\(prefix)_streak"),
           let decoded = try? decoder.decode(StreakData.self, from: data) {
            streak = decoded
            checkStreakStatus()
        } else {
            streak = StreakData(weekCount: 3, lastReceiptDate: Date().addingTimeInterval(-86400 * 5), hasShield: false, isAtRisk: false)
        }

        if let data = userDefaults.data(forKey: "\(prefix)_goldTier"),
           let decoded = try? decoder.decode(GoldTierStatus.self, from: data) {
            goldTierStatus = decoded
        } else {
            goldTierStatus = GoldTierStatus(isGoldTier: true)
        }

        spinsAvailable = userDefaults.integer(forKey: "\(prefix)_spins")
        hasDoubleNext = userDefaults.bool(forKey: "\(prefix)_doubleNext")
        if !userDefaults.bool(forKey: "\(prefix)_initialized") {
            spinsAvailable = 2
        }

        if let data = userDefaults.data(forKey: "\(prefix)_badges"),
           let decoded = try? decoder.decode([Badge].self, from: data) {
            badges = decoded
        } else {
            badges = Badge.allBadges
        }

        if let data = userDefaults.data(forKey: "\(prefix)_ownedCoupons"),
           let decoded = try? decoder.decode([Coupon].self, from: data) {
            ownedCoupons = decoded
        }

        // Referral state
        referralCode = userDefaults.string(forKey: "\(prefix)_referralCode")
        referralCount = userDefaults.integer(forKey: "\(prefix)_referralCount")
        referralEarned = userDefaults.double(forKey: "\(prefix)_referralEarned")
        hasAppliedReferralCode = userDefaults.bool(forKey: "\(prefix)_hasAppliedReferral")

        userDefaults.set(true, forKey: "\(prefix)_initialized")
        saveState()

        // Sync wallet with backend cashback balance
        fetchAndSyncWallet()
    }

    private func saveState() {
        let prefix = keyPrefix
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(wallet)         { userDefaults.set(data, forKey: "\(prefix)_wallet") }
        if let data = try? encoder.encode(streak)         { userDefaults.set(data, forKey: "\(prefix)_streak") }
        if let data = try? encoder.encode(goldTierStatus) { userDefaults.set(data, forKey: "\(prefix)_goldTier") }
        if let data = try? encoder.encode(badges)         { userDefaults.set(data, forKey: "\(prefix)_badges") }
        if let data = try? encoder.encode(ownedCoupons) { userDefaults.set(data, forKey: "\(prefix)_ownedCoupons") }
        userDefaults.set(spinsAvailable, forKey: "\(prefix)_spins")
        userDefaults.set(hasDoubleNext, forKey: "\(prefix)_doubleNext")
        if let code = referralCode { userDefaults.set(code, forKey: "\(prefix)_referralCode") }
        userDefaults.set(referralCount, forKey: "\(prefix)_referralCount")
        userDefaults.set(referralEarned, forKey: "\(prefix)_referralEarned")
        userDefaults.set(hasAppliedReferralCode, forKey: "\(prefix)_hasAppliedReferral")
    }

    // MARK: - Wallet & Gold Tier Sync

    func syncWalletWithBackend(balance: Double, isGoldTier: Bool, spins: Int? = nil) {
        wallet = WalletBalance(euros: balance)
        goldTierStatus = GoldTierStatus(isGoldTier: isGoldTier)
        if let spins {
            spinsAvailable = spins
        }
        saveState()
    }

    /// Fetch the latest cashback balance from the backend and update the wallet.
    func fetchAndSyncWallet() {
        Task {
            do {
                let balance = try await CashbackAPIService.shared.getBalance()
                self.wallet = WalletBalance(euros: balance.currentBalance)
                self.goldTierStatus = GoldTierStatus(isGoldTier: balance.isGoldTier)
                self.spinsAvailable = balance.spinsAvailable
                self.saveState()
            } catch {
                print("[GamificationManager] Wallet sync failed: \(error)")
            }
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
        updateStreakForReceipt()
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

            if result.isJackpot {
                unlockBadgeIfNeeded(id: "jackpot")
            }

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
        // Sync wallet and spins with server-authoritative values
        wallet = WalletBalance(euros: result.newBalance)
        spinsAvailable = result.spinsRemaining

        // Update double-next state
        if result.grantsDoubleNext {
            hasDoubleNext = true
        } else if result.isDoubled {
            hasDoubleNext = false
        }
        saveState()
    }

    func redeemCoupon(_ coupon: Coupon) -> Bool {
        guard wallet.cents >= coupon.priceCents else { return false }

        wallet.cents -= coupon.priceCents
        var purchased = coupon
        purchased.isRedeemed = false
        purchased.redeemedAt = Date()
        ownedCoupons.append(purchased)

        unlockBadgeIfNeeded(id: "coupon_buyer")
        saveState()
        return true
    }

    func checkStreakStatus() {
        guard let lastDate = streak.lastReceiptDate else { return }
        let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        streak.isAtRisk = daysSince >= 5 && daysSince < 7
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

    // MARK: - Private Helpers

    private func updateStreakForReceipt() {
        let now = Date()
        streak.lastReceiptDate = now
        streak.isAtRisk = false
        streak.weekCount += 1

        if streak.weekCount == 2 { unlockBadgeIfNeeded(id: "streak_2") }
        if streak.weekCount == 4 { unlockBadgeIfNeeded(id: "streak_4") }
        if streak.weekCount == 8 { unlockBadgeIfNeeded(id: "streak_8") }

        // Award weekly streak reward
        let reward = StreakData.weeklyReward(for: streak.weekCount)
        if reward.isCash {
            wallet.add(euros: reward.cashValue)
        } else {
            let spinStr = reward.label.components(separatedBy: " ").first ?? "1"
            spinsAvailable += Int(spinStr) ?? 1
        }
    }

    private func unlockBadgeIfNeeded(id: String) {
        guard let index = badges.firstIndex(where: { $0.id == id }),
              !badges[index].isUnlocked else { return }

        badges[index].isUnlocked = true
        badges[index].unlockedAt = Date()
        lastUnlockedBadge = badges[index]

        NotificationCenter.default.post(
            name: .badgeUnlocked,
            object: nil,
            userInfo: ["badgeId": id]
        )
    }
}
